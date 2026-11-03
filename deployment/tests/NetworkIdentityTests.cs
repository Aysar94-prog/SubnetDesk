using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SubnetDesk.Deployment;

internal static class NetworkIdentityTests {
    static void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }
    static string Send(int port, IPAddress address, string route, string id, string token, object body) {
        byte[] payload = Encoding.UTF8.GetBytes(Data.Json(body));
        using (var client = new TcpClient(address.AddressFamily)) {
            client.ReceiveTimeout = 5000; client.SendTimeout = 5000; client.Connect(address, port);
            using (var stream = client.GetStream()) {
                byte[] header = Encoding.ASCII.GetBytes("POST /subnetdesk/" + route + " HTTP/1.1\r\nHost: localhost:" + port + "\r\nAuthorization: Bearer " + token + "\r\nX-Device-Id: " + id + "\r\nContent-Type: application/json\r\nContent-Length: " + payload.Length + "\r\nConnection: close\r\n\r\n");
                stream.Write(header, 0, header.Length); stream.Write(payload, 0, payload.Length);
                using (var reader = new StreamReader(stream, Encoding.UTF8)) return reader.ReadToEnd();
            }
        }
    }
    internal static void Run() {
        string root = Path.Combine(Path.GetTempPath(), "SubnetDesk-Network-" + Guid.NewGuid().ToString("N"));
        string id = Guid.NewGuid().ToString("D"), token = Data.Secret(), admin = Data.Secret(), jobId = Guid.NewGuid().ToString("D");
        var reservation = new TcpListener(IPAddress.Loopback, 0); reservation.Start(); int port = ((IPEndPoint)reservation.LocalEndpoint).Port; reservation.Stop();
        Data.Save(Path.Combine(root, "config.json"), new { server = "https://localhost/subnetdesk/", adminToken = admin });
        string devicePath = Path.Combine(root, "devices", id + ".json");
        Data.Save(devicePath, new { id = id, tokenHash = Data.Hash(Encoding.UTF8.GetBytes(token)), name = "BEFORE", machine = "BEFORE", transport = "agent", group = "HQ", status = "Queued", job = new { id = jobId, action = "restart", state = "queued" } });
        var server = new ManagementServer(root, null, "http://localhost:" + port + "/subnetdesk/");
        using (var cancel = new CancellationTokenSource()) {
            var running = Task.Run(() => server.Run(cancel.Token));
            try {
                bool listening = false;
                for (int attempt = 0; attempt < 40; attempt++) {
                    try { using (var probe = new TcpClient()) probe.Connect(IPAddress.Loopback, port); listening = true; break; }
                    catch (SocketException) { Thread.Sleep(50); }
                }
                Assert(listening, "Test listener unavailable. Run the network test as administrator; no firewall or URL reservations are changed.");
                string windows = ComputerFacts.OperatingSystemName();
                string reply = Send(port, IPAddress.Loopback, "poll", id, token, new { machine = "BEFORE", agentVersion = "1.3.1", operatingSystem = windows });
                Assert(reply.StartsWith("HTTP/1.1 200") && reply.Contains(jobId), "Initial authenticated poll receives existing task");
                Assert(Data.Text(Data.Read(devicePath), "address") == "127.0.0.1", "Initial source IPv4 stored");
                reply = Send(port, IPAddress.IPv6Loopback, "heartbeat", id, token, new { machine = "BEFORE", agentVersion = "1.3.1" });
                var saved = Data.Read(devicePath);
                Assert(reply.StartsWith("HTTP/1.1 200") && Data.Text(saved, "address") == "::1", "Changed real connection address updates inventory");
                Assert(Data.Text(saved,"machine") == "BEFORE" && Data.Text(saved,"name") == "BEFORE", "Address change alone preserves machine name");
                Assert(Data.Text(saved,"operatingSystem") == windows && !windows.Contains("Windows NT"), "Actual Windows caption reaches persisted inventory");
                reply = Send(port, IPAddress.IPv6Loopback, "heartbeat", id, token, new { machine = "AFTER", agentVersion = "1.3.1" });
                saved = Data.Read(devicePath);
                Assert(Data.Text(saved,"address") == "::1", "Name change alone preserves current address");
                Assert(Data.Text(saved, "machine") == "AFTER" && Data.Text(saved, "name") == "AFTER", "Machine rename updates automatic display name");
                Assert(Data.Text(saved, "id") == id && Data.Text(saved, "group") == "HQ" && Data.Text((Dictionary<string,object>)saved["job"], "id") == jobId, "Identity, group and active task survive address/name change");
                reply = Send(port, IPAddress.IPv6Loopback, "poll", id, token, new { machine = "AFTER", agentVersion = "1.3.1" });
                Assert(reply.StartsWith("HTTP/1.1 200") && reply.Contains(jobId), "Same task remains available after reconnect");
                reply = Send(port, IPAddress.Loopback, "admin/device/edit", id, admin, new { deviceId = id, name = "Finance reception", group = "HQ" });
                Assert(reply.StartsWith("HTTP/1.1 200"), "Admin custom name accepted");
                reply = Send(port, IPAddress.Loopback, "poll", id, token, new { machine = "AFTER-SECOND-RENAME", agentVersion = "1.3.1" });
                saved = Data.Read(devicePath);
                Assert(Data.Text(saved,"name") == "Finance reception" && Data.Text(saved,"machine") == "AFTER-SECOND-RENAME", "Custom display name preserved while actual machine name refreshes");
                reply = Send(port, IPAddress.IPv6Loopback, "poll", id, Data.Secret(), new { machine = "IMPOSTOR" });
                saved = Data.Read(devicePath);
                Assert(reply.StartsWith("HTTP/1.1 401") && Data.Text(saved,"machine") == "AFTER-SECOND-RENAME" && Data.Text(saved,"address") == "127.0.0.1", "Invalid credentials cannot replace name or address");
                Assert(Directory.GetFiles(Path.Combine(root,"devices"),"*.json").Length == 1, "No duplicate device records");
                AgentUpdateTests.Network(port,root,id,token,admin,jobId);
                HelperSecurityTests.Network(port,root,id,token,admin);
                var rolloutProfile=new {name="Synthetic schedule test",username="Administrator",password="not-a-real-password",accountType="local"};
                reply=Send(port,IPAddress.Loopback,"admin/rollout/profile",id,token,rolloutProfile);
                Assert(reply.StartsWith("HTTP/1.1 401") && !Directory.Exists(Path.Combine(root,"rollout","profiles")),"Agent credentials cannot save privileged rollout profiles");
                reply=Send(port,IPAddress.Loopback,"admin/rollout/profile",id,admin,rolloutProfile);
                Assert(reply.StartsWith("HTTP/1.1 200") && !reply.Contains("not-a-real-password") && !reply.Contains("protectedCredential"),"Admin profile creation redacts credentials over HTTP");
                string profileId=Data.Text(Data.Read(Directory.GetFiles(Path.Combine(root,"rollout","profiles"),"*.json")[0]),"id");
                reply=Send(port,IPAddress.Loopback,"admin/rollout/schedule",id,admin,new {kind="discover",name="Future only",profileId=profileId,ranges="192.0.2.0/24",nextRunUtc=DateTime.UtcNow.AddDays(1).ToString("o"),intervalMinutes=1440,parallelism=20});
                Assert(reply.StartsWith("HTTP/1.1 200") && Directory.GetFiles(Path.Combine(root,"rollout","schedules"),"*.json").Length==1,"Future discovery schedule persists through authenticated HTTP without scanning");
                Console.WriteLine("PASS rollout HTTP authorization: Agent denied, administrator accepted, credentials redacted, future schedule persisted without a network scan.");
                Console.WriteLine("PASS HTTP integration: actual IPv4 -> IPv6 -> IPv4 connections, machine rename, custom name preservation, same identity/group/task, no duplicates, invalid credential rejection.");
                Console.WriteLine("Local Windows inventory: " + ComputerFacts.OperatingSystemName());
            } finally { cancel.Cancel(); server.Stop(); Assert(running.Wait(5000), "Test server did not stop"); if (Directory.Exists(root)) Directory.Delete(root,true); }
        }
    }
}
