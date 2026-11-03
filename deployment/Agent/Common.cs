using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Web.Script.Serialization;

namespace SubnetDesk.Deployment {
    internal static class Data {
        internal static readonly string Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SubnetDesk Deployment");
        internal static void SecureRoot() {
            var security = new DirectorySecurity(); security.SetAccessRuleProtection(true, false);
            foreach (string sid in new[] { "S-1-5-18", "S-1-5-32-544" }) security.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(sid), FileSystemRights.FullControl, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
            if (!Directory.Exists(Root)) Directory.CreateDirectory(Root, security);
            // Refuse pre-existing writable configuration rather than consuming it
            // with service privileges. Elevated setup repairs folder permissions.
            CheckRules(Directory.GetAccessControl(Root).GetAccessRules(true, true, typeof(SecurityIdentifier)));
            foreach (string directory in Directory.GetDirectories(Root, "*", SearchOption.AllDirectories)) {
                if ((File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) throw new UnauthorizedAccessException("Configuration links are not allowed.");
                CheckRules(Directory.GetAccessControl(directory).GetAccessRules(true, true, typeof(SecurityIdentifier)));
            }
            foreach (string file in Directory.GetFiles(Root, "*", SearchOption.AllDirectories)) {
                if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) throw new UnauthorizedAccessException("Configuration links are not allowed.");
                CheckRules(File.GetAccessControl(file).GetAccessRules(true, true, typeof(SecurityIdentifier)));
            }
        }
        static void CheckRules(AuthorizationRuleCollection rules) {
            foreach (FileSystemAccessRule rule in rules) {
                string sid = rule.IdentityReference.Value;
                if (rule.AccessControlType == AccessControlType.Allow && sid != "S-1-5-18" && sid != "S-1-5-32-544" && (rule.FileSystemRights & (FileSystemRights.Write | FileSystemRights.Delete | FileSystemRights.ChangePermissions)) != 0) throw new UnauthorizedAccessException("Run elevated deployment setup to secure configuration.");
            }
        }
        internal static Dictionary<string, object> Parse(string json) { return new JavaScriptSerializer { MaxJsonLength = 1048576 }.Deserialize<Dictionary<string, object>>(json); }
        internal static string Json(object value) { return new JavaScriptSerializer { MaxJsonLength = 1048576 }.Serialize(value); }
        internal static string Text(Dictionary<string, object> data, string key) { object value; return data.TryGetValue(key, out value) && value != null ? Convert.ToString(value) : ""; }
        internal static Dictionary<string, object> Read(string path) { return Parse(File.ReadAllText(path, Encoding.UTF8)); }
        internal static void Save(string path, object value) {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temporary = path + ".new";
            File.WriteAllText(temporary, Json(value), new UTF8Encoding(false));
            if (File.Exists(path)) File.Replace(temporary, path, null); else File.Move(temporary, path);
        }
        internal static string Secret() { var bytes = new byte[32]; using (var random = RandomNumberGenerator.Create()) random.GetBytes(bytes); return Convert.ToBase64String(bytes); }
        internal static string Hash(byte[] bytes) { using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", ""); }
        internal static string FileHash(string path) { using (var stream = File.OpenRead(path)) using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", ""); }
        internal static bool Equal(string left, string right) {
            byte[] a = Encoding.UTF8.GetBytes(left), b = Encoding.UTF8.GetBytes(right);
            int diff = a.Length ^ b.Length;
            for (int i = 0; i < Math.Min(a.Length, b.Length); i++) diff |= a[i] ^ b[i];
            return diff == 0;
        }
        internal static string Id(string value) { Guid parsed; if (!Guid.TryParseExact(value, "D", out parsed)) throw new InvalidDataException("Invalid device/job ID."); return parsed.ToString("D"); }
        internal static Uri Endpoint(string value) {
            Uri uri;
            if (!Uri.TryCreate(value, UriKind.Absolute, out uri) || uri.Scheme != "https" || uri.AbsolutePath != "/subnetdesk/" || uri.UserInfo != "" || uri.Query != "" || uri.Fragment != "") throw new InvalidDataException("Use https://server/subnetdesk/.");
            return uri;
        }
        internal static HttpWebRequest Request(Dictionary<string, object> config, string route, string method, string token) {
            Uri server = Endpoint(Text(config, "server"));
            string pin = Text(config, "certificateSha256");
            if (!System.Text.RegularExpressions.Regex.IsMatch(pin, "^[A-Fa-f0-9]{64}$")) throw new InvalidDataException("Invalid server certificate pin.");
            var request = (HttpWebRequest)WebRequest.Create(new Uri(server, route));
            request.Method = method; request.AllowAutoRedirect = false; request.Timeout = 30000; request.ReadWriteTimeout = 120000; request.Proxy = null;
            request.ServerCertificateValidationCallback = (sender, certificate, chain, errors) => {
                if (certificate == null || (errors & (SslPolicyErrors.RemoteCertificateNameMismatch | SslPolicyErrors.RemoteCertificateNotAvailable)) != 0) return false;
                var cert = new X509Certificate2(certificate);
                return DateTime.Now >= cert.NotBefore && DateTime.Now <= cert.NotAfter && Equal(Hash(cert.RawData), pin.ToUpperInvariant());
            };
            if (token != "") request.Headers["Authorization"] = "Bearer " + token;
            return request;
        }
        internal static Dictionary<string, object> Call(Dictionary<string, object> config, string route, string token, object body, string device = "") {
            var request = Request(config, route, body == null ? "GET" : "POST", token);
            if (device != "") request.Headers["X-Device-Id"] = device;
            if (body != null) { byte[] bytes = Encoding.UTF8.GetBytes(Json(body)); request.ContentType = "application/json"; request.ContentLength = bytes.Length; using (var stream = request.GetRequestStream()) stream.Write(bytes, 0, bytes.Length); }
            using (var response = request.GetResponse()) using (var reader = new StreamReader(response.GetResponseStream())) return Parse(reader.ReadToEnd());
        }
        internal static void Log(string role, string message) {
            string path = Path.Combine(Root, role + ".log");
            try { Directory.CreateDirectory(Root); if (File.Exists(path) && new FileInfo(path).Length > 1048576) File.Delete(path); File.AppendAllText(path, DateTime.UtcNow.ToString("o") + " " + message + Environment.NewLine); }
            catch (IOException) { System.Diagnostics.Trace.WriteLine("Deployment log unavailable."); }
            catch (UnauthorizedAccessException) { System.Diagnostics.Trace.WriteLine("Deployment log access denied."); }
        }
    }
    internal static class Msi {
        internal const string HelperUpgradeCode = "{DC0E791C-3B4D-5A51-9AA8-629D81975868}";
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] static extern uint MsiEnumRelatedProducts(string upgradeCode, uint reserved, uint index, StringBuilder product);
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] internal static extern uint MsiConfigureProductEx(string product, int level, int state, string properties);
        internal static void RemoveLegacyAgent() {
            var products = new List<string>();
            for (uint index = 0; ; index++) {
                var product = new StringBuilder(39);
                if (MsiEnumRelatedProducts("{7A1073B8-8D46-49D3-BFDC-3C222D62A3F6}", 0, index, product) != 0) break;
                products.Add(product.ToString());
            }
            MsiSetInternalUI(2, IntPtr.Zero);
            foreach (string product in products) {
                uint code = MsiConfigureProductEx(product, 0, 2, "REBOOT=ReallySuppress");
                if (code != 0 && code != 3010) throw new InvalidOperationException("Legacy Agent migration failed (MSI " + code + ").");
            }
        }
        internal static Dictionary<string, object> Inventory() {
            string product = "", version = "", service = "Not installed";
            for (uint index = 0; ; index++) {
                var code = new StringBuilder(39); if (MsiEnumRelatedProducts(HelperUpgradeCode, 0, index, code) != 0) break;
                var name = new StringBuilder(1024); uint nameLength = 1023;
                if (MsiGetProductInfo(code.ToString(), "ProductName", name, ref nameLength) != 0 || !IsHelperName(name.ToString())) continue;
                var value = new StringBuilder(1024); uint length = 1023;
                if (MsiGetProductInfo(code.ToString(), "VersionString", value, ref length) == 0) { product = code.ToString(); version = value.ToString(); break; }
            }
            try { using (var controller = new System.ServiceProcess.ServiceController("SubnetDesk")) service = controller.Status.ToString(); }
            catch (InvalidOperationException) { service = "Not installed"; }
            var inventory=new Dictionary<string, object> { { "productCode", product }, { "version", version }, { "service", service } };
            MachineReceiverPolicy.AddInventory(inventory); return inventory;
        }
        internal static bool IsHelperName(string name) { return name.IndexOf("SubnetDesk", StringComparison.OrdinalIgnoreCase) >= 0 && name.IndexOf("Deploy", StringComparison.OrdinalIgnoreCase) < 0 && name.IndexOf("Agent", StringComparison.OrdinalIgnoreCase) < 0; }
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] static extern uint MsiOpenDatabase(string path, IntPtr mode, out IntPtr db);
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] static extern uint MsiDatabaseOpenView(IntPtr db, string query, out IntPtr view);
        [DllImport("msi.dll")] static extern uint MsiViewExecute(IntPtr view, IntPtr record);
        [DllImport("msi.dll")] static extern uint MsiViewFetch(IntPtr view, out IntPtr record);
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] static extern uint MsiRecordGetString(IntPtr record, uint field, StringBuilder value, ref uint size);
        [DllImport("msi.dll")] static extern uint MsiCloseHandle(IntPtr handle);
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] internal static extern uint MsiGetProductInfo(string product, string property, StringBuilder value, ref uint size);
        [DllImport("msi.dll", CharSet = CharSet.Unicode)] internal static extern uint MsiInstallProduct(string path, string properties);
        [DllImport("msi.dll")] internal static extern uint MsiSetInternalUI(uint level, IntPtr window);
        internal static string Property(IntPtr db, string name) {
            IntPtr view = IntPtr.Zero, record = IntPtr.Zero;
            try {
                if (MsiDatabaseOpenView(db, "SELECT `Value` FROM `Property` WHERE `Property`='" + name + "'", out view) != 0 || MsiViewExecute(view, IntPtr.Zero) != 0 || MsiViewFetch(view, out record) != 0) throw new InvalidDataException("Missing MSI property.");
                var text = new StringBuilder(4096); uint size = 4095;
                if (MsiRecordGetString(record, 1, text, ref size) != 0) throw new InvalidDataException("Invalid MSI property.");
                return text.ToString();
            } finally { if (record != IntPtr.Zero) MsiCloseHandle(record); if (view != IntPtr.Zero) MsiCloseHandle(view); }
        }
        internal static Dictionary<string, object> Inspect(string path) {
            IntPtr db; if (MsiOpenDatabase(path, IntPtr.Zero, out db) != 0) throw new InvalidDataException("Cannot read Helper MSI.");
            try {
                string name = Property(db, "ProductName");
                if (!IsHelperName(name)) throw new InvalidDataException("Only Helper packages are allowed.");
                if (!string.Equals(Property(db, "UpgradeCode"), HelperUpgradeCode, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Package does not belong to the Helper product family.");
                return new Dictionary<string, object> { { "sha256", Data.FileHash(path) }, { "version", Property(db, "ProductVersion") }, { "productCode", Property(db, "ProductCode") }, {"supportsUnattended",SupportsUnattended(db)} };
            } finally { MsiCloseHandle(db); }
        }
        static bool SupportsUnattended(IntPtr db) {
            foreach(string action in new[]{"PrepareUnattendedPassword","SetUnattendedPassword"}) {
                IntPtr view=IntPtr.Zero, record=IntPtr.Zero;
                try {
                    if(MsiDatabaseOpenView(db,"SELECT `Action` FROM `CustomAction` WHERE `Action`='"+action+"'",out view)!=0 || MsiViewExecute(view,IntPtr.Zero)!=0 || MsiViewFetch(view,out record)!=0) return false;
                } finally {if(record!=IntPtr.Zero) MsiCloseHandle(record); if(view!=IntPtr.Zero) MsiCloseHandle(view);}
            }
            return true;
        }
        internal static bool SupportsUnattended(string path) {
            IntPtr db; if(MsiOpenDatabase(path,IntPtr.Zero,out db)!=0) return false;
            try {return SupportsUnattended(db);} finally {MsiCloseHandle(db);}
        }
        internal static bool InstalledSupportsUnattended(string product) {
            var path=new StringBuilder(4096); uint length=4095;
            return MsiGetProductInfo(product,"LocalPackage",path,ref length)==0 && File.Exists(path.ToString()) && SupportsUnattended(path.ToString());
        }
        internal static bool Installed(string product, string version) { uint length = 1023; var text = new StringBuilder(1024); return MsiGetProductInfo(product, "VersionString", text, ref length) == 0 && text.ToString() == version; }
    }
}
