using System;
using System.IO;
using System.Text;

namespace SubnetDesk.Deployment {
    internal static class SelfTest {
        internal static void Run() {
            if (ComputerFacts.FormatOperatingSystem("Microsoft Windows 10 Pro", "22H2", "19045", "6000") != "Microsoft Windows 10 Pro 22H2 (Build 19045.6000)") throw new Exception("Windows display formatting failed.");
            if (ComputerFacts.FormatOperatingSystem("Microsoft Windows 11 Enterprise", "24H2", "26100", "") != "Microsoft Windows 11 Enterprise 24H2 (Build 26100)") throw new Exception("Windows 11 display formatting failed.");
            if (ComputerFacts.FormatOperatingSystem("Microsoft Windows Server 2022 Standard", "", "20348", "") != "Microsoft Windows Server 2022 Standard (Build 20348)") throw new Exception("Server display formatting failed.");
            if (ComputerFacts.FormatOperatingSystem("", "", "", "").Contains("Windows NT")) throw new Exception("Unknown edition must not report Windows NT as the product name.");
            if (Data.Equal("abc", "abd") || Data.Equal("abc", "abcd") || !Data.Equal("abc", "abc")) throw new Exception("Constant time comparison failed.");
            if (Data.Hash(Encoding.UTF8.GetBytes("abc")) != "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD") throw new Exception("SHA256 failed.");
            foreach (string invalid in new[] { "http://host/subnetdesk/", "https://user:pass@host/subnetdesk/", "https://host/subnetdesk/?x=1", "https://host/" }) {
                bool rejected = false; try { Data.Endpoint(invalid); } catch (InvalidDataException) { rejected = true; } if (!rejected) throw new Exception("Unsafe endpoint accepted.");
            }
            Data.Endpoint("https://server.local/subnetdesk/");
            if (!Msi.IsHelperName("SubnetDesk Helper") || Msi.IsHelperName("RustDesk") || Msi.IsHelperName("SubnetDesk Deploy") || Msi.IsHelperName("SubnetDesk Agent")) throw new Exception("Helper product identity validation failed.");
            foreach (string action in new[] { "install", "repair", "uninstall", "start", "stop", "restart" }) if (!HelperActions.Allowed(action)) throw new Exception("Missing managed action.");
            foreach (string action in new[] { "cmd.exe", "powershell", "delete", "", "uninstall arbitrary-product" }) if (HelperActions.Allowed(action)) throw new Exception("Unsafe action accepted.");
            bool badId = false; try { Data.Id("../../config"); } catch (InvalidDataException) { badId = true; } if (!badId) throw new Exception("Path traversal accepted.");
            string folder = Path.Combine(Path.GetTempPath(), "SubnetDesk-Agent-Test-" + Guid.NewGuid().ToString("N"));
            try {
                string path = Path.Combine(folder, "state.json"); Data.Save(path, new { version = "1" }); Data.Save(path, new { version = "2" }); if (Data.Text(Data.Read(path), "version") != "2") throw new Exception("Atomic state write failed.");
                string setup = Path.Combine(folder,"setup.bin"), runtime = Path.Combine(folder,"runtime.bin");
                byte[] payload = Encoding.UTF8.GetBytes(Data.Json(new { server="https://test.example/subnetdesk/",certificateSha256=new string('F',64),enrollmentToken=Convert.ToBase64String(new byte[32]) }));
                using (var writer = new BinaryWriter(File.Create(setup))) { writer.Write(new byte[]{1,2,3,4,5}); writer.Write(payload); writer.Write(payload.Length); writer.Write(Encoding.UTF8.GetBytes("SUBNETDESK_ENROLLMENT_V1")); }
                if (Data.Text(EmbeddedRegistration.Read(setup),"server")!="https://test.example/subnetdesk/") throw new Exception("Embedded enrollment read failed.");
                EmbeddedRegistration.CopyRuntime(setup,runtime);
                if (new FileInfo(runtime).Length!=5 || EmbeddedRegistration.Read(runtime)!=null) throw new Exception("Runtime retained embedded enrollment credentials.");
                payload = Encoding.UTF8.GetBytes(Data.Json(new { server="https://test.example/subnetdesk/",certificateSha256=new string('F',64),approvalRequired="true" }));
                using (var writer = new BinaryWriter(File.Create(setup))) { writer.Write(new byte[]{1,2,3,4,5}); writer.Write(payload); writer.Write(payload.Length); writer.Write(Encoding.UTF8.GetBytes("SUBNETDESK_ENROLLMENT_V1")); }
                var reusable = EmbeddedRegistration.Read(setup);
                if (Data.Text(reusable,"approvalRequired")!="true" || reusable.ContainsKey("enrollmentToken")) throw new Exception("Reusable setup must not require enrollment secrets.");
                EmbeddedRegistration.CopyRuntime(setup,runtime);
                if (new FileInfo(runtime).Length!=5) throw new Exception("Reusable setup footer stripping failed.");
            }
            finally { if (Directory.Exists(folder)) Directory.Delete(folder, true); }
            Console.WriteLine("PASS: comparison, SHA256, endpoint restrictions, device IDs, atomic persistence, embedded enrollment and secret stripping.");
        }
    }
}
