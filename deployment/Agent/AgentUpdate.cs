using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.ServiceProcess;
using System.Threading;
using Microsoft.Win32;

namespace SubnetDesk.Deployment {
    internal static class AgentPackage {
        internal static Dictionary<string, object> Inspect(string path) {
            var assembly = AssemblyName.GetAssemblyName(path); var info = FileVersionInfo.GetVersionInfo(path); Version version;
            if (assembly.Name != "SubnetDeskAgent" || assembly.ProcessorArchitecture != ProcessorArchitecture.Amd64 || info.CompanyName != "SubnetDesk" || info.ProductName != "SubnetDesk Device Management" || !Version.TryParse(info.FileVersion, out version) || version < new Version(1,4,0,0)) throw new InvalidDataException("Choose a SubnetDesk Agent setup EXE version 1.4.0 or later.");
            return new Dictionary<string, object> { { "kind", "agent" }, { "version", version.ToString() }, { "sha256", Data.FileHash(path) }, { "name", "SubnetDesk Agent " + version } };
        }
        internal static void Verify(string path, Dictionary<string, object> metadata) {
            var actual = Inspect(path);
            foreach (string key in new[] { "version", "sha256", "kind" }) if (!Data.Equal(Data.Text(actual,key), Data.Text(metadata,key))) throw new InvalidDataException("Agent update metadata/hash mismatch.");
        }
    }
    internal static class AgentUpdate {
        static string Folder { get { return Path.Combine(Data.Root,"Agent"); } }
        static string Pointer { get { return Path.Combine(Folder,"agent-update.json"); } }
        internal static string Installed { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SubnetDesk Agent Runtime","SubnetDeskAgent.exe"); } }
        static string DirectoryFor(string id) { return Path.Combine(Folder,"updates",Data.Id(id)); }
        internal static string CurrentVersion { get { return Assembly.GetExecutingAssembly().GetName().Version.ToString(); } }
        static void Progress(Dictionary<string, object> config, string id, string stage) {
            try { Data.Call(config,"agent-update-status",Data.Text(config,"deviceToken"),new { jobId=id, stage=stage },Data.Text(config,"deviceId")); }
            catch (System.Net.WebException e) { if (e.Response != null) e.Response.Close(); Data.Log("Agent","Update progress delivery failed: " + e.Status); }
        }
        internal static void Schedule(Dictionary<string, object> config, Dictionary<string, object> job, CancellationToken stop) {
            string id=Data.Id(Data.Text(job,"id")), directory=DirectoryFor(id), package=Path.Combine(directory,"SubnetDeskAgent.exe");
            if (File.Exists(Pointer)) throw new InvalidOperationException("An Agent update is already pending.");
            if (new Version(Data.Text(job,"version")) <= new Version(CurrentVersion)) throw new InvalidOperationException("Agent update must be newer than the installed version.");
            if (!string.Equals(Assembly.GetExecutingAssembly().Location,Installed,StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Update requires the installed Agent service.");
            Directory.CreateDirectory(directory); Progress(config,id,"Downloading Agent");
            var request=Data.Request(config,"agent-packages/"+Data.Text(job,"sha256"),"GET",Data.Text(config,"deviceToken")); request.Headers["X-Device-Id"]=Data.Text(config,"deviceId");
            using (var response=request.GetResponse()) using (var input=response.GetResponseStream()) using (var output=File.Create(package)) {
                var bytes=new byte[65536]; long size=0; int count;
                while ((count=input.Read(bytes,0,bytes.Length))>0) { stop.ThrowIfCancellationRequested(); size+=count; if (size>67108864) throw new InvalidDataException("Agent package exceeds 64 MB."); output.Write(bytes,0,count); }
            }
            AgentPackage.Verify(package,job); stop.ThrowIfCancellationRequested();
            var state=new Dictionary<string,object>(job); state["deviceId"]=Data.Text(config,"deviceId"); state["previousVersion"]=CurrentVersion; state["state"]="downloaded"; state["stagedUtc"]=DateTime.UtcNow.ToString("o");
            Data.Save(Path.Combine(directory,"update.json"),state);
            string worker=Path.Combine(directory,"Updater.exe"); File.Copy(Installed,worker,false);
            Data.Save(Pointer,new { jobId=id }); Progress(config,id,"Verified; preparing service restart");
            try { using (var process=Process.Start(new ProcessStartInfo(worker,"--apply-agent-update "+id) { UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=directory })) { if (process==null) throw new InvalidOperationException("Agent updater could not start."); } }
            catch { File.Delete(Pointer); throw; }
            // The separate worker stops this service before replacing the runtime.
            stop.WaitHandle.WaitOne(TimeSpan.FromMinutes(2));
        }
        internal static bool Reconcile() {
            if (!File.Exists(Pointer)) return false;
            string id=Data.Id(Data.Text(Data.Read(Pointer),"jobId")), path=Path.Combine(DirectoryFor(id),"update.json"); var state=Data.Read(path);
            if (Data.Text(state,"state")=="completed" || Data.Text(state,"state")=="rolled-back") { File.Delete(Pointer); return false; }
            var config=Data.Read(Path.Combine(Folder,"config.json"));
            if (CurrentVersion!=Data.Text(state,"version") || Data.Text(config,"deviceId")!=Data.Text(state,"deviceId") || Data.FileHash(Installed)!=Data.Text(state,"sha256")) {
                DateTime staged;
                if (DateTime.TryParse(Data.Text(state,"stagedUtc"),out staged) && DateTime.UtcNow-staged.ToUniversalTime()>TimeSpan.FromMinutes(5)) {
                    Data.Save(Path.Combine(Folder,"result.json"),new {jobId=id,ok=false,message="Agent update was interrupted; the running version remains "+CurrentVersion+"."}); File.Delete(Pointer); return false;
                }
                return true;
            }
            using (var service=new ServiceController("SubnetDeskAgent")) service.WaitForStatus(ServiceControllerStatus.Running,TimeSpan.FromSeconds(30));
            using (var key=Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SubnetDeskAgentRuntime",true)) { if (key!=null) key.SetValue("DisplayVersion",CurrentVersion); }
            Data.Save(Path.Combine(Folder,"result.json"),new { jobId=id,ok=true,agentVersion=CurrentVersion,message="Agent "+CurrentVersion+" updated; service running; device identity preserved." });
            state["state"]="completed"; Data.Save(path,state); File.Delete(Pointer); Data.Log("Agent","Agent update completed: "+CurrentVersion); return false;
        }
        internal static void ReplaceRuntime(string replacement, string target, string backup) {
            for (int attempt=0;;attempt++) {
                try { File.Replace(replacement,target,backup); return; }
                catch (Exception e) when (e is IOException || e is UnauthorizedAccessException) { if (attempt>=30) throw; Thread.Sleep(500); }
            }
        }
        static void Stop(ServiceController service) {
            service.Refresh();
            if (service.Status!=ServiceControllerStatus.Stopped) {
                if (service.Status!=ServiceControllerStatus.StopPending) service.Stop();
                service.WaitForStatus(ServiceControllerStatus.Stopped,TimeSpan.FromSeconds(30));
            }
        }
        internal static int Apply(string value) {
            Data.SecureRoot(); string id=Data.Id(value), directory=DirectoryFor(id), path=Path.Combine(directory,"update.json"), package=Path.Combine(directory,"SubnetDeskAgent.exe"), backup=Path.Combine(directory,"previous.exe");
            var state=Data.Read(path); var config=Data.Read(Path.Combine(Folder,"config.json")); bool replaced=false,stopped=false;
            try {
                if (Data.Text(Data.Read(Pointer),"jobId")!=id || Data.Text(state,"deviceId")!=Data.Text(config,"deviceId") || !string.Equals(Assembly.GetExecutingAssembly().Location,Path.Combine(directory,"Updater.exe"),StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Agent updater identity mismatch.");
                AgentPackage.Verify(package,state);
                using (var key=Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\SubnetDeskAgent")) {
                    string image=key==null ? "" : Convert.ToString(key.GetValue("ImagePath")).Trim();
                    if (!string.Equals(image,"\""+Installed+"\" --service",StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Agent service installation path is not supported for self-update.");
                }
                Progress(config,id,"Restarting Agent service");
                using (var service=new ServiceController("SubnetDeskAgent")) {
                    stopped=true; Stop(service);
                    string replacement=Path.Combine(directory,"replacement.exe"); File.Copy(package,replacement,true);
                    // Retry while the stopped service process releases its executable.
                    ReplaceRuntime(replacement,Installed,backup); replaced=true;
                    state["state"]="starting"; Data.Save(path,state); service.Start();
                    service.WaitForStatus(ServiceControllerStatus.Running,TimeSpan.FromSeconds(30));
                    for (int attempt=0;attempt<60;attempt++) { if (Data.Text(Data.Read(path),"state")=="completed") return 0; Thread.Sleep(1000); }
                    throw new InvalidOperationException("Updated Agent did not confirm its version and identity.");
                }
            } catch (Exception e) {
                // Restore the previous runtime, preserving enrollment and Helper.
                try {
                    if (stopped) using (var service=new ServiceController("SubnetDeskAgent")) {
                        Stop(service);
                        if (replaced) ReplaceRuntime(backup,Installed,Path.Combine(directory,"failed.exe"));
                        using (var key=Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SubnetDeskAgentRuntime",true)) { if (key!=null) key.SetValue("DisplayVersion",Data.Text(state,"previousVersion")); }
                        state["state"]="rolled-back"; Data.Save(path,state);
                        Data.Save(Path.Combine(Folder,"result.json"),new { jobId=id,ok=false,message="Agent update failed; previous runtime restored. "+e.Message });
                        if (File.Exists(Pointer)) File.Delete(Pointer); service.Start();
                    } else {
                        Data.Save(Path.Combine(Folder,"result.json"),new { jobId=id,ok=false,message="Agent update rejected before replacement: "+e.GetType().Name });
                        if (File.Exists(Pointer)) File.Delete(Pointer);
                    }
                    Data.Log("Agent","Agent update failed: "+e.GetType().Name); return 1;
                } catch (Exception recovery) { Data.Log("Agent","Agent update recovery needs attention: "+recovery.GetType().Name); return 2; }
            }
        }
    }
}
