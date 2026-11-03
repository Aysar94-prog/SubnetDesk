using System;
using System.Collections.Generic;
using System.IO;
using SubnetDesk.Deployment;

internal static class SilentAgentSetupTests {
    static void Assert(bool value,[System.Runtime.CompilerServices.CallerLineNumber]int line=0) {if(!value) throw new Exception("Silent setup regression at line "+line);}
    internal static void Run() {
        string pin=new string('A',64);
        foreach(string server in new[]{"PC-Aysar","192.168.50.189"}) {
            var result=SilentAgentSetup.Configuration(new[]{"--install","--silent","--server",server,"--certificate-sha256",pin},null,null);
            Assert(string.Equals(Data.Text(result,"server"),"https://"+server+"/subnetdesk/",StringComparison.OrdinalIgnoreCase));
            Assert(Data.Text(result,"approvalRequired")=="true");
        }
        var embedded=new Dictionary<string,object>{{"server","https://pc-aysar/subnetdesk/"},{"certificateSha256",pin}};
        var saved=new Dictionary<string,object>(embedded){{"deviceId",Guid.NewGuid().ToString("D")},{"deviceToken","synthetic-existing-token"}};
        var config=SilentAgentSetup.Configuration(new[]{"--install","--silent","--server","PC-Aysar"},embedded,saved);
        Assert(Data.Text(config,"deviceId")==Data.Text(saved,"deviceId") && Data.Text(config,"deviceToken")=="synthetic-existing-token");
        config=SilentAgentSetup.Configuration(new[]{"--install","--silent","--server","PC-Aysar"},embedded,null);
        Assert(Data.Text(config,"certificateSha256")==pin && Data.Text(config,"approvalRequired")=="true");
        foreach(var args in new[]{
            new[]{"--install","--silent","--server","192.168.50.189"},
            new[]{"--install","--silent","--server","http://pc-aysar","--certificate-sha256",pin},
            new[]{"--install","--silent","--server","PC-Aysar","--server","other"},
            new[]{"--install","--silent","--server"},
            new[]{"--install","--silent","--server","other","--certificate-sha256",pin},
            new[]{"--install","--silent","--server","https://user:secret@pc-aysar/subnetdesk/","--certificate-sha256",pin}
        }) {
            bool denied=false; try{SilentAgentSetup.Configuration(args,embedded,saved);}catch(InvalidDataException){denied=true;} Assert(denied);
        }
        config=SilentAgentSetup.Configuration(new[]{"--install","--silent","--server","other","--certificate-sha256",pin,"--replace-registration"},embedded,saved);
        Assert(!config.ContainsKey("deviceId") && !config.ContainsKey("deviceToken") && Data.Text(config,"approvalRequired")=="true");
        var ipv6=new Uri(SilentAgentSetup.Server("2001:db8::1"));
        Assert(System.Net.IPAddress.Parse(ipv6.Host.Trim('[',']')).Equals(System.Net.IPAddress.Parse("2001:db8::1")) && ipv6.AbsolutePath=="/subnetdesk/");
        Console.WriteLine("PASS silent Agent: management IP/hostname parameters, trusted identity, existing registration preservation, explicit migration and rejected malformed options.");
    }
}
