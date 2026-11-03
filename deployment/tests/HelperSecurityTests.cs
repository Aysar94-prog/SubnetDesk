using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using SubnetDesk.Deployment;

internal static class HelperSecurityTests {
    static void Assert(bool value,string message) {if(!value) throw new Exception("Helper security: "+message);}
    static Dictionary<string,object> Settings(string operation,string current="",string password="") {return new Dictionary<string,object>{{"operation",operation},{"currentPassword",current},{"newPassword",password}};}
    internal static void Run() {
        const string unattended="synthetic-unattended-\"-العربية";
        var settings=Settings("unattended-password",password:unattended);
        string encrypted=HelperSettings.Protect(settings); Assert(!encrypted.Contains(unattended),"DPAPI queue does not contain plaintext");
        Assert(Data.Text(HelperSettings.Unprotect(encrypted),"newPassword")==unattended,"protected queue round trip");
        var job=new Dictionary<string,object>{{"id",Guid.NewGuid().ToString("D")},{"protectedSettings",encrypted}};
        Assert(!Data.Json(HelperSettings.PublicJob(job)).Contains("protectedSettings"),"public job redaction");
        Assert(HelperSettings.AgentJob(job).ContainsKey("settings") && !HelperSettings.AgentJob(job).ContainsKey("protectedSettings"),"assigned Agent alone receives decoded settings");
        string properties=HelperSettings.InstallProperties(settings), encoded=properties.Substring(properties.IndexOf("UNATTENDED_PASSWORD_B64=")+"UNATTENDED_PASSWORD_B64=".Length);
        Assert(!properties.Contains(unattended) && Encoding.UTF8.GetString(Convert.FromBase64String(encoded))==unattended,"MSI Unicode/quote password transfer");
        foreach(string invalid in new[]{"", "bad\npassword", new string('x',181)}) {
            bool denied=false; try{HelperSettings.Validate(Settings("unattended-password",password:invalid));}catch(InvalidDataException){denied=true;} Assert(denied,"invalid password rejected");
        }
        bool unsupported=false;
        try {HelperSettings.Validate(Settings("arbitrary-policy",current:"synthetic-current"));} catch(InvalidDataException){unsupported=true;}
        Assert(unsupported,"arbitrary policy actions are rejected");
        Console.WriteLine("PASS Helper security: DPAPI/redaction, exact MSI password encoding and input validation.");
    }    internal static void Network(int port,string root,string id,string token,string admin) {
        const string current="synthetic-network-old-password", password="synthetic-network-new-password";
        string devicePath=Path.Combine(root,"devices",id+".json");
        var saved=Data.Read(devicePath); object active; saved.TryGetValue("job",out active);
        if(active is Dictionary<string,object>) AgentUpdateTests.JsonCall(port,"result",token,id,new {jobId=Data.Text((Dictionary<string,object>)active,"id"),ok=false,message="Test cleanup"});
        AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.4.0.0"});
        var body=new {action="configure-helper",deviceIds=new[]{id},settings=Settings("unattended-password",password:password)};
        var reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,body); var rows=(System.Collections.IList)reply["results"];
        Assert(!(bool)((Dictionary<string,object>)rows[0])["queued"],"old Agent cannot silently skip settings");
        AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.5.0.0",helperSettingsProtocol="1"});
        reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,body); rows=(System.Collections.IList)reply["results"];
        Assert((bool)((Dictionary<string,object>)rows[0])["queued"],"capable Agent receives settings job");
        string disk=File.ReadAllText(devicePath); Assert(!disk.Contains(current) && !disk.Contains(password) && disk.Contains("protectedSettings"),"disk queue protects credentials");
        string publicData=Data.Json(AgentUpdateTests.JsonCall(port,"admin/devices",admin,id,null));
        Assert(!publicData.Contains(current) && !publicData.Contains(password) && !publicData.Contains("protectedSettings"),"inventory API exposes no password payload");
        reply=AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.5.0.0",helperSettingsProtocol="1"});
        var job=(Dictionary<string,object>)reply["job"]; string jobId=Data.Text(job,"id");
        var delivered=(Dictionary<string,object>)job["settings"];
        Assert(Data.Text(delivered,"currentPassword")=="" && Data.Text(delivered,"newPassword")==password,"assigned poll delivers exact settings");
        Assert(!File.ReadAllText(devicePath).Contains(password),"poll does not persist decrypted password");
        AgentUpdateTests.JsonCall(port,"result",token,id,new {jobId=jobId,ok=true,message="Synthetic settings result"});
        reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,body);
        AgentUpdateTests.JsonCall(port,"admin/cancel",admin,id,new {deviceId=id});
        AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,body);
        saved=Data.Read(devicePath); ((Dictionary<string,object>)saved["job"])["settingsExpiresUtc"]=DateTime.UtcNow.AddMinutes(-1).ToString("o"); Data.Save(devicePath,saved);
        AgentUpdateTests.JsonCall(port,"admin/devices",admin,id,null);
        Assert(Data.Read(devicePath)["job"]==null && Data.Text(Data.Read(devicePath),"status")=="Expired","sensitive queued task expires and removes credential payload");
        string history=Data.Json(AgentUpdateTests.JsonCall(port,"admin/history",admin,id,null));
        Assert(!history.Contains(current) && !history.Contains(password) && !history.Contains("protectedSettings") && !history.Contains("newPassword"),"result/cancel/expiry history contains no credentials");
        string msi=Environment.GetEnvironmentVariable("SUBNETDESK_TEST_HELPER_MSI");
        if(!string.IsNullOrEmpty(msi)) {
            Assert(Msi.SupportsUnattended(msi),"Helper MSI contains unattended password custom actions");
            var metadata=Msi.Inspect(msi); string sha=Data.Text(metadata,"sha256"); Directory.CreateDirectory(Path.Combine(root,"packages"));
            File.Copy(msi,Path.Combine(root,"packages",sha+".msi")); Data.Save(Path.Combine(root,"packages",sha+".json"),metadata);
            reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,new {action="install",sha256=sha,deviceIds=new[]{id},settings=Settings("unattended-password",password:password)});
            rows=(System.Collections.IList)reply["results"]; Assert((bool)((Dictionary<string,object>)rows[0])["queued"],"MSI install and unattended settings queue together");
            AgentUpdateTests.JsonCall(port,"admin/cancel",admin,id,new {deviceId=id});
        }
        var receiverBody=new {action="configure-helper",deviceIds=new[]{id},settings=Settings("receiver-lock",password:password)};
        AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.6.0.0",helperSettingsProtocol="2",helper=new {version="1.4.4.104",service="Running"}});
        reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,receiverBody);rows=(System.Collections.IList)reply["results"];
        Assert(!(bool)((Dictionary<string,object>)rows[0])["queued"],"old Helper cannot receive device policy task");
        AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.6.0.0",helperSettingsProtocol="2",helper=new {version="1.4.5.115",service="Running",receiverPolicyProtocol="1",receiverScope="profile"}});
        reply=AgentUpdateTests.JsonCall(port,"admin/jobs",admin,id,receiverBody);rows=(System.Collections.IList)reply["results"];
        Assert((bool)((Dictionary<string,object>)rows[0])["queued"],"new Helper and Agent advertise device policy capability");
        reply=AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.6.0.0",helperSettingsProtocol="2"});job=(Dictionary<string,object>)reply["job"];
        Assert(Data.Text((Dictionary<string,object>)job["settings"],"operation")=="receiver-lock","receiver action delivered separately from unattended password");
        AgentUpdateTests.JsonCall(port,"result",token,id,new {jobId=Data.Text(job,"id"),ok=true,message="Synthetic all-account policy result"});
        AgentUpdateTests.JsonCall(port,"poll",token,id,new {agentVersion="1.6.0.0",helperSettingsProtocol="2",helper=new {version="1.4.5.115",service="Running",receiverPolicyProtocol="1",receiverScope="device",receiverOnly=true}});
        saved=Data.Read(devicePath);Assert(Data.Text(saved,"receiverScope")=="device" && Data.Text(saved,"receiverOnly")=="True","policy scope and mode are reported without verifier");
        Console.WriteLine("PASS HTTP Helper settings: capability gate, protected queue, inventory redaction, assigned delivery, result/cancel/expiry secret removal and MSI install settings contract.");
    }
}
