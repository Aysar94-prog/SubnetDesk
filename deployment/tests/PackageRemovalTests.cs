using System;
using System.Collections.Generic;
using System.IO;
using SubnetDesk.Deployment;

internal static class PackageRemovalTests {
    static void Assert(bool value) { if(!value) throw new Exception("Package removal regression"); }
    internal static void Run() {
        string root=Path.Combine(Path.GetTempPath(),"SubnetDesk-package-removal-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root,"packages")); Directory.CreateDirectory(Path.Combine(root,"devices"));
        string sha=new string('A',64), file=Path.Combine(root,"packages",sha+".msi"), metadata=Path.Combine(root,"packages",sha+".json");
        string device=Path.Combine(root,"devices",Guid.NewGuid().ToString("D")+".json");
        try {
            File.WriteAllText(file,"synthetic MSI"); Data.Save(metadata,new {sha256=sha,version="1.0"});
            var server=new ManagementServer(root); int code=0;
            var body=new Dictionary<string,object>{{"sha256",sha}};
            foreach(string state in new[]{"queued","running"}) {
                Data.Save(device,new {job=new {action="install",sha256=sha,state=state}});
                server.AdminRoute("admin/packages/remove","POST",body,(reply,status)=>code=status);
                Assert(code==409 && File.Exists(file) && File.Exists(metadata));
            }
            Data.Save(device,new {job=(object)null,helperVersion="1.0"});
            server.AdminRoute("admin/packages/remove","POST",body,(reply,status)=>code=status);
            Assert(code==200 && !File.Exists(file) && !File.Exists(metadata) && File.Exists(device));
            server=new ManagementServer(root);
            server.AdminRoute("admin/packages/remove","POST",body,(reply,status)=>code=status); Assert(code==404);
            bool rejected=false;
            try {server.AdminRoute("admin/packages/remove","POST",new Dictionary<string,object>{{"sha256","../device"}},(r,s)=>{});} catch(InvalidDataException){rejected=true;}
            Assert(rejected);
        } finally {Directory.Delete(root,true);}
        Console.WriteLine("PASS package deletion: queued/running protection, durable removal, device preservation and path validation.");
    }
}
