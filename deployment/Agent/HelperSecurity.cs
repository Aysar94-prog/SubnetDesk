using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace SubnetDesk.Deployment {
    internal static class HelperSettings {
        static readonly byte[] Entropy=Encoding.UTF8.GetBytes("SubnetDesk.HelperSettings.v1");
        internal static Dictionary<string,object> Validate(Dictionary<string,object> settings) {
            string operation=Data.Text(settings,"operation"), password=Data.Text(settings,"newPassword"), current=Data.Text(settings,"currentPassword");
            if(operation!="unattended-password" && operation!="receiver-lock" && operation!="receiver-unlock" && operation!="receiver-password") throw new InvalidDataException("Unsupported Helper settings action.");
            if(operation!="receiver-unlock") Password(password);
            if(operation=="receiver-unlock" || operation=="receiver-password") Password(current);
            return new Dictionary<string,object>{{"operation",operation},{"newPassword",operation=="receiver-unlock" ? "" : password},{"currentPassword",operation=="receiver-unlock" || operation=="receiver-password" ? current : ""}};
        }
        internal static void Password(string password) {
            if(password.Length==0 || Encoding.UTF8.GetByteCount(password)>180) throw new InvalidDataException("Enter a password of 1–180 UTF-8 bytes.");
            foreach(char character in password) if(char.IsControl(character)) throw new InvalidDataException("Passwords cannot contain control characters.");
        }
        internal static string Protect(Dictionary<string,object> settings) {
            byte[] bytes=Encoding.UTF8.GetBytes(Data.Json(Validate(settings)));
            try { return Convert.ToBase64String(ProtectedData.Protect(bytes,Entropy,DataProtectionScope.LocalMachine)); }
            finally { Array.Clear(bytes,0,bytes.Length); }
        }
        internal static Dictionary<string,object> Unprotect(string value) {
            byte[] bytes=ProtectedData.Unprotect(Convert.FromBase64String(value),Entropy,DataProtectionScope.LocalMachine);
            try { return Validate(Data.Parse(Encoding.UTF8.GetString(bytes))); }
            finally { Array.Clear(bytes,0,bytes.Length); }
        }
        internal static Dictionary<string,object> PublicJob(Dictionary<string,object> job) {
            var copy=new Dictionary<string,object>(job); copy.Remove("protectedSettings"); copy.Remove("settings"); return copy;
        }
        internal static Dictionary<string,object> AgentJob(Dictionary<string,object> job) {
            var copy=PublicJob(job);
            if(job.ContainsKey("protectedSettings")) copy["settings"]=Unprotect(Data.Text(job,"protectedSettings"));
            return copy;
        }
        internal static string InstallProperties(Dictionary<string,object> settings) {
            string properties="REBOOT=ReallySuppress LAUNCH_TRAY_APP=N";
            if(settings==null) return properties;
            settings=Validate(settings);
            if(Data.Text(settings,"operation")!="unattended-password") throw new InvalidDataException("Only unattended access can be configured during MSI installation.");
            return properties+" SET_UNATTENDED_PASSWORD=1 UNATTENDED_PASSWORD_B64="+Convert.ToBase64String(Encoding.UTF8.GetBytes(Data.Text(settings,"newPassword")));
        }
    }
    internal static class HelperSecurity {
        internal static string Executable() {
            string product=Data.Text(Msi.Inventory(),"productCode");
            if(product=="") throw new InvalidOperationException("SubnetDesk Helper is not installed.");
            if(!Msi.InstalledSupportsUnattended(product)) throw new InvalidOperationException("Installed Helper MSI does not advertise unattended password configuration support. Update or repair Helper first.");
            using(var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64))
            using(var key=hive.OpenSubKey(@"SOFTWARE\SubnetDesk\Helper")) {
                string directory=key==null ? "" : Convert.ToString(key.GetValue("InstallFolder"));
                if(!Path.IsPathRooted(directory)) throw new InvalidOperationException("Helper installation directory is unavailable.");
                string executable=Path.Combine(directory,"SubnetDesk.exe");
                if(!File.Exists(executable)) throw new InvalidOperationException("Installed Helper executable was not found.");
                return executable;
            }
        }
        static string Run(string executable,string arguments,string password=null) {
            using(var process=new Process {StartInfo=new ProcessStartInfo(executable,arguments) {UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Path.GetDirectoryName(executable),RedirectStandardInput=password!=null,RedirectStandardOutput=true,RedirectStandardError=true}}) {
                process.Start(); var output=process.StandardOutput.ReadToEndAsync(); var error=process.StandardError.ReadToEndAsync();
                if(password!=null) {
                    byte[] bytes=Encoding.UTF8.GetBytes(password+"\n");
                    try { process.StandardInput.BaseStream.Write(bytes,0,bytes.Length); process.StandardInput.BaseStream.Flush(); process.StandardInput.Close(); }
                    finally {Array.Clear(bytes,0,bytes.Length);}
                }
                if(!process.WaitForExit(30000)) {process.Kill(); throw new InvalidOperationException("Helper configuration timed out.");}
                // Never propagate process output: a queried option can be a password verifier.
                var text=output.GetAwaiter().GetResult(); error.GetAwaiter().GetResult();
                if(process.ExitCode!=0) throw new InvalidOperationException("Helper rejected the settings change.");
                return text.Trim();
            }
        }
        internal static string Execute(Dictionary<string,object> settings) {
            settings=HelperSettings.Validate(settings);
            if(Data.Text(settings,"operation")!="unattended-password") return MachineReceiverPolicy.Apply(settings);
            string executable=Executable();
            using(var service=new System.ServiceProcess.ServiceController("SubnetDesk")) if(service.Status!=System.ServiceProcess.ServiceControllerStatus.Running) throw new InvalidOperationException("Start Helper service before changing its settings.");
            Run(executable,"--set-unattended-password-stdin",Data.Text(settings,"newPassword"));
            // The running listener caches its credentials. Reload them before
            // reporting success; the independent Agent stays available.
            try {
                using(var service=new System.ServiceProcess.ServiceController("SubnetDesk")) {
                    service.Stop(); service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Stopped,TimeSpan.FromSeconds(30));
                    service.Start(); service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Running,TimeSpan.FromSeconds(30));
                }
            } catch(Exception e) when(e is InvalidOperationException || e is System.ServiceProcess.TimeoutException) {
                throw new InvalidOperationException("Password was saved, but Helper service restart could not be verified. Check the target service.");
            }
            return "Unattended access password applied; Helper service restarted. Receiver-only policy and its unlock password are unchanged.";
        }
        internal static string ReadReceiverOption(string key) {
            if(key!="incoming-only" && key!="incoming-only-password" && key!="incoming-only-initialized") throw new InvalidDataException("Unsupported receiver option.");
            using(var service=new System.ServiceProcess.ServiceController("SubnetDesk")) if(service.Status!=System.ServiceProcess.ServiceControllerStatus.Running) throw new InvalidOperationException("Start Helper service before importing its current receiver lock.");
            return Run(Executable(),"--option "+key);
        }
    }
}
