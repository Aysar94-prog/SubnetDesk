using System;
using System.Collections.Generic;
using System.IO;
using SubnetDesk.Deployment;

internal static class InventoryContractTests {
    static void Assert(bool value, string name) { if (!value) throw new Exception("Inventory contract: " + name); }
    static Dictionary<string, object> Call(ManagementServer server, string route, object body, out int code) {
        int status = 0; Dictionary<string, object> reply = null;
        server.AdminRoute("admin/" + route, body == null ? "GET" : "POST", body == null ? null : Data.Parse(Data.Json(body)), (value, result) => { status = result; reply = Data.Parse(Data.Json(value)); });
        code = status; return reply;
    }
    internal static void Run() {
        string root = Path.Combine(Path.GetTempPath(), "SubnetDesk-Inventory-Test-" + Guid.NewGuid().ToString("N"));
        try {
            var server = new ManagementServer(root); int code;
            string joinId = Guid.NewGuid().ToString("D"), joinToken = Data.Secret();
            Dictionary<string, object> joined = null;
            var joinBody = Data.Parse(Data.Json(new { deviceId = joinId, deviceToken = joinToken, machine = "REQUEST-PC", domain = "WORKGROUP" }));
            server.Join(joinBody, "192.0.2.10", (value, status) => { joined = Data.Parse(Data.Json(value)); });
            Assert(Data.Text(joined, "state") == "pending" && !File.Exists(Path.Combine(root,"devices",joinId+".json")), "unapproved request has no device access");
            var pending = Call(server,"requests",null,out code);
            Assert(!Data.Json(pending).Contains(joinToken) && !Data.Json(pending).Contains("tokenHash") && ((System.Collections.IList)pending["requests"]).Count == 1, "pending listing excludes secrets");
            bool wrongJoin = false;
            try { server.Join(Data.Parse(Data.Json(new { deviceId=joinId,deviceToken=Data.Secret() })),"192.0.2.10",(value,status)=>{}); } catch (UnauthorizedAccessException) { wrongJoin = true; }
            Assert(wrongJoin, "another credential cannot replace pending identity");
            Call(server,"requests/approve",new {deviceId=joinId},out code);
            Assert(code == 200 && File.Exists(Path.Combine(root,"devices",joinId+".json")), "explicit approval creates device");
            server = new ManagementServer(root);
            server.Join(joinBody,"192.0.2.10",(value,status)=>{joined=Data.Parse(Data.Json(value));});
            Assert(Data.Text(joined,"state")=="approved", "approval survives restart and lost response");
            Call(server,"revoke",new {deviceId=joinId},out code);
            server.Join(joinBody,"192.0.2.10",(value,status)=>{joined=Data.Parse(Data.Json(value));});
            Assert(Data.Text(joined,"state")=="revoked", "join cannot restore revoked access");
            Call(server,"device/remove",new {deviceId=joinId},out code);
            string rejectedId=Guid.NewGuid().ToString("D");
            var rejectedBody=Data.Parse(Data.Json(new {deviceId=rejectedId,deviceToken=Data.Secret(),machine="REJECT-PC"}));
            server.Join(rejectedBody,"192.0.2.11",(value,status)=>{});
            Call(server,"requests/reject",new {deviceId=rejectedId},out code);
            server.Join(rejectedBody,"192.0.2.11",(value,status)=>{joined=Data.Parse(Data.Json(value));});
            Assert(Data.Text(joined,"state")=="rejected" && !File.Exists(Path.Combine(root,"devices",rejectedId+".json")),"rejection persists without creating device");
            string expiredId=Guid.NewGuid().ToString("D");
            var expiredBody=Data.Parse(Data.Json(new {deviceId=expiredId,deviceToken=Data.Secret(),machine="EXPIRED-PC"}));
            server.Join(expiredBody,"192.0.2.12",(value,status)=>{});
            string expiredPath=Path.Combine(root,"requests",expiredId+".json");
            var expired=Data.Read(expiredPath); expired["createdUtc"]=DateTime.UtcNow.AddDays(-8).ToString("o"); Data.Save(expiredPath,expired);
            Call(server,"requests/approve",new {deviceId=expiredId},out code);
            Assert(code==409 && !File.Exists(Path.Combine(root,"devices",expiredId+".json")),"expired requests cannot be approved");
            for(int i=0;i<11;i++) {
                int joinStatus=0;
                server.Join(Data.Parse(Data.Json(new {deviceId=Guid.NewGuid().ToString("D"),deviceToken=Data.Secret(),machine="RATE-PC"})),"192.0.2.20",(value,status)=>{joinStatus=status;});
                Assert(joinStatus==(i==10 ? 429 : 200),"new request rate limit");
            }
            Console.WriteLine("PASS: pending access denied, request secrets excluded, credential substitution denied, explicit approval, restart recovery, persistent rejection and revoked identity protection.");
            var reply = Call(server, "domain/import", new { targets = new[] { "PC-01.example.local", "PC-02.example.local", "pc-01.example.local" }, group = "HQ" }, out code);
            Assert(code == 200 && Convert.ToInt32(reply["added"]) == 2, "persistent domain import deduplicates case");
            reply = Call(server, "devices", null, out code); var rows = (System.Collections.IList)reply["devices"]; Assert(rows.Count == 2, "unified listing");
            var first = (Dictionary<string, object>)rows[0]; string id = Data.Text(first, "id"); Assert(!(bool)first["online"], "untested domain is not online");
            Call(server, "device/edit", new { deviceId = id, name = "Finance desktop", group = "Finance" }, out code);
            Call(server, "domain/result", new { deviceId = id, action = "test", ok = true, message = "Verified", inventory = new { helperVersion = "1.4.4.104", helperService = "Running", domainJoined = true } }, out code);
            var saved = Data.Read(Path.Combine(root, "devices", id + ".json")); Assert(Data.Text(saved,"group") == "Finance" && Data.Text(saved,"helperVersion") == "1.4.4.104", "facts and group retained");
            Call(server, "domain/result", new { deviceId = id, action = "test", ok = false, message = "Access denied" }, out code);
            saved = Data.Read(Path.Combine(root, "devices", id + ".json")); Assert(Data.Text(saved,"connectionState") == "failed", "failure changes verification state");
            bool denied = false; try { Call(server, "domain/result", new { deviceId=id, action="powershell", ok=true }, out code); } catch (InvalidDataException) { denied = true; } Assert(denied,"arbitrary actions rejected");
            string agentId = Guid.NewGuid().ToString("D"); string agentPath = Path.Combine(root,"devices",agentId+".json");
            Data.Save(agentPath,new { id=agentId,name="Agent device",transport="agent",agentVersion="1.2.0",tokenHash="secret-not-for-ui",job=(object)null });
            var incompatible=Data.Read(agentPath); incompatible["agentVersion"]="unknown"; Data.Save(agentPath,incompatible);
            reply=Call(server,"jobs",new {action="repair",deviceIds=new[]{agentId}},out code); Assert(code==200 && Data.Read(agentPath)["job"]==null,"unknown Agent versions cannot receive new lifecycle commands");
            incompatible["agentVersion"]="1.2.0"; Data.Save(agentPath,incompatible);
            Call(server,"jobs",new {action="restart",deviceIds=new[]{agentId}},out code);
            saved=Data.Read(agentPath); Assert(saved["job"] != null,"agent queue persisted");
            Call(server,"cancel",new {deviceId=agentId},out code); Assert(code==200 && Data.Read(agentPath)["job"]==null,"queued cancellation");
            Call(server,"jobs",new {action="restart",deviceIds=new[]{agentId}},out code); saved=Data.Read(agentPath); ((Dictionary<string,object>)saved["job"])["state"]="assigned"; Data.Save(agentPath,saved);
            Call(server,"cancel",new {deviceId=agentId},out code); Assert(code==409 && Data.Read(agentPath)["job"]!=null,"assigned work cannot be cancelled");
            Call(server,"revoke",new {deviceId=agentId},out code); Call(server,"device/remove",new {deviceId=agentId},out code);
            Assert(File.Exists(agentPath) && Data.Read(agentPath).ContainsKey("revoked"),"removed Agent retains revocation tombstone");
            reply=Call(server,"devices",null,out code); Assert(!Data.Json(reply).Contains("secret-not-for-ui") && !Data.Json(reply).Contains(agentId),"credentials and removed records excluded");
            reply=Call(server,"history",null,out code); Assert(((System.Collections.IList)reply["history"]).Count>=3,"persistent result and cancellation history");
            var reloaded=new ManagementServer(root); reply=Call(reloaded,"devices",null,out code); Assert(((System.Collections.IList)reply["devices"]).Count==2,"inventory survives server restart");
            Console.WriteLine("PASS: domain import, unified inventory, groups, live facts, safe actions, queue/cancel, revocation, history and restart persistence.");
        } finally { if (Directory.Exists(root)) Directory.Delete(root,true); }
    }
}
