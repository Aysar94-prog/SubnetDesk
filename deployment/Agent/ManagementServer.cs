using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace SubnetDesk.Deployment {
    internal sealed class ManagementServer {
        readonly object gate = new object();
        readonly HttpListener listener = new HttpListener();
        readonly string folder;
        Dictionary<string, object> config;
        readonly string listenPrefix;
        readonly AgentRollout rollout;
        internal ManagementServer(string dataFolder = null, Dictionary<string, object> initialConfig = null, string testListenPrefix = null) { folder = dataFolder ?? Path.Combine(Data.Root, "Management"); config = initialConfig; listenPrefix = testListenPrefix ?? "https://+:443/subnetdesk/"; rollout=new AgentRollout(folder,()=>config ?? Data.Read(Path.Combine(folder,"config.json"))); }
        string PathFor(string kind, string id) { return Path.Combine(folder, kind, id + ".json"); }
        internal void Stop() { listener.Close(); }
        internal void Run(CancellationToken stop) {
            Task.Run(()=>rollout.Run(stop));
            while (!stop.IsCancellationRequested) {
                try {
                    string path = Path.Combine(folder, "config.json");
                    if (!File.Exists(path)) { stop.WaitHandle.WaitOne(5000); continue; }
                    config = Data.Read(path); Data.Endpoint(Data.Text(config, "server"));
                    listener.Prefixes.Add(listenPrefix); listener.Start();
                    Data.Log("Management", "HTTPS management listener started.");
                    while (!stop.IsCancellationRequested) {
                        var context = listener.GetContext();
                        Task.Run(() => Handle(context));
                    }
                } catch (HttpListenerException) { if (!stop.IsCancellationRequested) Data.Log("Management", "HTTPS listener unavailable. Check certificate binding and port 443."); }
                catch (Exception e) { Data.Log("Management", "Management service error: " + e.GetType().Name); }
                if (listener.IsListening) listener.Stop();
                if (!stop.IsCancellationRequested) stop.WaitHandle.WaitOne(10000);
            }
        }
        static Dictionary<string, object> Body(HttpListenerRequest request) {
            if (request.ContentLength64 > 1048576 || request.ContentLength64 < 0) throw new InvalidDataException("JSON request too large or missing length.");
            using (var reader = new StreamReader(request.InputStream, Encoding.UTF8)) return Data.Parse(reader.ReadToEnd());
        }
        static void Reply(HttpListenerResponse response, object body, int status = 200) {
            byte[] bytes = Encoding.UTF8.GetBytes(Data.Json(body)); response.StatusCode = status; response.ContentType = "application/json"; response.ContentLength64 = bytes.Length; response.OutputStream.Write(bytes, 0, bytes.Length);
        }
        static void Reply(Action<object, int> response, object body, int status = 200) { response(body, status); }
        bool Admin(HttpListenerRequest request) { return Data.Equal(request.Headers["Authorization"] ?? "", "Bearer " + Data.Text(config, "adminToken")); }
        Dictionary<string, object> Device(HttpListenerRequest request) {
            string id = Data.Id(request.Headers["X-Device-Id"] ?? ""); string path = PathFor("devices", id);
            if (!File.Exists(path)) throw new UnauthorizedAccessException("Device record is missing: " + id);
            var device = Data.Read(path); string supplied = request.Headers["Authorization"] ?? "";
            if (Data.Text(device, "transport") == "domain") throw new UnauthorizedAccessException();
            if (device.ContainsKey("revoked")) throw new UnauthorizedAccessException("Device access revoked: " + id);
            if (!supplied.StartsWith("Bearer ", StringComparison.Ordinal) || !Data.Equal(Data.Hash(Encoding.UTF8.GetBytes(supplied.Substring(7))), Data.Text(device, "tokenHash"))) throw new UnauthorizedAccessException("Device credential mismatch: " + id);
            return device;
        }
        void Handle(HttpListenerContext context) {
            var request = context.Request; var response = context.Response;
            try {
                string route = request.Url.AbsolutePath.Substring("/subnetdesk/".Length).Trim('/');
                if (route == "health" && request.HttpMethod == "GET") { Reply(response, new { ok = true }); return; }
                bool agentPackage = route == "admin/agent-package";
                if ((route == "admin/package" || agentPackage) && request.HttpMethod == "POST") {
                    if (!Admin(request)) throw new UnauthorizedAccessException();
                    long maximum = agentPackage ? 67108864 : 536870912;
                    if (request.ContentLength64 < 1 || request.ContentLength64 > maximum) throw new InvalidDataException("Package exceeds the allowed size.");
                    string category = agentPackage ? "agent-packages" : "packages";
                    string packages = Path.Combine(folder, category); Directory.CreateDirectory(packages);
                    string temporary = Path.Combine(packages, Guid.NewGuid().ToString("N") + ".upload");
                    try {
                        using (var output = File.Create(temporary)) {
                            byte[] buffer = new byte[65536]; long copied = 0; int count;
                            while ((count = request.InputStream.Read(buffer, 0, buffer.Length)) > 0) { copied += count; if (copied > maximum) throw new InvalidDataException("Package too large."); output.Write(buffer, 0, count); }
                            if (copied != request.ContentLength64) throw new InvalidDataException("Incomplete MSI upload.");
                        }
                        if (agentPackage) {
                            string stripped=temporary+".runtime";
                            try { EmbeddedRegistration.CopyRuntime(temporary,stripped); File.Delete(temporary); File.Move(stripped,temporary); }
                            finally { if (File.Exists(stripped)) File.Delete(stripped); }
                        }
                        var metadata = agentPackage ? AgentPackage.Inspect(temporary) : Msi.Inspect(temporary); string sha = Data.Text(metadata, "sha256");
                        metadata["uploadedUtc"] = DateTime.UtcNow.ToString("o"); metadata["name"] = (agentPackage ? "SubnetDesk Agent " : "SubnetDesk Helper ") + Data.Text(metadata, "version");
                        lock (gate) {
                            string destination = Path.Combine(packages, sha + (agentPackage ? ".exe" : ".msi"));
                            if (!File.Exists(destination)) File.Move(temporary, destination);
                            Data.Save(PathFor(category, sha), metadata);
                        }
                        Reply(response, metadata);
                    } finally { if (File.Exists(temporary)) File.Delete(temporary); }
                    return;
                }
                bool agentDownload = route.StartsWith("agent-packages/", StringComparison.Ordinal);
                if ((route.StartsWith("packages/", StringComparison.Ordinal) || agentDownload) && request.HttpMethod == "GET") {
                    string sha = route.Substring(agentDownload ? "agent-packages/".Length : "packages/".Length);
                    if (!Regex.IsMatch(sha, "^[A-F0-9]{64}$")) throw new InvalidDataException("Invalid package hash.");
                    lock (gate) {
                        var device = Device(request);
                        object job;
                        if (!device.TryGetValue("job", out job) || job == null || Data.Text((Dictionary<string, object>)job, "sha256") != sha) throw new UnauthorizedAccessException();
                        if (agentDownload != (Data.Text((Dictionary<string,object>)job,"action")=="agent-update")) throw new UnauthorizedAccessException();
                    }
                    using (var file = File.OpenRead(Path.Combine(folder, agentDownload ? "agent-packages" : "packages", sha + (agentDownload ? ".exe" : ".msi")))) { response.ContentType = "application/octet-stream"; response.ContentLength64 = file.Length; file.CopyTo(response.OutputStream); }
                    return;
                }
                Dictionary<string, object> body = request.HttpMethod == "POST" ? Body(request) : null;
                lock (gate) {
                    if (route == "join" && body != null) { Join(body, request.RemoteEndPoint == null ? "" : request.RemoteEndPoint.Address.ToString(), (value, status) => Reply(response, value, status)); return; }
                    if (route.StartsWith("admin/", StringComparison.Ordinal)) {
                        if (!Admin(request)) throw new UnauthorizedAccessException();
                        AdminRoute(route, request.HttpMethod, body, (value, status) => Reply(response, value, status)); return;
                    }
                    if (route == "enroll" && body != null) {
                        string token = Data.Text(body, "token"); string hash = Data.Hash(Encoding.UTF8.GetBytes(token)); string path = PathFor("enrollments", hash);
                        if (!File.Exists(path)) throw new UnauthorizedAccessException();
                        var enrollment = Data.Read(path);
                        if (DateTime.Parse(Data.Text(enrollment, "expiresUtc")).ToUniversalTime() < DateTime.UtcNow) throw new UnauthorizedAccessException();
                        string id = Data.Id(Data.Text(body, "deviceId")), secret = Data.Text(body, "deviceToken");
                        if (Convert.FromBase64String(secret).Length != 32) throw new UnauthorizedAccessException();
                        string tokenHash = Data.Hash(Encoding.UTF8.GetBytes(secret));
                        if (Data.Text(enrollment, "deviceId") != "") {
                            if (Data.Text(enrollment, "deviceId") != id || !Data.Equal(Data.Text(enrollment, "tokenHash"), tokenHash)) throw new UnauthorizedAccessException();
                        } else {
                            enrollment["deviceId"] = id; enrollment["tokenHash"] = tokenHash; Data.Save(path, enrollment);
                        }
                        if (!File.Exists(PathFor("devices", id))) Data.Save(PathFor("devices", id), new { id = id, name = Data.Text(enrollment, "name"), group = Data.Text(enrollment, "group"), transport = "agent", machine = Limit(Data.Text(body, "machine")), domain = Limit(Data.Text(body, "domain")), tokenHash = tokenHash, lastSeenUtc = "", status = "Enrolled", job = (object)null });
                        Reply(response, new { deviceId = id }); return;
                    }
                    var record = Device(request); string deviceId = Data.Text(record, "id");
                    if (route=="agent-update-status" && body!=null) {
                        object raw; record.TryGetValue("job",out raw); var job=raw as Dictionary<string,object>;
                        string stage=Data.Text(body,"stage");
                        if (job==null || Data.Text(job,"action")!="agent-update" || Data.Text(job,"id")!=Data.Id(Data.Text(body,"jobId")) || (stage!="Downloading Agent" && stage!="Verified; preparing service restart" && stage!="Restarting Agent service")) throw new InvalidDataException("Invalid Agent update progress.");
                        job["stage"]=stage; record["message"]=stage; Data.Save(PathFor("devices",deviceId),record); Reply(response,new {ok=true}); return;
                    }
                    if ((route == "poll" || route == "heartbeat") && body != null) {
                        record["lastSeenUtc"] = DateTime.UtcNow.ToString("o");
                        if (body.ContainsKey("machine")) {
                            string previousMachine = Data.Text(record, "machine"), machine = Limit(Data.Text(body, "machine")).Trim();
                            if (machine != "") {
                                if (!record.ContainsKey("nameIsCustom") && Data.Text(record, "name") == previousMachine) record["name"] = machine;
                                record["machine"] = machine;
                            }
                        }
                        if (body.ContainsKey("domain")) record["domain"] = Limit(Data.Text(body, "domain"));
                        if (body.ContainsKey("domainJoined")) record["domainJoined"] = Limit(Data.Text(body, "domainJoined"));
                        if (body.ContainsKey("operatingSystem")) record["operatingSystem"] = Limit(Data.Text(body, "operatingSystem"));
                        if (body.ContainsKey("architecture")) record["architecture"] = Limit(Data.Text(body, "architecture"));
                        if (request.RemoteEndPoint != null) record["address"] = request.RemoteEndPoint.Address.IsIPv4MappedToIPv6 ? request.RemoteEndPoint.Address.MapToIPv4().ToString() : request.RemoteEndPoint.Address.ToString();
                        object inventory;
                        if (body.TryGetValue("helper", out inventory) && inventory is Dictionary<string, object>) {
                            var helper = (Dictionary<string, object>)inventory;
                            record["helperVersion"] = Limit(Data.Text(helper, "version")); record["helperService"] = Limit(Data.Text(helper, "service"));
                            foreach(string key in new[]{"receiverPolicyProtocol","receiverScope","receiverOnly"}) record[key]=Limit(Data.Text(helper,key));
                        }
                        record["agentVersion"] = Limit(Data.Text(body, "agentVersion"));
                        if (body.ContainsKey("agentUpdateProtocol")) record["agentUpdateProtocol"] = Limit(Data.Text(body,"agentUpdateProtocol"));
                        if (body.ContainsKey("helperSettingsProtocol")) record["helperSettingsProtocol"] = Limit(Data.Text(body,"helperSettingsProtocol"));
                        if (Data.Text(record, "status") == "Approved — waiting for Agent" || Data.Text(record, "status") == "Enrolled") record["status"] = "Connected — no tasks yet";
                        if (route == "heartbeat") { Data.Save(PathFor("devices", deviceId), record); Reply(response, new { ok = true }); return; }
                        ExpireSettings(record);
                        object job; record.TryGetValue("job", out job);
                        if (job != null) { record["status"] = "Running"; ((Dictionary<string, object>)job)["state"] = "assigned"; }
                        var delivery=job==null ? null : HelperSettings.AgentJob((Dictionary<string,object>)job);
                        Data.Save(PathFor("devices", deviceId), record); Reply(response, new { job = delivery }); return;
                    }
                    if (route == "result" && body != null) {
                        string jobId = Data.Id(Data.Text(body, "jobId")); object active; record.TryGetValue("job", out active);
                        if (active != null && Data.Text((Dictionary<string, object>)active, "id") == jobId) {
                            bool ok = body.ContainsKey("ok") && body["ok"] is bool && (bool)body["ok"];
                            if (ok && Data.Text((Dictionary<string,object>)active,"action")=="agent-update" && Data.Text(body,"agentVersion")!=Data.Text((Dictionary<string,object>)active,"version")) throw new InvalidDataException("Updated Agent version was not confirmed.");
                            record["status"] = ok ? "Succeeded" : "Failed"; record["message"] = Limit(Data.Text(body, "message")); record["lastJobId"] = jobId;
                            if (ok && Data.Text((Dictionary<string, object>)active, "version") != "") record[Data.Text((Dictionary<string,object>)active,"action")=="agent-update" ? "agentVersion" : "helperVersion"] = Data.Text((Dictionary<string, object>)active, "version");
                            Data.Save(PathFor("history", jobId), new { deviceId = deviceId, job = HelperSettings.PublicJob((Dictionary<string,object>)active), ok = ok, message = record["message"], finishedUtc = DateTime.UtcNow.ToString("o") });
                            record["job"] = null; record["lastSeenUtc"] = DateTime.UtcNow.ToString("o"); Data.Save(PathFor("devices", deviceId), record);
                        } else if (Data.Text(record, "lastJobId") != jobId) throw new InvalidDataException("Unknown job result.");
                        Reply(response, new { ok = true }); return;
                    }
                    Reply(response, new { error = "Unknown route." }, 404);
                }
            } catch (UnauthorizedAccessException e) { Data.Log("Management", "Authorization refused on " + request.Url.AbsolutePath + ": " + e.Message); Reply(response, new { error = "Unauthorized. Check the device status in Deploy." }, 401); }
            catch (InvalidDataException e) {Reply(response,new {error=e.Message},400);}
            catch (Exception e) {
                Data.Log("Management", "Request failed: " + e.GetType().Name);
                try { Reply(response, new { error = "Request failed. Check the management service log." }, 400); } catch (Exception) { Data.Log("Management", "Client disconnected before status delivery."); }
            } finally { response.Close(); }
        }
        static string Limit(string value) { return value.Length > 512 ? value.Substring(0, 512) : value; }
        void ExpireSettings(Dictionary<string,object> device) {
            object raw; device.TryGetValue("job",out raw); var job=raw as Dictionary<string,object>; DateTime expires;
            if(job==null || !job.ContainsKey("protectedSettings") || !DateTime.TryParse(Data.Text(job,"settingsExpiresUtc"),out expires) || DateTime.UtcNow<=expires.ToUniversalTime()) return;
            string id=Data.Id(Data.Text(device,"id")), jobId=Data.Id(Data.Text(job,"id"));
            string message=Data.Text(job,"state")=="assigned" ? "Sensitive settings task expired; assigned outcome is unknown." : "Sensitive settings task expired before assignment.";
            Data.Save(PathFor("history",jobId),new {deviceId=id,job=HelperSettings.PublicJob(job),ok=false,message=message,finishedUtc=DateTime.UtcNow.ToString("o")});
            device["job"]=null; device["lastJobId"]=jobId; device["status"]="Expired"; device["message"]=message; Data.Save(PathFor("devices",id),device);
        }
        // Called under gate. Pending requests have no access to inventory, jobs or packages.
        internal void Join(Dictionary<string, object> body, string address, Action<object, int> response) {
            string id = Data.Id(Data.Text(body, "deviceId")), secret = Data.Text(body, "deviceToken");
            if (Convert.FromBase64String(secret).Length != 32) throw new InvalidDataException("Invalid device credential.");
            string hash = Data.Hash(Encoding.UTF8.GetBytes(secret)), path = PathFor("requests", id);
            Dictionary<string, object> request;
            if (File.Exists(path)) {
                request = Data.Read(path);
                if (!Data.Equal(Data.Text(request, "tokenHash"), hash)) throw new UnauthorizedAccessException("Join credential mismatch: " + id);
                DateTime created = DateTime.Parse(Data.Text(request, "createdUtc")).ToUniversalTime();
                if (Data.Text(request, "state") == "pending" && DateTime.UtcNow - created > TimeSpan.FromDays(7)) request["state"] = "expired";
                if (Data.Text(request, "state") == "approved") {
                    string devicePath = PathFor("devices", id);
                    if (!File.Exists(devicePath) || Data.Read(devicePath).ContainsKey("revoked")) request["state"] = "revoked";
                }
                request["lastSeenUtc"] = DateTime.UtcNow.ToString("o"); Data.Save(path, request);
            } else {
                if (File.Exists(PathFor("devices", id))) {
                    var existing = Data.Read(PathFor("devices", id));
                    if (Data.Text(existing, "transport") == "domain" || !Data.Equal(Data.Text(existing, "tokenHash"), hash)) throw new UnauthorizedAccessException("Existing identity cannot request access: " + id);
                    Reply(response, new { state = existing.ContainsKey("revoked") ? "revoked" : "approved", deviceId = id, verification = hash.Substring(0, 12) }); return;
                }
                string directory = Path.Combine(folder, "requests");
                if (Directory.Exists(directory)) {
                    var files = Directory.GetFiles(directory, "*.json"); int recent = 0;
                    foreach (string file in files) {
                        var previous = Data.Read(file); DateTime created = DateTime.Parse(Data.Text(previous, "createdUtc")).ToUniversalTime();
                        if (DateTime.UtcNow - created > TimeSpan.FromDays(7)) { File.Delete(file); continue; }
                        if (Data.Text(previous, "address") == address && DateTime.UtcNow - created < TimeSpan.FromMinutes(1)) recent++;
                    }
                    if (recent >= 10 || Directory.GetFiles(directory, "*.json").Length >= 2000) { Reply(response, new { state = "busy", message = "Too many requests. Retry later." }, 429); return; }
                }
                request = new Dictionary<string, object> { { "id", id }, { "tokenHash", hash }, { "state", "pending" }, { "machine", Limit(Data.Text(body, "machine")) }, { "domain", Limit(Data.Text(body, "domain")) }, { "address", Limit(address) }, { "createdUtc", DateTime.UtcNow.ToString("o") }, { "lastSeenUtc", DateTime.UtcNow.ToString("o") } };
                Data.Save(path, request);
            }
            Reply(response, new { state = Data.Text(request, "state"), deviceId = id, verification = hash.Substring(0, 12) });
        }
        internal void AdminRoute(string route, string method, Dictionary<string, object> body, Action<object, int> response) {
            if(route.StartsWith("admin/rollout/",StringComparison.Ordinal)) {rollout.Route(route.Substring("admin/rollout/".Length),method,body,response);return;}
            if (route == "admin/packages/remove" && method == "POST" && body != null) {
                string sha = Data.Text(body, "sha256");
                if (!Regex.IsMatch(sha, "^[A-F0-9]{64}$")) throw new InvalidDataException("Invalid package hash.");
                string devices = Path.Combine(folder, "devices");
                if (Directory.Exists(devices)) foreach (string path in Directory.GetFiles(devices, "*.json")) {
                    var device = Data.Read(path); object raw;
                    if (device.TryGetValue("job", out raw) && raw is Dictionary<string, object>) {
                        var job = (Dictionary<string, object>)raw;
                        if (Data.Text(job, "action") != "agent-update" && Data.Equal(Data.Text(job, "sha256"), sha)) {
                            Reply(response, new { error = "Package is used by a queued or running task. Finish or cancel that task first." }, 409); return;
                        }
                    }
                }
                string package = Path.Combine(folder, "packages", sha + ".msi");
                string metadata = PathFor("packages", sha);
                if (!File.Exists(package) && !File.Exists(metadata)) { Reply(response, new { error = "Package no longer exists." }, 404); return; }
                File.Delete(package); File.Delete(metadata);
                Reply(response, new { ok = true }); return;
            }
            if (route == "admin/requests" && method == "GET") {
                var requests = new List<object>(); string directory = Path.Combine(folder, "requests");
                if (Directory.Exists(directory)) foreach (string path in Directory.GetFiles(directory, "*.json")) {
                    var request = Data.Read(path);
                    if (Data.Text(request, "state") != "pending" || DateTime.UtcNow - DateTime.Parse(Data.Text(request, "createdUtc")).ToUniversalTime() > TimeSpan.FromDays(7)) continue;
                    request["verification"] = Data.Text(request, "tokenHash").Substring(0, 12); request.Remove("tokenHash"); requests.Add(request);
                }
                Reply(response, new { requests = requests }); return;
            }
            if ((route == "admin/requests/approve" || route == "admin/requests/reject") && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")), path = PathFor("requests", id); var request = Data.Read(path);
                if (Data.Text(request, "state") != "pending" || DateTime.UtcNow - DateTime.Parse(Data.Text(request, "createdUtc")).ToUniversalTime() > TimeSpan.FromDays(7)) { Reply(response, new { error = "Request is no longer pending." }, 409); return; }
                bool approve = route.EndsWith("/approve", StringComparison.Ordinal);
                if (approve) {
                    string devicePath = PathFor("devices", id);
                    if (File.Exists(devicePath)) { Reply(response, new { error = "An identity already exists. Create a fresh request." }, 409); return; }
                    Data.Save(devicePath, new { id = id, name = Data.Text(request, "machine"), machine = Data.Text(request, "machine"), domain = Data.Text(request, "domain"), address = Data.Text(request, "address"), transport = "agent", tokenHash = Data.Text(request, "tokenHash"), status = "Approved — waiting for Agent", lastSeenUtc = "", job = (object)null });
                }
                request["state"] = approve ? "approved" : "rejected"; request["decidedUtc"] = DateTime.UtcNow.ToString("o"); Data.Save(path, request);
                Reply(response, new { ok = true }); return;
            }
            if ((route == "admin/packages" || route == "admin/agent-packages") && method == "GET") {
                bool agents=route=="admin/agent-packages";
                var packages = new List<object>(); string directory = Path.Combine(folder,agents ? "agent-packages" : "packages");
                if (Directory.Exists(directory)) foreach (string path in Directory.GetFiles(directory,"*.json")) {
                    var package = Data.Read(path); string sha = Data.Text(package,"sha256");
                    if (Regex.IsMatch(sha,"^[A-F0-9]{64}$") && File.Exists(Path.Combine(directory,sha+(agents ? ".exe" : ".msi")))) packages.Add(package);
                }
                Reply(response,new { packages = packages }); return;
            }
            if (route == "admin/history" && method == "GET") {
                var history = new List<object>(); string directory = Path.Combine(folder, "history");
                if (Directory.Exists(directory)) {
                    var files = new DirectoryInfo(directory).GetFiles("*.json");
                    Array.Sort(files, (a, b) => b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc));
                    for (int index = 0; index < Math.Min(files.Length, 200); index++) history.Add(Data.Read(files[index].FullName));
                }
                Reply(response, new { history = history }); return;
            }
            if (route == "admin/cancel" && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")); string file = PathFor("devices", id); var device = Data.Read(file);
                object raw; device.TryGetValue("job", out raw); var job = raw as Dictionary<string, object>;
                if (job != null && Data.Text(job, "state") == "queued") {
                    Data.Save(PathFor("history", Data.Id(Data.Text(job, "id"))), new { deviceId = id, job = HelperSettings.PublicJob(job), ok = false, message = "Cancelled before assignment.", finishedUtc = DateTime.UtcNow.ToString("o") });
                    device["job"] = null; device["status"] = "Cancelled"; Data.Save(file, device);
                    Reply(response, new { ok = true });
                } else Reply(response, new { error = "Only queued jobs can be cancelled. Running operations cannot be interrupted." }, 409);
                return;
            }
            if (route == "admin/devices" && method == "GET") {
                var devices = new List<object>(); string directory = Path.Combine(folder, "devices");
                if (Directory.Exists(directory)) foreach (string file in Directory.GetFiles(directory, "*.json")) {
                    var device = Data.Read(file); ExpireSettings(device); device.Remove("tokenHash");
                    if(device.ContainsKey("job") && device["job"] is Dictionary<string,object>) device["job"]=HelperSettings.PublicJob((Dictionary<string,object>)device["job"]);
                    if (device.ContainsKey("hidden")) continue;
                    DateTime seen; bool online = DateTime.TryParse(Data.Text(device, "lastSeenUtc"), out seen) && DateTime.UtcNow - seen.ToUniversalTime() < TimeSpan.FromSeconds(90);
                    device["online"] = online && !device.ContainsKey("revoked");
                    if (!device.ContainsKey("transport")) device["transport"] = "agent";
                    if (Data.Text(device, "transport") == "domain") {
                        DateTime checkedAt;
                        device["online"] = Data.Text(device, "connectionState") == "ready" && DateTime.TryParse(Data.Text(device, "checkedUtc"), out checkedAt) && DateTime.UtcNow - checkedAt.ToUniversalTime() < TimeSpan.FromMinutes(5);
                    }
                    devices.Add(device);
                }
                Reply(response, new { devices = devices }); return;
            }
            if (route == "admin/domain/import" && body != null) {
                var existing = new HashSet<string>(StringComparer.OrdinalIgnoreCase); string directory = Path.Combine(folder, "devices");
                if (Directory.Exists(directory)) foreach (string file in Directory.GetFiles(directory, "*.json")) { var record = Data.Read(file); if (Data.Text(record, "transport") == "domain") existing.Add(Data.Text(record, "address")); }
                var targets = body["targets"] as IEnumerable; if (targets == null) throw new InvalidDataException("Missing domain devices.");
                int added = 0;
                foreach (object raw in targets) {
                    string target = Convert.ToString(raw).Trim();
                    if (!Regex.IsMatch(target, "^[A-Za-z0-9][A-Za-z0-9.\\-]{0,252}$")) throw new InvalidDataException("Invalid hostname or IPv4 address.");
                    if (!existing.Add(target)) continue;
                    string id = Guid.NewGuid().ToString("D");
                    Data.Save(PathFor("devices", id), new { id = id, name = target, machine = target, address = target, transport = "domain", status = "Not tested", connectionState = "unknown", helperVersion = "", group = Limit(Data.Text(body, "group")), job = (object)null, createdUtc = DateTime.UtcNow.ToString("o") }); added++;
                }
                Reply(response, new { added = added }); return;
            }
            if (route == "admin/domain/result" && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")); string file = PathFor("devices", id); var device = Data.Read(file);
                if (Data.Text(device, "transport") != "domain") throw new InvalidDataException("Not a domain transport device.");
                bool ok = body.ContainsKey("ok") && body["ok"] is bool && (bool)body["ok"];
                string action = Data.Text(body, "action"); if (action != "test" && !HelperActions.Allowed(action)) throw new InvalidDataException("Unknown domain task.");
                device["checkedUtc"] = DateTime.UtcNow.ToString("o"); device["message"] = Limit(Data.Text(body, "message"));
                device["status"] = ok ? (action == "test" ? "Ready" : "Succeeded") : "Failed";
                device["connectionState"] = ok ? "ready" : "failed";
                object rawInventory;
                if (ok && body.TryGetValue("inventory", out rawInventory) && rawInventory is Dictionary<string, object>) {
                    var inventory = (Dictionary<string, object>)rawInventory;
                    foreach (string key in new[] { "helperVersion", "helperService", "machine", "domain", "operatingSystem", "architecture", "domainJoined", "inventoryWarning" }) if (inventory.ContainsKey(key)) device[key] = Limit(Data.Text(inventory, key));
                }
                if (ok && action == "install") device["helperVersion"] = Limit(Data.Text(body, "version"));
                if (ok && action == "uninstall") { device["helperVersion"] = ""; device["helperService"] = "Not installed"; }
                if (ok && action == "stop") device["helperService"] = "Stopped";
                if (ok && (action == "start" || action == "restart" || action == "repair" || action == "install")) device["helperService"] = "Running";
                Data.Save(file, device);
                string jobId = Guid.NewGuid().ToString("D");
                Data.Save(PathFor("history", jobId), new { deviceId = id, job = new { id = jobId, action = action, transport = "domain" }, ok = ok, message = device["message"], finishedUtc = DateTime.UtcNow.ToString("o") });
                Reply(response, new { ok = true }); return;
            }
            if (route == "admin/device/edit" && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")); string file = PathFor("devices", id); var device = Data.Read(file);
                string name = Limit(Data.Text(body, "name")).Trim(); if (name == "") throw new InvalidDataException("Device name required.");
                if (name != Data.Text(device, "name")) device["nameIsCustom"] = true;
                device["name"] = name; device["group"] = Limit(Data.Text(body, "group")); Data.Save(file, device); Reply(response, new { ok = true }); return;
            }
            if (route == "admin/device/remove" && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")); string file = PathFor("devices", id); var device = Data.Read(file);
                if (device.ContainsKey("job") && device["job"] != null) throw new InvalidDataException("Cancel or finish its task first.");
                if (Data.Text(device, "transport") != "domain" && !device.ContainsKey("revoked")) throw new InvalidDataException("Revoke Agent access before removing its record.");
                if (Data.Text(device, "transport") == "domain") File.Delete(file);
                else { device["hidden"] = true; Data.Save(file, device); }
                Reply(response, new { ok = true }); return;
            }
            if (route == "admin/enrollment" && body != null) {
                string name = Limit(Data.Text(body, "name")); if (name.Trim() == "") throw new InvalidDataException("Device label required.");
                string token = Data.Secret();
                Data.Save(PathFor("enrollments", Data.Hash(Encoding.UTF8.GetBytes(token))), new { name = name, group = Limit(Data.Text(body, "group")), expiresUtc = DateTime.UtcNow.AddHours(24).ToString("o") });
                Reply(response, new { server = Data.Text(config, "server"), certificateSha256 = Data.Text(config, "certificateSha256"), enrollmentToken = token, name = name }); return;
            }
            if (route == "admin/revoke" && body != null) {
                string id = Data.Id(Data.Text(body, "deviceId")); string file = PathFor("devices", id); var device = Data.Read(file);
                object raw; device.TryGetValue("job", out raw); var job = raw as Dictionary<string, object>;
                if (job != null) Data.Save(PathFor("history", Data.Id(Data.Text(job,"id"))), new { deviceId=id, job=HelperSettings.PublicJob(job), ok=false, message=Data.Text(job,"state")=="queued" ? "Cancelled by revocation before assignment." : "Access revoked while task assigned. Final outcome unknown.", finishedUtc=DateTime.UtcNow.ToString("o") });
                device["revoked"] = true; device["job"] = null; device["status"] = "Revoked"; Data.Save(file, device); Reply(response, new { ok = true }); return;
            }
            if (route == "admin/jobs" && body != null) {
                string action = Data.Text(body, "action"); if (action == "") action = "install";
                if (action!="agent-update" && action!="configure-helper" && !HelperActions.Allowed(action)) throw new InvalidDataException("Unsupported action.");
                object rawSettings; body.TryGetValue("settings",out rawSettings); var settings=rawSettings as Dictionary<string,object>;
                if(rawSettings!=null && settings==null) throw new InvalidDataException("Invalid Helper settings payload.");
                if(settings!=null) {
                    settings=HelperSettings.Validate(settings);
                    if(action!="install" && action!="configure-helper") throw new InvalidDataException("Helper settings are not allowed for this action.");
                    if(action=="install" && Data.Text(settings,"operation")!="unattended-password") throw new InvalidDataException("Only unattended password can be set during installation.");
                }
                if(action=="configure-helper" && settings==null) throw new InvalidDataException("Helper settings are required.");
                var metadata = new Dictionary<string, object>();
                if (action == "install" || action == "agent-update") {
                    string sha = Data.Text(body, "sha256"); if (!Regex.IsMatch(sha, "^[A-F0-9]{64}$")) throw new InvalidDataException("Invalid package.");
                    metadata = Data.Read(PathFor(action=="agent-update" ? "agent-packages" : "packages", sha));
                    if(settings!=null && action=="install" && !Msi.SupportsUnattended(Path.Combine(folder,"packages",sha+".msi"))) throw new InvalidDataException("Selected Helper MSI does not support unattended password installation.");
                }
                var results = new List<object>();
                var ids = body["deviceIds"] as IEnumerable; if (ids == null) throw new InvalidDataException("Select devices.");
                foreach (object rawId in ids) {
                    string id = Data.Id(Convert.ToString(rawId)); string file = PathFor("devices", id); var device = Data.Read(file);
                    if (Data.Text(device, "transport") == "domain") { results.Add(new { id = id, queued = false }); continue; }
                    if (device.ContainsKey("revoked") || (device.ContainsKey("job") && device["job"] != null)) { results.Add(new { id = id, queued = false }); continue; }
                    Version agentVersion;
                    if(settings!=null) {
                        string protocol=Data.Text(device,"helperSettingsProtocol"); bool receiver=Data.Text(settings,"operation")!="unattended-password";
                        if((protocol!="1" && protocol!="2") || !Version.TryParse(Data.Text(device,"agentVersion"),out agentVersion) || agentVersion<new Version(1,5,0,0)) {results.Add(new {id=id,queued=false,reason="Agent 1.5.0+ is required for Helper settings."}); continue;}
                        if(receiver && (protocol!="2" || agentVersion<new Version(1,6,0,0) || Data.Text(device,"receiverPolicyProtocol")!="1")) {results.Add(new {id=id,queued=false,reason="Device-wide receiver policy requires Agent 1.6.0+ and Helper 1.4.5+."}); continue;}
                    }
                    if (action=="agent-update") {
                        Version target;
                        if (Data.Text(device,"agentUpdateProtocol")!="1" || !Version.TryParse(Data.Text(device,"agentVersion"),out agentVersion) || agentVersion<new Version(1,4,0,0)) { results.Add(new {id=id,queued=false,reason="Agent 1.4.0+ must be installed once before dashboard updates are supported."}); continue; }
                        if (!Version.TryParse(Data.Text(metadata,"version"),out target) || target<=agentVersion) { results.Add(new {id=id,queued=false,reason="Selected Agent version must be newer than the installed version."}); continue; }
                    }
                    if (action != "install" && (!Version.TryParse(Data.Text(device, "agentVersion"), out agentVersion) || agentVersion < new Version("1.1.0"))) { results.Add(new { id = id, queued = false }); continue; }
                    var job = new Dictionary<string, object>(metadata); job["id"] = Guid.NewGuid().ToString("D"); job["state"] = "queued";
                    job["action"] = action; job["createdUtc"] = DateTime.UtcNow.ToString("o");
                    if(settings!=null) {job["protectedSettings"]=HelperSettings.Protect(settings); job["settingsOperation"]=Data.Text(settings,"operation"); job["settingsExpiresUtc"]=DateTime.UtcNow.AddHours(24).ToString("o");}
                    device["job"] = job; device["status"] = "Queued"; device["message"] = ""; Data.Save(file, device); results.Add(new { id = id, queued = true });
                }
                Reply(response, new { results = results }); return;
            }
            Reply(response, new { error = "Unknown admin route." }, 404);
        }
    }
}
