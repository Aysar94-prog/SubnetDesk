using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Management;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Threading;
using System.Text;

namespace SubnetDesk.Deployment {
    internal interface IWindowsAgentPush {
        Dictionary<string,object> Probe(string target,Dictionary<string,object> credential);
        string Push(Dictionary<string,object> device,Dictionary<string,object> credential,string setup,Dictionary<string,object> server,CancellationToken stop);
    }
    internal sealed class WindowsAgentPush : IWindowsAgentPush {
        [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool LogonUser(string user,string domain,string password,int type,int provider,out IntPtr token);
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
        static bool Port(string target,int port) {
            using(var socket=new TcpClient()) {
                var pending=socket.BeginConnect(target,port,null,null);
                using(var wait=pending.AsyncWaitHandle) {
                    if(!wait.WaitOne(1000)) return false;
                    try {socket.EndConnect(pending);return true;}catch(SocketException){return false;}
                }
            }
        }
        static ManagementScope Scope(string target,Dictionary<string,object> credential) {
            string user=Data.Text(credential,"username");
            if(Data.Text(credential,"accountType")=="local") user=target+"\\"+user;
            var options=new ConnectionOptions {Username=user,Password=Data.Text(credential,"password"),
                Impersonation=ImpersonationLevel.Impersonate,Authentication=AuthenticationLevel.PacketPrivacy,
                EnablePrivileges=true,Timeout=TimeSpan.FromSeconds(12)};
            var scope=new ManagementScope("\\\\"+target+"\\root\\cimv2",options); scope.Connect(); return scope;
        }
        static Dictionary<string,object> Facts(string target,ManagementScope scope) {
            var facts=new Dictionary<string,object>{{"target",target}};
            using(var query=new ManagementObjectSearcher(scope,new ObjectQuery("SELECT Caption,Version,CSName FROM Win32_OperatingSystem"),new EnumerationOptions {Timeout=TimeSpan.FromSeconds(12),ReturnImmediately=false}))
            using(var results=query.Get()) foreach(ManagementObject row in results) using(row) {
                string caption=Convert.ToString(row["Caption"]);
                if(caption.IndexOf("Windows",StringComparison.OrdinalIgnoreCase)<0) throw new InvalidDataException("Windows was not verified.");
                facts["windowsVersion"]=caption; facts["osBuild"]=Convert.ToString(row["Version"]); facts["machine"]=Convert.ToString(row["CSName"]);
            }
            if(!facts.ContainsKey("windowsVersion")) throw new InvalidDataException("Windows was not verified.");
            using(var query=new ManagementObjectSearcher(scope,new ObjectQuery("SELECT UUID FROM Win32_ComputerSystemProduct")))
            using(var results=query.Get()) foreach(ManagementObject row in results) using(row) facts["uuid"]=Convert.ToString(row["UUID"]);
            Guid uuid;
            facts["uuid"]=!Guid.TryParse(Data.Text(facts,"uuid"),out uuid) || uuid==Guid.Empty || uuid==new Guid("ffffffff-ffff-ffff-ffff-ffffffffffff") ? "" : uuid.ToString("D");
            facts["verifiedWindows"]=true;facts["agentService"]="Not installed";
            using(var query=new ManagementObjectSearcher(scope,new ObjectQuery("SELECT State FROM Win32_Service WHERE Name='SubnetDeskAgent'")))
            using(var rows=query.Get()) foreach(ManagementObject row in rows) using(row) facts["agentService"]=Convert.ToString(row["State"]);
            return facts;
        }
        public Dictionary<string,object> Probe(string target,Dictionary<string,object> credential) {
            if(!Port(target,135)) throw new Win32Exception(1722);
            return Facts(target,Scope(target,credential));
        }
        internal static bool SameDevice(Dictionary<string,object> expected,Dictionary<string,object> actual) {
            return Data.Text(expected,"uuid")!="" && Data.Text(actual,"verifiedWindows")=="True" &&
                string.Equals(Data.Text(expected,"uuid"),Data.Text(actual,"uuid"),StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Data.Text(expected,"machine"),Data.Text(actual,"machine"),StringComparison.OrdinalIgnoreCase);
        }
        public string Push(Dictionary<string,object> device,Dictionary<string,object> credential,string setup,Dictionary<string,object> server,CancellationToken stop) {
            stop.ThrowIfCancellationRequested();
            string target=Data.Text(device,"target"); var scope=Scope(target,credential);
            var actual=Facts(target,scope);
            if(!SameDevice(device,actual)) throw new InvalidOperationException("Target Windows identity changed. Discover and select it again.");
            var metadata=AgentPackage.Inspect(setup); Version version;
            if(!Version.TryParse(Data.Text(metadata,"version"),out version) || version<new Version(1,7,0,0)) throw new InvalidOperationException("Agent setup 1.7.0+ is required.");
            string endpoint=Data.Endpoint(Data.Text(server,"server")).AbsoluteUri, pin=Data.Text(server,"certificateSha256");
            if(!System.Text.RegularExpressions.Regex.IsMatch(pin,"^[A-Fa-f0-9]{64}$")) throw new InvalidDataException("Invalid management certificate fingerprint.");
            string user=Data.Text(credential,"username"), domain=null;
            if(Data.Text(credential,"accountType")=="local") domain=Data.Text(actual,"machine");
            else if(user.Contains("\\")) {int split=user.IndexOf('\\');domain=user.Substring(0,split);user=user.Substring(split+1);}
            IntPtr token;
            if(!LogonUser(user,domain,Data.Text(credential,"password"),9,3,out token)) throw new Win32Exception(Marshal.GetLastWin32Error());
            try { using(WindowsIdentity.Impersonate(token)) {
                if(!Port(target,445)) throw new IOException("SMB administrator share unavailable");
                string name="SubnetDeskPush-"+Guid.NewGuid().ToString("N");
                string remoteRoot="\\\\"+target+"\\ADMIN$\\Temp\\"+name;
                if(Directory.Exists(remoteRoot)) throw new IOException("Push staging directory already exists.");
                Directory.CreateDirectory(remoteRoot);
                string windows;
                using(var query=new ManagementObjectSearcher(scope,new ObjectQuery("SELECT WindowsDirectory FROM Win32_OperatingSystem")))
                using(var rows=query.Get()) {windows="";foreach(ManagementObject row in rows) using(row) windows=Convert.ToString(row["WindowsDirectory"]);}
                if(!System.Text.RegularExpressions.Regex.IsMatch(windows,@"^[A-Za-z]:\\[A-Za-z0-9 _.-]+$")) throw new InvalidDataException("Unsupported target Windows directory.");
                string targetRoot=windows+"\\Temp\\"+name;
                string runtime=Path.Combine(remoteRoot,"SubnetDeskAgent.exe"); File.Copy(setup,runtime);
                if(Data.FileHash(runtime)!=Data.Text(metadata,"sha256")) throw new IOException("Remote setup hash verification failed.");
                string payload=Convert.ToBase64String(Encoding.UTF8.GetBytes(Data.Json(new {exe=targetRoot+"\\SubnetDeskAgent.exe",server=endpoint,pin=pin,exit=targetRoot+"\\exit.txt",log=targetRoot+"\\setup.log"})));
                string script="$ErrorActionPreference='Stop'; $c=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"+payload+"')) | ConvertFrom-Json; try { $p=Start-Process -FilePath $c.exe -ArgumentList @('--install','--silent','--server',('\"'+$c.server+'\"'),'--certificate-sha256',$c.pin) -WindowStyle Hidden -Wait -PassThru -RedirectStandardError $c.log; [IO.File]::WriteAllText($c.exit,[string]$p.ExitCode) } catch { [IO.File]::WriteAllText($c.exit,'1') }";
                string command="powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "+Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
                using(var process=new ManagementClass(scope,new ManagementPath("Win32_Process"),null))
                using(var input=process.GetMethodParameters("Create")) {
                    input["CommandLine"]=command; input["CurrentDirectory"]=targetRoot;
                    using(var result=process.InvokeMethod("Create",input,new InvokeMethodOptions {Timeout=TimeSpan.FromSeconds(20)}))
                        if(Convert.ToUInt32(result["ReturnValue"])!=0) throw new InvalidOperationException("Remote administrator process creation was denied.");
                }
                string exit=Path.Combine(remoteRoot,"exit.txt"); DateTime deadline=DateTime.UtcNow.AddMinutes(3);
                while(!File.Exists(exit)) {
                    if(stop.WaitHandle.WaitOne(1000)) throw new OperationCanceledException("Push interrupted; remote installer may still be running.");
                    if(DateTime.UtcNow>=deadline) throw new TimeoutException("Installer result timed out; outcome is unknown. Verify target before retrying.");
                }
                if(File.ReadAllText(exit).Trim()!="0") throw new InvalidOperationException("Agent setup failed; inspect "+targetRoot+"\\setup.log on the target.");
                bool running=false;
                using(var query=new ManagementObjectSearcher(scope,new ObjectQuery("SELECT State FROM Win32_Service WHERE Name='SubnetDeskAgent'")))
                using(var rows=query.Get()) foreach(ManagementObject row in rows) using(row) running=Convert.ToString(row["State"])=="Running";
                if(!running) throw new InvalidOperationException("Setup exited successfully, but Agent service startup was not verified.");
                // Only remove the three files created for this unique operation.
                try {
                    foreach(string file in new[]{"SubnetDeskAgent.exe","setup.log","exit.txt"}) File.Delete(Path.Combine(remoteRoot,file));
                    Directory.Delete(remoteRoot,false);
                } catch(Exception e) when(e is IOException || e is UnauthorizedAccessException) {Data.Log("Management","Verified Agent push succeeded; temporary target cleanup remains pending.");}
                return "Agent "+version+" installed; service Running. Registration/approval is verified separately in Agent requests.";
            }} finally {CloseHandle(token);}
        }
        internal static string Failure(Exception error) {
            var management=error as ManagementException;
            var com=error as COMException;var native=error as Win32Exception;
            int code=management!=null ? (int)management.ErrorCode : com!=null ? com.ErrorCode : native!=null ? native.ErrorCode : error.HResult;
            string detail=" (0x"+unchecked((uint)code).ToString("X8")+")";
            if(native!=null) detail=" (Win32 "+native.NativeErrorCode+")";
            if(error is UnauthorizedAccessException || (management!=null && management.ErrorCode==ManagementStatus.AccessDenied) ||
                code==unchecked((int)0x80041003) || code==unchecked((int)0x80070005) || code==unchecked((int)0x8007052e) ||
                (native!=null && (native.NativeErrorCode==5 || native.NativeErrorCode==1326))) return "Administrator authentication/access denied"+detail+". Check credentials, remote UAC and WMI/ADMIN$ permissions.";
            if(code==unchecked((int)0x800706ba) || code==unchecked((int)0x80041015) || (native!=null && native.NativeErrorCode==1722)) return "WMI/RPC unavailable"+detail+". Check target availability, VLAN routing, TCP 135 and dynamic RPC firewall rules.";
            if(management!=null || (unchecked((uint)code)&0xfffff000u)==0x80041000u) return "WMI query/provider failed"+detail+". Check the target WMI namespace and provider health.";
            if(error is TimeoutException) return "Timed out; remote installation outcome may be unknown.";
            if(error is InvalidOperationException || error is InvalidDataException) return error.Message;
            return "Windows management failed ("+error.GetType().Name+")"+detail+". Check authentication policy, routing, RPC, administrator shares and firewall policy.";
        }
    }
}
