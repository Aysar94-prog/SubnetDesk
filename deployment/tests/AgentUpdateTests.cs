using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using SubnetDesk.Deployment;

internal static class AgentUpdateTests {
    static void Assert(bool value,string message) { if (!value) throw new Exception("Agent update: "+message); }
    internal static void Run() {
        string root=Path.Combine(Path.GetTempPath(),"SubnetDesk-Update-Test-"+Guid.NewGuid().ToString("N")); Directory.CreateDirectory(root);
        try {
            string current=Path.Combine(root,"runtime.exe"), candidate=Path.Combine(root,"candidate.exe"), backup=Path.Combine(root,"previous.exe"), failed=Path.Combine(root,"failed.exe"), config=Path.Combine(root,"config.json");
            File.WriteAllText(current,"previous runtime"); File.WriteAllText(candidate,"new runtime"); File.WriteAllText(config,"unchanged identity");
            AgentUpdate.ReplaceRuntime(candidate,current,backup);
            Assert(File.ReadAllText(current)=="new runtime" && File.ReadAllText(backup)=="previous runtime","atomic replacement retains backup");
            AgentUpdate.ReplaceRuntime(backup,current,failed);
            Assert(File.ReadAllText(current)=="previous runtime" && File.ReadAllText(failed)=="new runtime" && File.ReadAllText(config)=="unchanged identity","rollback restores runtime without changing config");
            string package=Environment.GetEnvironmentVariable("SUBNETDESK_TEST_AGENT_PACKAGE");
            if (!string.IsNullOrEmpty(package)) {
                var metadata=AgentPackage.Inspect(package); AgentPackage.Verify(package,metadata);
                metadata["sha256"]=new string('0',64); bool rejected=false;
                try { AgentPackage.Verify(package,metadata); } catch(InvalidDataException) { rejected=true; }
                Assert(rejected,"modified hash rejected");
            }
            Console.WriteLine("PASS Agent update: atomic runtime replacement, backup restoration, config preservation and package hash verification.");
        } finally { Directory.Delete(root,true); }
    }
    static byte[] Call(int port,string route,string method,string token,string id,byte[] body) {
        var request=(HttpWebRequest)WebRequest.Create("http://localhost:"+port+"/subnetdesk/"+route); request.Method=method; request.Timeout=5000; request.Proxy=null;
        request.Headers["Authorization"]="Bearer "+token; request.Headers["X-Device-Id"]=id;
        if(body!=null) { request.ContentLength=body.Length; using(var stream=request.GetRequestStream()) stream.Write(body,0,body.Length); }
        using(var response=request.GetResponse()) using(var stream=response.GetResponseStream()) using(var memory=new MemoryStream()) { stream.CopyTo(memory); return memory.ToArray(); }
    }
    internal static Dictionary<string,object> JsonCall(int port,string route,string token,string id,object body) { return Data.Parse(Encoding.UTF8.GetString(Call(port,route,body==null ? "GET" : "POST",token,id,body==null ? null : Encoding.UTF8.GetBytes(Data.Json(body))))); }
    internal static void Network(int port,string root,string id,string token,string admin,string previousJob) {
        string package=Environment.GetEnvironmentVariable("SUBNETDESK_TEST_AGENT_PACKAGE");
        if(string.IsNullOrEmpty(package)) { Console.WriteLine("SKIP Agent upload HTTP test: SUBNETDESK_TEST_AGENT_PACKAGE not configured."); return; }
        JsonCall(port,"result",token,id,new {jobId=previousJob,ok=true,message="Previous fixed task complete"});
        JsonCall(port,"poll",token,id,new {machine="AFTER-SECOND-RENAME",agentVersion="1.3.1.0",helper=new {version="1.4.4.104",service="Running"}});
        var uploaded=Data.Parse(Encoding.UTF8.GetString(Call(port,"admin/agent-package","POST",admin,id,File.ReadAllBytes(package)))); string sha=Data.Text(uploaded,"sha256");
        var reply=JsonCall(port,"admin/jobs",admin,id,new {action="agent-update",sha256=sha,deviceIds=new[]{id}});
        var rows=(System.Collections.IList)reply["results"];
        Assert(!(bool)((Dictionary<string,object>)rows[0])["queued"],"old Agent cannot receive unsupported update command");
        JsonCall(port,"poll",token,id,new {agentVersion="1.4.0.0",agentUpdateProtocol="1"});
        reply=JsonCall(port,"admin/jobs",admin,id,new {action="agent-update",sha256=sha,deviceIds=new[]{id}});
        rows=(System.Collections.IList)reply["results"]; Assert((bool)((Dictionary<string,object>)rows[0])["queued"],"capable Agent update queued");
        reply=JsonCall(port,"poll",token,id,new {agentVersion="1.4.0.0",agentUpdateProtocol="1"}); var job=(Dictionary<string,object>)reply["job"]; string jobId=Data.Text(job,"id");
        byte[] bytes=Call(port,"agent-packages/"+sha,"GET",token,id,null); Assert(Data.Hash(bytes)==sha,"authorized download matches uploaded package");
        bool denied=false;
        try { Call(port,"agent-packages/"+sha,"GET",Data.Secret(),id,null); } catch(WebException e) { denied=((HttpWebResponse)e.Response).StatusCode==HttpStatusCode.Unauthorized; e.Response.Close(); }
        Assert(denied,"wrong device credential cannot download Agent package");
        JsonCall(port,"agent-update-status",token,id,new {jobId=jobId,stage="Restarting Agent service"});
        denied=false;
        try { JsonCall(port,"result",token,id,new {jobId=jobId,ok=true,agentVersion="1.4.0.0"}); } catch(WebException e) { denied=((HttpWebResponse)e.Response).StatusCode==HttpStatusCode.BadRequest; e.Response.Close(); }
        Assert(denied,"incorrect running version cannot complete update successfully");
        JsonCall(port,"result",token,id,new {jobId=jobId,ok=true,agentVersion=Data.Text(uploaded,"version"),message="Updated service verified"});
        var saved=Data.Read(Path.Combine(root,"devices",id+".json"));
        Assert(Data.Text(saved,"agentVersion")==Data.Text(uploaded,"version") && Data.Text(saved,"helperVersion")=="1.4.4.104" && saved["job"]==null,"Agent result updates Agent version without changing Helper");
        reply=JsonCall(port,"admin/jobs",admin,id,new {action="agent-update",sha256=sha,deviceIds=new[]{id}}); rows=(System.Collections.IList)reply["results"];
        Assert(!(bool)((Dictionary<string,object>)rows[0])["queued"],"same-version update skipped");
        Console.WriteLine("PASS HTTP Agent update: upload, compatibility gate, queue, assigned download, access control, progress, running-version confirmation, result history and same-version skip.");
    }
}
