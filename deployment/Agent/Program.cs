using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;

namespace SubnetDesk.Deployment {
    internal sealed class DeploymentService : ServiceBase {
        readonly bool agent;
        readonly CancellationTokenSource stopping = new CancellationTokenSource();
        ManagementServer server;
        internal DeploymentService(bool isAgent) { agent = isAgent; ServiceName = agent ? "SubnetDeskAgent" : "SubnetDeskManagement"; CanStop = true; }
        protected override void OnStart(string[] args) {
            Data.SecureRoot();
            Task.Run(() => { if (agent) Agent.Run(stopping.Token); else { server = new ManagementServer(); server.Run(stopping.Token); } });
        }
        protected override void OnStop() { stopping.Cancel(); if (server != null) server.Stop(); }
        [STAThread]
        static int Main(string[] args) {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            if (args.Length == 2 && args[0] == "--apply-agent-update") return AgentUpdate.Apply(args[1]);
            bool agent = Path.GetFileNameWithoutExtension(System.Reflection.Assembly.GetExecutingAssembly().Location).IndexOf("Agent", StringComparison.OrdinalIgnoreCase) >= 0;
            if(agent && (Array.IndexOf(args,"--silent")>=0 || Array.IndexOf(args,"--install")>=0)) return SilentAgentSetup.Run(args);
            if (args.Length > 0 && args[0] == "--inspect-msi") { Console.WriteLine(Data.Json(Msi.Inspect(args[1]))); return 0; }
            if (args.Length > 0 && args[0] == "--self-test") { SelfTest.Run(); return 0; }
            if (agent && Environment.UserInteractive && (args.Length == 0 || args[0] == "--settings")) {
                System.Windows.Forms.Application.EnableVisualStyles();
                System.Windows.Forms.Application.Run(new AgentSettings()); return 0;
            }
            if (agent && Environment.UserInteractive && args.Length > 0 && args[0] == "--remove") {
                System.Windows.Forms.Application.EnableVisualStyles(); using (var settings = new AgentSettings()) settings.Remove(); return 0;
            }
            if (args.Length > 0 && args[0] == "--console") {
                using (var cancel = new CancellationTokenSource()) {
                    Console.CancelKeyPress += (s, e) => { e.Cancel = true; cancel.Cancel(); };
                    if (agent) Agent.Run(cancel.Token); else new ManagementServer().Run(cancel.Token);
                }
            } else ServiceBase.Run(new DeploymentService(agent));
            return 0;
        }
    }
    internal static class Agent {
        static string Folder { get { return Path.Combine(Data.Root, "Agent"); } }
        static string ConfigPath { get { return Path.Combine(Folder, "config.json"); } }
        internal static void Run(CancellationToken stop) {
            Directory.CreateDirectory(Folder);
            Task.Run(() => {
                while (!stop.WaitHandle.WaitOne(30000)) {
                    try {
                        if (!File.Exists(ConfigPath)) continue;
                        var config = Data.Read(ConfigPath); string device = Data.Text(config, "deviceId");
                        if (device != "") Data.Call(config, "heartbeat", Data.Text(config, "deviceToken"), new { helper = Msi.Inventory(), agentVersion = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString() }, device);
                    } catch (Exception e) { Data.Log("Agent", "Heartbeat failed: " + e.GetType().Name); }
                }
            });
            while (!stop.IsCancellationRequested) {
                try { Tick(stop); }
                catch (WebException e) {
                    var response = e.Response as HttpWebResponse;
                    Data.Log("Agent", response == null ? "Connection failed: " + e.Status + ". Check server DNS/address, TCP 443, certificate name, fingerprint and expiry." : "Server rejected request: HTTP " + (int)response.StatusCode + ". Check approval/revocation in Deploy. Request server approval in Agent Settings to replace an unauthorized identity.");
                    if (response != null) response.Close();
                }
                catch (Exception e) { Data.Log("Agent", "Cycle failed: " + e.GetType().Name + ". Check enrollment, server reachability and the server certificate."); }
                // Randomized polling avoids a simultaneous burst from large fleets.
                stop.WaitHandle.WaitOne(10000 + new Random().Next(10000));
            }
        }
        static void Tick(CancellationToken stop) {
            if (!File.Exists(ConfigPath)) return;
            if (AgentUpdate.Reconcile()) return;
            var config = Data.Read(ConfigPath);
            string device = Data.Text(config, "deviceId"), token = Data.Text(config, "deviceToken");
            if (device == "") {
                if (Data.Text(config, "candidateId") == "") { config["candidateId"] = Guid.NewGuid().ToString("D"); config["candidateToken"] = Data.Secret(); Data.Save(ConfigPath, config); }
                if (Data.Text(config, "approvalRequired") == "true") {
                    var joined = Data.Call(config, "join", "", new { deviceId = Data.Text(config, "candidateId"), deviceToken = Data.Text(config, "candidateToken"), machine = Environment.MachineName, domain = Data.Text(ComputerFacts.Read(), "domain") });
                    string state = Data.Text(joined, "state");
                    if (state != Data.Text(config, "approvalState")) { config["approvalState"] = state; Data.Save(ConfigPath, config); Data.Log("Agent", "Server approval: " + state + ". Review Agent requests in Deploy."); }
                    if (state != "approved") return;
                    config["deviceId"] = Data.Id(Data.Text(joined, "deviceId")); config["deviceToken"] = Data.Text(config, "candidateToken"); config.Remove("candidateId"); config.Remove("candidateToken"); config.Remove("approvalRequired");
                    Data.Save(ConfigPath, config); Data.Log("Agent", "Device approved by administrator."); return;
                }
                var enrolled = Data.Call(config, "enroll", "", new { token = Data.Text(config, "enrollmentToken"), deviceId = Data.Text(config, "candidateId"), deviceToken = Data.Text(config, "candidateToken"), machine = Environment.MachineName, domain = Environment.UserDomainName });
                config["deviceId"] = Data.Id(Data.Text(enrolled, "deviceId")); config["deviceToken"] = Data.Text(config, "candidateToken"); config.Remove("enrollmentToken"); config.Remove("candidateId"); config.Remove("candidateToken");
                Data.Save(ConfigPath, config); device = Data.Text(config, "deviceId"); token = Data.Text(config, "deviceToken");
                Data.Log("Agent", "Device enrolled.");
            }
            var resultFile = Path.Combine(Folder, "result.json");
            if (File.Exists(resultFile)) {
                var report = Data.Read(resultFile);
                Data.Call(config, "result", token, report, device);
                File.Delete(resultFile);
            }
            var facts = ComputerFacts.Read(); facts["helper"] = Msi.Inventory(); facts["agentVersion"] = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString(); facts["agentUpdateProtocol"] = "1"; facts["helperSettingsProtocol"]="2";
            var reply = Data.Call(config, "poll", token, facts, device);
            object raw;
            if (!reply.TryGetValue("job", out raw) || raw == null || stop.IsCancellationRequested) return;
            var job = (Dictionary<string, object>)raw;
            string id = Data.Id(Data.Text(job, "id"));
            string action = Data.Text(job, "action");
            if (action == "") action = "install";
            if (action == "agent-update") {
                try { AgentUpdate.Schedule(config,job,stop); }
                catch (Exception e) { Data.Save(resultFile,new { jobId=id,ok=false,message="Agent update could not start: "+e.GetType().Name }); }
                return;
            }
            string pending = Path.Combine(Folder, "pending.json");
            if (File.Exists(pending) && Data.Text(Data.Read(pending), "id") == id) {
                // A crash during MSI execution leaves an uncertain outcome. Do not
                // blindly repeat privileged work; reconcile the installed product.
                var verified = action == "install" ? !job.ContainsKey("settings") && Verify(job) : action == "uninstall" && Data.Text(Msi.Inventory(), "productCode") == "";
                Data.Save(resultFile, new { jobId = id, ok = verified, message = verified ? "Helper version and service verified after restart." : job.ContainsKey("settings") ? "Sensitive Helper settings operation was interrupted; outcome is unknown. Verify settings before retrying." : "Installation was interrupted. Check Windows Installer before retrying." });
                File.Delete(pending); return;
            }
            string package = Path.Combine(Folder, id + ".msi");
            bool ok = false; string message;
            try {
                object settingsValue; job.TryGetValue("settings",out settingsValue); var settings=settingsValue as Dictionary<string,object>;
                if(action=="configure-helper") {
                    if(settings==null) throw new InvalidDataException("Missing Helper settings.");
                    Data.Save(pending,new {id=id}); message=HelperSecurity.Execute(settings); ok=true;
                } else if (action != "install") {
                    Data.Save(pending, new { id = id });
                    message = HelperActions.Execute(action); ok = true;
                } else {
                var request = Data.Request(config, "packages/" + Data.Text(job, "sha256"), "GET", token); request.Headers["X-Device-Id"] = device;
                using (var response = request.GetResponse()) using (var source = response.GetResponseStream()) using (var target = File.Create(package)) {
                    var buffer = new byte[65536]; long size = 0; int count;
                    while ((count = source.Read(buffer, 0, buffer.Length)) > 0) { stop.ThrowIfCancellationRequested(); size += count; if (size > 536870912) throw new InvalidDataException("Package too large."); target.Write(buffer, 0, count); }
                }
                var metadata = Msi.Inspect(package);
                foreach (string property in new[] { "sha256", "productCode", "version" }) if (!Data.Equal(Data.Text(metadata, property), Data.Text(job, property))) throw new InvalidDataException("Package metadata/hash mismatch.");
                stop.ThrowIfCancellationRequested();
                Data.Save(pending, new { id = id });
                if (!Msi.Installed(Data.Text(job, "productCode"), Data.Text(job, "version"))) {
                    if(settings!=null && !Msi.SupportsUnattended(package)) throw new InvalidOperationException("Selected Helper MSI does not support unattended password configuration.");
                    Msi.MsiSetInternalUI(2, IntPtr.Zero);
                    uint code = Msi.MsiInstallProduct(package, HelperSettings.InstallProperties(settings));
                    if (code != 0 && code != 3010 && code != 1641) throw new InvalidOperationException("Windows Installer code " + code + ".");
                }
                if(settings!=null) {if(!Verify(job)) throw new InvalidOperationException("Installed Helper service could not be started."); HelperSecurity.Execute(settings);}
                ok = Verify(job); message = ok ? (settings==null ? "Selected Helper version installed; service running." : "Selected Helper version installed; service running; unattended password applied.") : "Installation finished, but version/service verification failed.";
                }
            } catch (Exception e) { message = e is InvalidOperationException ? e.Message : "Package download, validation or installation failed (" + e.GetType().Name + ")."; }
            finally { if (File.Exists(package)) File.Delete(package); }
            // Durable outbox: report on the next poll and retry on network errors.
            Data.Save(resultFile, new { jobId = id, ok = ok, message = message });
            if (File.Exists(pending)) File.Delete(pending);
        }
        static bool Verify(Dictionary<string, object> job) {
            if (!Msi.Installed(Data.Text(job, "productCode"), Data.Text(job, "version"))) return false;
            try {
                using (var service = new ServiceController("SubnetDesk")) {
                    if (service.Status == ServiceControllerStatus.Stopped) service.Start();
                    service.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30)); return true;
                }
            } catch (InvalidOperationException) { return false; }
            catch (System.ServiceProcess.TimeoutException) { return false; }
        }
    }
}
