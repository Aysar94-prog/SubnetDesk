using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.ServiceProcess;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace SubnetDesk.Deployment {
    internal sealed class AgentSettings : Form {
        readonly TextBox server = new TextBox();
        readonly TextBox pin = new TextBox();
        readonly TextBox token = new TextBox { UseSystemPasswordChar = true };
        readonly TextBox code = new TextBox { Multiline = true, Height = 55, ScrollBars = ScrollBars.Vertical };
        readonly TextBox status = new TextBox { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Height = 140 };
        readonly Timer timer = new Timer { Interval = 3000 };
        readonly Label summary = new Label { AutoSize = true, MaximumSize = new Size(620, 0), ForeColor = Color.FromArgb(8, 127, 140) };
        static string ConfigPath { get { return Path.Combine(Data.Root, "Agent", "config.json"); } }
        internal AgentSettings() {
            Text = "SubnetDesk Endpoint Agent"; Font = new Font("Segoe UI", 10); BackColor = Color.FromArgb(243, 246, 250);
            Icon = System.Drawing.Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
            Size = new Size(760, 650); MinimumSize = new Size(700, 600);
            StartPosition = FormStartPosition.CenterScreen;
            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Padding = new Padding(22) };
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            Controls.Add(layout);
            var header = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Top, ColumnCount = 1, Padding = new Padding(0, 0, 0, 18) };
            header.Controls.Add(new Label { Text = "SubnetDesk Endpoint Agent", AutoSize = true, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = Color.FromArgb(23, 43, 77) });
            header.Controls.Add(new Label { Text = "Secure connection to your device management console", AutoSize = true, ForeColor = Color.FromArgb(101, 117, 139) });
            layout.Controls.Add(header);
            var tabs = new TabControl { Dock = DockStyle.Fill };
            var connectionPage = new TabPage("Connection") { BackColor = Color.White };
            var registrationPage = new TabPage("Advanced") { BackColor = Color.White };
            var diagnosticPage = new TabPage("Diagnostics") { BackColor = Color.White };
            tabs.TabPages.AddRange(new[] { connectionPage, registrationPage, diagnosticPage }); layout.Controls.Add(tabs);
            var connection = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, AutoScroll = true, Padding = new Padding(18) }; connectionPage.Controls.Add(connection);
            Add(connection, "Management server", server);
            connection.Controls.Add(new Label { Text = "Install the background service once. It starts with Windows and remains connected after closing this window.", AutoSize = true, MaximumSize = new Size(610, 0), Margin = new Padding(3, 14, 3, 14), ForeColor = Color.FromArgb(101, 117, 139) });
            connection.Controls.Add(summary);
            var buttons = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Top, Margin = new Padding(0, 20, 0, 8) };
            Button(buttons, Exists() ? "Save & reconnect" : "Install & connect", Save);
            if (File.Exists(ConfigPath)) Button(buttons, "Request server approval", () => Save(true));
            Button(buttons, "Test HTTPS", Test); Button(buttons, "Uninstall Agent", Remove); connection.Controls.Add(buttons);
            connection.Controls.Add(new Label { Text = "Enter your server and install. Your administrator approves this computer in Deploy > Agent requests. No registration code is needed. Use Request server approval if an old identity was revoked.", AutoSize = true, MaximumSize = new Size(610, 0), ForeColor = Color.FromArgb(101, 117, 139), Margin = new Padding(3, 15, 3, 3) });
            var registration = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, AutoScroll = true, Padding = new Padding(18) }; registrationPage.Controls.Add(registration);
            Add(registration, "Legacy registration code (optional)", code);
            var import = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Top };
            Button(import, "Apply registration code", () => Import(Data.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(code.Text.Trim())))));
            Button(import, "Import enrollment file", () => { using (var picker = new OpenFileDialog { Filter = "Enrollment JSON|*.json" }) if (picker.ShowDialog() == DialogResult.OK) Import(Data.Read(picker.FileName)); });
            registration.Controls.Add(import);
            Add(registration, "Server certificate identity (SHA256)", pin);
            Add(registration, "Enrollment token (only for first registration or server migration)", token);
            registration.Controls.Add(new Label { Text = "The normal flow uses server approval. These advanced fields support older registration codes. The reusable installer includes the server address and public certificate identity only.", AutoSize = true, MaximumSize = new Size(610, 0), ForeColor = Color.FromArgb(101, 117, 139) });
            diagnosticPage.Controls.Add(status); status.Dock = DockStyle.Fill; status.BorderStyle = BorderStyle.None; status.BackColor = Color.White; status.Font = new Font("Consolas", 9);
            layout.Controls.Add(new Label { Text = "SubnetDesk · Agent " + System.Reflection.Assembly.GetExecutingAssembly().GetName().Version + " · Administrator settings", AutoSize = true, ForeColor = Color.FromArgb(101, 117, 139), Padding = new Padding(0, 14, 0, 0) });
            if (File.Exists(ConfigPath)) { var config = Data.Read(ConfigPath); server.Text = Data.Text(config, "server"); pin.Text = Data.Text(config, "certificateSha256"); }
            var embedded = EmbeddedRegistration.Read(System.Reflection.Assembly.GetExecutingAssembly().Location);
            if (embedded != null && !File.Exists(ConfigPath)) Import(embedded);
            else if (embedded != null) Button(buttons, "Use included server", () => { Import(embedded); MessageBox.Show(this, "Server settings loaded. Use Request server approval to replace a revoked identity, or Save & reconnect to preserve an existing identity on this server.", "Server loaded"); });
            timer.Tick += (s, e) => RefreshStatus(); timer.Start(); RefreshStatus();
        }
        void Add(TableLayoutPanel layout, string label, Control control) { layout.Controls.Add(new Label { Text = label, AutoSize = true }); control.Dock = DockStyle.Top; layout.Controls.Add(control); }
        void Button(Control parent, string label, Action action) {
            bool primary = label.StartsWith("Install") || label.StartsWith("Save");
            var button = new Button { Text = label, UseMnemonic = false, AutoSize = true, FlatStyle = FlatStyle.Flat, Padding = new Padding(8, 5, 8, 5), BackColor = primary ? Color.FromArgb(8, 127, 140) : Color.White, ForeColor = primary ? Color.White : Color.FromArgb(23, 43, 77), Margin = new Padding(3, 5, 8, 5) };
            button.FlatAppearance.BorderColor = Color.FromArgb(217, 226, 236);
            button.Click += (s, e) => { try { action(); } catch (Exception error) { MessageBox.Show(this, error.Message, "SubnetDesk Agent", MessageBoxButtons.OK, MessageBoxIcon.Error); } };
            parent.Controls.Add(button);
        }
        void Import(Dictionary<string, object> config) { server.Text = Data.Text(config, "server"); pin.Text = Data.Text(config, "certificateSha256"); token.Text = Data.Text(config, "enrollmentToken"); code.Clear(); }
        Dictionary<string, object> Draft() {
            string address = server.Text.Trim(); if (!address.EndsWith("/")) address += "/";
            Data.Endpoint(address);
            if (!System.Text.RegularExpressions.Regex.IsMatch(pin.Text.Trim(), "^[A-Fa-f0-9]{64}$")) throw new InvalidDataException("Paste the server fingerprint from Deploy. Do not disable certificate verification.");
            return new Dictionary<string, object> { { "server", address }, { "certificateSha256", pin.Text.Trim().ToUpperInvariant() } };
        }
        void Save() { Save(false); }
        void Save(bool requestApproval) {
            if (File.Exists(Path.Combine(Data.Root,"Agent","agent-update.json"))) throw new InvalidOperationException("An Agent update is in progress. Wait for its result before changing registration or settings.");
            if (pin.Text.Trim() == "") TrustServer();
            var config = Draft();
            if (File.Exists(ConfigPath)) {
                var previous = Data.Read(ConfigPath);
                bool same = string.Equals(Data.Text(previous, "server"), Data.Text(config, "server"), StringComparison.OrdinalIgnoreCase) && Data.Text(previous, "certificateSha256") == Data.Text(config, "certificateSha256");
                if (same && token.Text.Trim() == "" && !requestApproval) config = previous;
                else if (MessageBox.Show(this, "Register this device again? Revoke its previous identity on the old server after migration. Queued local results will be archived.", "Change management server", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
            }
            if (!config.ContainsKey("deviceId") && !config.ContainsKey("enrollmentToken")) {
                if (!requestApproval && token.Text.Trim() != "") {
                    if (Convert.FromBase64String(token.Text.Trim()).Length != 32) throw new InvalidDataException("Invalid legacy enrollment token.");
                    config["enrollmentToken"] = token.Text.Trim();
                } else config["approvalRequired"] = "true";
            }
            Install(config);
            token.Clear(); RefreshStatus();
        }
        internal static void Install(Dictionary<string, object> config) {
            if (File.Exists(Path.Combine(Data.Root, "Agent", "agent-update.json"))) throw new InvalidOperationException("An Agent update is in progress.");
            if (File.Exists(Path.Combine(Data.Root, "Agent", "pending.json"))) throw new InvalidOperationException("A Helper operation is in progress. Wait for its result before installing Agent.");
            Data.SecureRoot(); StopService();
            string installed = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "SubnetDesk Agent Runtime", "SubnetDeskAgent.exe");
            Directory.CreateDirectory(Path.GetDirectoryName(installed));
            string current = System.Reflection.Assembly.GetExecutingAssembly().Location;
            if (!string.Equals(current, installed, StringComparison.OrdinalIgnoreCase)) EmbeddedRegistration.CopyRuntime(current, installed);
            if (!config.ContainsKey("deviceId")) foreach (string name in new[] { "pending.json", "result.json" }) {
                string path = Path.Combine(Data.Root, "Agent", name);
                if (File.Exists(path)) File.Move(path, path + ".migration-" + DateTime.UtcNow.Ticks);
            }
            Data.Save(ConfigPath, config);
            Msi.RemoveLegacyAgent();
            // sc.exe arguments are fixed except the system Program Files path.
            if (!Exists()) Sc("create SubnetDeskAgent binPath= \"\\\"" + installed + "\\\" --service\" start= auto DisplayName= \"SubnetDesk Deployment Agent\"");
            else Sc("config SubnetDeskAgent binPath= \"\\\"" + installed + "\\\" --service\" start= auto");
            using (var service = new ServiceController("SubnetDeskAgent")) service.Start();
            Sc("failure SubnetDeskAgent reset= 86400 actions= restart/5000/restart/15000/restart/60000");
            using (var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SubnetDeskAgentRuntime")) {
                key.SetValue("DisplayName", "SubnetDesk Endpoint Agent"); key.SetValue("Publisher", "SubnetDesk");
                key.SetValue("DisplayVersion", System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString());
                key.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd")); key.SetValue("EstimatedSize", (int)(new FileInfo(installed).Length / 1024));
                key.SetValue("InstallLocation", Path.GetDirectoryName(installed)); key.SetValue("DisplayIcon", installed);
                key.SetValue("UninstallString", "\"" + installed + "\" --remove"); key.SetValue("NoModify", 1); key.SetValue("NoRepair", 1);
            }
            try {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                dynamic shell = Activator.CreateInstance(shellType);
                dynamic shortcut = shell.CreateShortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), "SubnetDesk Agent Settings.lnk"));
                shortcut.TargetPath = installed; shortcut.Arguments = "--settings"; shortcut.WorkingDirectory = Path.GetDirectoryName(installed); shortcut.IconLocation = installed + ",0"; shortcut.Save();
                System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shortcut); System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
            } catch (Exception e) { Data.Log("Agent", "Start menu shortcut could not be created: " + e.GetType().Name); }
            using (var service = new ServiceController("SubnetDeskAgent")) service.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
        }
        static void Sc(string arguments) {
            using (var process = Process.Start(new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "sc.exe"), arguments) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true })) {
                string output = process.StandardOutput.ReadToEnd(); string error = process.StandardError.ReadToEnd(); process.WaitForExit();
                if (process.ExitCode != 0) throw new InvalidOperationException("Service setup failed: " + output + error);
            }
        }
        static bool Exists() { try { using (var service = new ServiceController("SubnetDeskAgent")) { var state = service.Status; return true; } } catch (InvalidOperationException) { return false; } }
        static void StopService() { if (Exists()) using (var service = new ServiceController("SubnetDeskAgent")) { if (service.Status != ServiceControllerStatus.Stopped) { service.Stop(); service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30)); } } }
        [System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
        static extern bool MoveFileEx(string source, string destination, int flags);
        internal void Remove() {
            if (File.Exists(Path.Combine(Data.Root,"Agent","agent-update.json"))) throw new InvalidOperationException("An Agent update is in progress. Wait for its result before uninstalling.");
            if (MessageBox.Show(this, "Uninstall the Agent? Helper remains installed. Saved registration is preserved for reinstall.", "Uninstall SubnetDesk Agent", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
            StopService(); if (Exists()) Sc("delete SubnetDeskAgent");
            Registry.LocalMachine.DeleteSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SubnetDeskAgentRuntime", false);
            string shortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), "SubnetDesk Agent Settings.lnk"); if (File.Exists(shortcut)) File.Delete(shortcut);
            string installed = Path.GetFullPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "SubnetDesk Agent Runtime", "SubnetDeskAgent.exe"));
            try { if (File.Exists(installed)) File.Delete(installed); }
            catch (IOException) { if (!MoveFileEx(installed, null, 4)) throw new IOException("Service removed, but executable cleanup could not be scheduled."); }
            RefreshStatus();
        }
        void Test() {
            if (pin.Text.Trim() == "") TrustServer();
            var request = Data.Request(Draft(), "health", "GET", ""); request.Timeout = 5000;
            try { using (var response = request.GetResponse()) MessageBox.Show(this, "HTTPS connection and server certificate verified."); }
            catch (WebException error) { if (error.Response != null) { error.Response.Close(); MessageBox.Show(this, "HTTPS reached the server; registration is required."); } else throw; }
        }
        void TrustServer() {
            string address = server.Text.Trim();
            if (!address.Contains("://")) address = "https://" + address;
            if (Uri.TryCreate(address, UriKind.Absolute, out var uri) && (uri.AbsolutePath == "/" || uri.AbsolutePath == "")) address = address.TrimEnd('/') + "/subnetdesk/";
            if (!address.EndsWith("/")) address += "/";
            Data.Endpoint(address); server.Text = address;
            System.Security.Cryptography.X509Certificates.X509Certificate2 certificate = null;
            var request = (HttpWebRequest)WebRequest.Create(new Uri(new Uri(address), "health"));
            request.Timeout = 7000; request.Proxy = null; request.AllowAutoRedirect = false;
            request.ServerCertificateValidationCallback = (sender, cert, chain, errors) => {
                if (cert != null && (errors & (System.Net.Security.SslPolicyErrors.RemoteCertificateNameMismatch | System.Net.Security.SslPolicyErrors.RemoteCertificateNotAvailable)) == 0) certificate = new System.Security.Cryptography.X509Certificates.X509Certificate2(cert);
                return false; // Discovery never authenticates or sends a request to an untrusted server.
            };
            try { using (var response = request.GetResponse()) { } } catch (WebException e) { if (e.Response != null) e.Response.Close(); if (certificate == null) throw; }
            if (certificate == null) throw new InvalidOperationException("The server certificate could not be read. Check the address and certificate name.");
            using (certificate) {
                if (DateTime.Now < certificate.NotBefore || DateTime.Now > certificate.NotAfter) throw new InvalidOperationException("The server certificate is outside its validity period.");
                string fingerprint = Data.Hash(certificate.RawData);
                if (MessageBox.Show(this, "Trust this management server?\r\n" + address + "\r\nSHA256: " + fingerprint + "\r\nCompare this fingerprint with Deploy > Server & enrollment before accepting. Configured installers already include it.", "Confirm management server identity", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) throw new InvalidOperationException("Server trust was not confirmed.");
                pin.Text = fingerprint;
            }
        }
        void RefreshStatus() {
            try {
                string text = Exists() ? "Service: " + ServiceStatus() : "Service: not installed.";
                string approval = "";
                if (File.Exists(ConfigPath)) { var config = Data.Read(ConfigPath); text += "\r\nServer: " + Data.Text(config, "server") + "\r\nRegistration: " + (Data.Text(config, "deviceId") == "" ? "Pending — check connection/log below" : Data.Text(config, "deviceId"));
                    if (Data.Text(config, "approvalRequired") == "true") { approval = Data.Text(config, "approvalState"); if (approval == "") approval = "Connecting to request approval"; text += "\r\nServer approval: " + approval; if (Data.Text(config, "candidateToken") != "") text += "\r\nVerification: " + Data.Hash(Encoding.UTF8.GetBytes(Data.Text(config, "candidateToken"))).Substring(0, 12); }
                }
                string log = Path.Combine(Data.Root, "Agent.log"); if (File.Exists(log)) { string[] lines = File.ReadAllLines(log); text += "\r\n" + string.Join("\r\n", lines, Math.Max(0, lines.Length - 5), Math.Min(5, lines.Length)); }
                status.Text = text; summary.Text = text.Split(new[] { "\r\n" }, StringSplitOptions.None)[0] + "\r\n" + (approval != "" ? "Server approval: " + approval + ". Your administrator reviews Agent requests in Deploy." : File.Exists(ConfigPath) ? "Settings saved. Review Diagnostics for registration and connection results." : "Install & connect, then approve this computer in Deploy. No registration code needed.");
            } catch (IOException) { status.Text = "Agent is updating status; retry shortly."; }
        }
        static string ServiceStatus() { using (var service = new ServiceController("SubnetDeskAgent")) return service.Status.ToString(); }
        protected override void Dispose(bool disposing) { if (disposing) timer.Dispose(); base.Dispose(disposing); }
    }
}
