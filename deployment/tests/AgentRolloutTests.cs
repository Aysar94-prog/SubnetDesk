using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using SubnetDesk.Deployment;

internal static class AgentRolloutTests {
    sealed class Fake : IWindowsAgentPush {
        internal int pushed;
        public Dictionary<string,object> Probe(string target,Dictionary<string,object> credential) {
            if(target=="linux") return new Dictionary<string,object>{{"verifiedWindows",false}};
            if(target=="offline") throw new IOException("synthetic offline");
            if(target.StartsWith("RPC-")) throw new System.Runtime.InteropServices.COMException("synthetic-secret",unchecked((int)0x800706ba));
            if(Data.Text(credential,"password")!="synthetic-secret") throw new Exception("Credential decryption failed");
            return new Dictionary<string,object>{{"target",target},{"machine","PC-"+target},{"uuid",Guid.NewGuid().ToString("D")},{"verifiedWindows",true},{"windowsVersion","Windows 11 Pro"},{"agentService","Not installed"}};
        }
        public string Push(Dictionary<string,object> device,Dictionary<string,object> credential,string setup,Dictionary<string,object> server,CancellationToken stop) {Interlocked.Increment(ref pushed);return "Synthetic success";}
    }
    static void Assert(bool value,[System.Runtime.CompilerServices.CallerLineNumber]int line=0) {if(!value)throw new Exception("Agent rollout regression at line "+line);}
    static void Reject<T>(Action action) where T:Exception {bool rejected=false;try{action();}catch(T){rejected=true;}Assert(rejected);}
    static Dictionary<string,object> Call(AgentRollout rollout,string route,Dictionary<string,object> body=null) {
        Dictionary<string,object> result=null;
        rollout.Route(route,body==null ? "GET" : "POST",body,(value,status)=>{Assert(status==200);result=Data.Parse(Data.Json(value));});return result;
    }
    static Dictionary<string,object>[] Rows(Dictionary<string,object> value,string key) {return ((IEnumerable)value[key]).Cast<Dictionary<string,object>>().ToArray();}
    internal static void Run() {
        Assert(AgentRollout.Targets("192.0.2.0/24").Count==254);
        Assert(AgentRollout.Targets("192.0.2.0/31").Count==2);
        Assert(AgentRollout.Targets("192.0.2.4/32,192.0.2.4;PC-A;pc-a").Count==2);
        Assert(AgentRollout.Targets("192.0.0.1-192.0.2.88").Count==600);
        bool rejected=false;try{AgentRollout.Targets("192.0.0.0/8");}catch(InvalidDataException){rejected=true;}Assert(rejected);
        string root=Path.Combine(Path.GetTempPath(),"SubnetDesk-RolloutTest-"+Guid.NewGuid().ToString("N"));
        var fake=new Fake();Func<Dictionary<string,object>> settings=()=>new Dictionary<string,object>{{"server","https://management.example/subnetdesk/"},{"certificateSha256",new string('A',64)}};
        var rollout=new AgentRollout(root,settings,fake,"unused");
        try {
            var profile=Call(rollout,"profile",new Dictionary<string,object>{{"name","Lab"},{"username",".\\Administrator"},{"accountType","local"},{"password","synthetic-secret"}});
            string id=Data.Text(profile,"id");
            Assert(!File.ReadAllText(Path.Combine(root,"rollout","profiles",id+".json")).Contains("synthetic-secret"));
            var duplicate=new Dictionary<string,object>{{"name","  lAb  "},{"username","Administrator"},{"accountType","local"},{"password","synthetic-secret"}};
            Reject<InvalidDataException>(()=>Call(rollout,"profile",duplicate));
            var edit=new Dictionary<string,object>(duplicate);edit["id"]=id;edit["name"]="Lab updated";edit["password"]="";
            Assert(Data.Text(Call(rollout,"profile",edit),"id")==id);
            var wrongAccount=new Dictionary<string,object>(edit);wrongAccount["username"]="DifferentAdmin";
            Reject<InvalidDataException>(()=>Call(rollout,"profile",wrongAccount));
            duplicate["name"]="Disposable";
            string disposableId=Data.Text(Call(rollout,"profile",duplicate),"id");
            var conflictingName=new Dictionary<string,object>(edit);conflictingName["name"]=" disposable ";
            Reject<InvalidDataException>(()=>Call(rollout,"profile",conflictingName));
            Call(rollout,"profile-delete",new Dictionary<string,object>{{"id",disposableId}});
            Assert(Rows(Call(rollout,"status"),"profiles").Length==1);
            var plan=new Dictionary<string,object>{{"profileId",id},{"ranges","windows,linux,offline"},{"parallelism",20}};
            Call(rollout,"discover",plan);
            Reject<InvalidOperationException>(()=>Call(rollout,"profile-delete",new Dictionary<string,object>{{"id",id}}));
            Reject<InvalidOperationException>(()=>Call(rollout,"profile",edit));
            Assert(rollout.ProcessNext(CancellationToken.None));
            var status=Call(rollout,"status");var devices=Rows(status,"devices");Assert(devices.Length==1);
            var jobs=Rows(status,"jobs");Assert(Data.Text(jobs[0],"completed")=="3" && Data.Text(jobs[0],"failed")=="2" && Data.Text(jobs[0],"windows")=="1");
            Assert(!Data.Json(status).Contains("protectedCredential") && !Data.Json(status).Contains("synthetic-secret"));
            var failures=Rows(jobs[0],"failures");Assert(failures.Length==2 && failures.Sum(f=>Convert.ToInt32(f["count"]))==2);
            Assert(failures.Any(f=>((IEnumerable)f["targets"]).Cast<string>().Contains("offline")));
            var changed=new Dictionary<string,object>(devices[0]);Assert(WindowsAgentPush.SameDevice(devices[0],changed));changed["uuid"]=Guid.NewGuid().ToString("D");Assert(!WindowsAgentPush.SameDevice(devices[0],changed));
            changed=new Dictionary<string,object>(devices[0]);changed["machine"]="REASSIGNED";Assert(!WindowsAgentPush.SameDevice(devices[0],changed));
            var push=new Dictionary<string,object>{{"profileId",id},{"deviceIds",new[]{Data.Text(devices[0],"id")}},{"parallelism",20}};
            Call(rollout,"push",push);Assert(rollout.ProcessNext(CancellationToken.None) && fake.pushed==1);
            DateTime first=DateTime.UtcNow.AddHours(1);
            var discoverSchedule=new Dictionary<string,object>(plan){{"kind","discover"},{"name","Night discovery"},{"nextRunUtc",first.ToString("o")},{"intervalMinutes",60}};
            var pushSchedule=new Dictionary<string,object>(push){{"kind","push"},{"name","Morning push"},{"nextRunUtc",first.AddHours(1).ToString("o")},{"intervalMinutes",1440}};
            string discoveryId=Data.Text(Call(rollout,"schedule",discoverSchedule),"id");Call(rollout,"schedule",pushSchedule);
            rollout=new AgentRollout(root,settings,fake,"unused"); // persistence across console/service object recreation
            rollout.Tick(first.AddMinutes(1));status=Call(rollout,"status");Assert(Rows(status,"schedules").Length==2);
            Assert(Rows(status,"jobs").Count(j=>Data.Text(j,"state")=="queued")==1);
            rollout.Tick(first.AddHours(5));status=Call(rollout,"status"); // missed runs coalesce, outstanding discovery not duplicated
            Assert(Rows(status,"jobs").Count(j=>Data.Text(j,"state")=="queued")==2);
            Assert(rollout.ProcessNext(CancellationToken.None));Assert(rollout.ProcessNext(CancellationToken.None));Assert(fake.pushed==2);
            Call(rollout,"schedule-toggle",new Dictionary<string,object>{{"id",discoveryId},{"enabled",false}});
            Reject<InvalidOperationException>(()=>Call(rollout,"profile-delete",new Dictionary<string,object>{{"id",id}}));
            rollout.Tick(first.AddHours(7));Assert(!Rows(Call(rollout,"status"),"jobs").Any(j=>Data.Text(j,"state")=="queued"));
            var queued=Call(rollout,"discover",plan);var job=(Dictionary<string,object>)queued["job"];
            Call(rollout,"cancel",new Dictionary<string,object>{{"id",job["id"]}});Assert(!rollout.ProcessNext(CancellationToken.None));
            var bulk=new Dictionary<string,object>(plan);bulk["ranges"]=string.Join(",",Enumerable.Range(0,600).Select(n=>"BULK-"+n));
            Call(rollout,"discover",bulk);Assert(rollout.ProcessNext(CancellationToken.None));
            var bulkIds=Rows(Call(rollout,"status"),"devices").Where(d=>Data.Text(d,"target").StartsWith("BULK-")).Select(d=>Data.Text(d,"id")).ToArray();Assert(bulkIds.Length==600);
            var bulkPush=new Dictionary<string,object>(push);bulkPush["deviceIds"]=bulkIds;
            Call(rollout,"push",bulkPush);Assert(rollout.ProcessNext(CancellationToken.None) && fake.pushed==602);
            queued=Call(rollout,"discover",plan);job=(Dictionary<string,object>)queued["job"];
            string interruptedPath=Path.Combine(root,"rollout","jobs",Data.Text(job,"id")+".json");
            var interrupted=Data.Read(interruptedPath);interrupted["state"]="running";Data.Save(interruptedPath,interrupted);
            using(var stopped=new CancellationTokenSource()) {stopped.Cancel();rollout.Run(stopped.Token);}
            Assert(Data.Text(Data.Read(interruptedPath),"state")=="interrupted" && !rollout.ProcessNext(CancellationToken.None));
            Assert(WindowsAgentPush.Failure(new UnauthorizedAccessException()).Contains("authentication/access denied"));
            Assert(WindowsAgentPush.Failure(new System.Runtime.InteropServices.COMException("secret",unchecked((int)0x800706ba))).Contains("WMI/RPC unavailable (0x800706BA)"));
            Assert(WindowsAgentPush.Failure(new System.ComponentModel.Win32Exception(1722)).Contains("WMI/RPC unavailable (Win32 1722)"));
            Assert(WindowsAgentPush.Failure(new System.Runtime.InteropServices.COMException("secret",unchecked((int)0x80041003))).Contains("authentication/access denied (0x80041003)"));
            Assert(WindowsAgentPush.Failure(new System.Runtime.InteropServices.COMException("secret",unchecked((int)0x8004100e))).Contains("WMI query/provider failed (0x8004100E)"));
            Assert(WindowsAgentPush.Failure(new System.Runtime.InteropServices.COMException("secret",unchecked((int)0x80070721))).Contains("0x80070721"));
            bulk["ranges"]=string.Join(",",Enumerable.Range(0,40).Select(n=>"RPC-"+n));
            queued=Call(rollout,"discover",bulk);Assert(rollout.ProcessNext(CancellationToken.None));
            string failedId=Data.Text((Dictionary<string,object>)queued["job"],"id");
            status=Call(rollout,"status");var failedJob=Rows(status,"jobs").Single(j=>Data.Text(j,"id")==failedId);
            failures=Rows(failedJob,"failures");Assert(failures.Length==1 && Data.Text(failures[0],"count")=="40");
            Assert(((IEnumerable)failures[0]["targets"]).Cast<string>().Count()==3);
            Assert(!Data.Json(status).Contains("synthetic-secret"));
            rollout=new AgentRollout(root,settings,fake,"unused");
            Assert(Rows(Rows(Call(rollout,"status"),"jobs").Single(j=>Data.Text(j,"id")==failedId),"failures").Length==1);
            Console.WriteLine("PASS Agent rollout: encrypted credentials, Windows-only inventory, 600 targets, identity changes, push selection, independent persisted schedules, missed-run coalescing, no overlap and cancellation.");
        } finally { // Delete only this test's explicitly verified temporary workspace.
            string full=Path.GetFullPath(root),temp=Path.GetFullPath(Path.GetTempPath());
            if(full.StartsWith(temp,StringComparison.OrdinalIgnoreCase) && Path.GetFileName(full).StartsWith("SubnetDesk-RolloutTest-"))Directory.Delete(full,true);
        }
    }
}
