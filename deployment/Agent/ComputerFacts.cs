using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Management;
using Microsoft.Win32;

namespace SubnetDesk.Deployment {
    internal static class ComputerFacts {
        static readonly object osGate = new object();
        static string osName;
        static DateTime osReadUtc;
        [DllImport("netapi32.dll", CharSet = CharSet.Unicode)] static extern int NetGetJoinInformation(string server, out IntPtr name, out int status);
        [DllImport("netapi32.dll")] static extern int NetApiBufferFree(IntPtr buffer);
        internal static Dictionary<string, object> Read() {
            string domain = ""; object joined = null; IntPtr name = IntPtr.Zero;
            try { int status; if (NetGetJoinInformation(null, out name, out status) == 0) { domain = Marshal.PtrToStringUni(name) ?? ""; joined = status == 3; } }
            finally { if (name != IntPtr.Zero) NetApiBufferFree(name); }
            return new Dictionary<string, object> { { "machine", Environment.MachineName }, { "domain", domain }, { "domainJoined", joined }, { "operatingSystem", OperatingSystemName() }, { "architecture", Environment.Is64BitOperatingSystem ? "x64" : "x86" } };
        }
        internal static string FormatOperatingSystem(string caption, string release, string build, string revision) {
            caption = caption.Trim(); release = release.Trim(); build = build.Trim(); revision = revision.Trim();
            if (caption == "") caption = "Windows (edition unavailable)";
            if (release != "") caption += " " + release;
            if (build != "") caption += " (Build " + build + (revision == "" ? "" : "." + revision) + ")";
            return caption;
        }
        internal static string OperatingSystemName() {
            lock (osGate) {
                if (osName != null && DateTime.UtcNow - osReadUtc < TimeSpan.FromMinutes(5)) return osName;
                string caption = "", release = "", build = "", revision = "", installation = "";
                try {
                    using (var hive = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, Environment.Is64BitOperatingSystem ? RegistryView.Registry64 : RegistryView.Registry32))
                    using (var key = hive.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion")) {
                        if (key != null) {
                            caption = Convert.ToString(key.GetValue("ProductName"));
                            release = Convert.ToString(key.GetValue("DisplayVersion"));
                            build = Convert.ToString(key.GetValue("CurrentBuildNumber"));
                            revision = Convert.ToString(key.GetValue("UBR"));
                            installation = Convert.ToString(key.GetValue("InstallationType"));
                        }
                    }
                } catch (Exception e) when (e is UnauthorizedAccessException || e is System.Security.SecurityException || e is System.IO.IOException) {
                    Data.Log("Agent", "Windows registry inventory unavailable: " + e.GetType().Name);
                }
                // Older ProductName registry values may retain Windows 10 on Windows 11.
                int number;
                if (installation == "Client" && int.TryParse(build, out number) && number >= 22000 && caption.StartsWith("Windows 10", StringComparison.OrdinalIgnoreCase)) caption = "Windows 11" + caption.Substring("Windows 10".Length);
                try {
                    using (var searcher = new ManagementObjectSearcher("root\\CIMV2", "SELECT Caption, BuildNumber FROM Win32_OperatingSystem")) {
                        searcher.Options.Timeout = TimeSpan.FromSeconds(5);
                        using (var rows = searcher.Get()) foreach (ManagementObject row in rows) using (row) {
                            string actual = Convert.ToString(row["Caption"]).Trim(), actualBuild = Convert.ToString(row["BuildNumber"]).Trim();
                            if (actual != "") caption = actual;
                            if (actualBuild != "") { if (build != actualBuild) revision = ""; build = actualBuild; }
                            break;
                        }
                    }
                } catch (Exception e) when (e is ManagementException || e is COMException || e is UnauthorizedAccessException || e is System.Security.SecurityException) {
                    Data.Log("Agent", "Windows WMI caption unavailable; using registry inventory: " + e.GetType().Name);
                }
                osName = FormatOperatingSystem(caption, release, build, revision); osReadUtc = DateTime.UtcNow;
                return osName;
            }
        }
    }
}
