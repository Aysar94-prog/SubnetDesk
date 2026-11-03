using System;
using System.Collections.Generic;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32;

namespace SubnetDesk.Deployment {
    internal static class MachineReceiverPolicy {
        const string PathKey=@"SOFTWARE\SubnetDesk\DevicePolicy";
        const string DefaultHash="b008f337c227dcb4fa0fa4b1e9b915dd24a34e698b6739236f96b29fa9d2f532";
        static readonly object Gate=new object();
        internal static bool Supported(string version) {
            Version parsed;
            if(!Version.TryParse(version,out parsed) || parsed<new Version(1,4,5,0)) return false;
            using(var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64))
            using(var key=hive.OpenSubKey(@"SOFTWARE\SubnetDesk\Helper")) return key!=null && Convert.ToString(key.GetValue("ReceiverPolicyProtocol"))=="1";
        }
        static Dictionary<string,object> Read() {
            using(var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64))
            using(var key=hive.OpenSubKey(PathKey)) {
                if(key==null || key.GetValue("ReceiverPolicy")==null) return null;
                Dictionary<string,object> policy;
                try {policy=Data.Parse(Convert.ToString(key.GetValue("ReceiverPolicy")));}
                catch(Exception e) when(e is ArgumentException || e is InvalidOperationException || e is FormatException) {throw new InvalidDataException("Device receiver policy is damaged. Administrator repair is required.");}
                object locked; long revision;
                if(Data.Text(policy,"schema")!="1" || !policy.TryGetValue("locked",out locked) || !(locked is bool) || !long.TryParse(Data.Text(policy,"revision"),out revision) || revision<0 || !System.Text.RegularExpressions.Regex.IsMatch(Data.Text(policy,"passwordHash"),"^[a-fA-F0-9]{64}$")) throw new InvalidDataException("Device receiver policy is damaged. Administrator repair is required.");
                return policy;
            }
        }
        internal static RegistrySecurity PolicySecurity() {
            var acl=new RegistrySecurity(); acl.SetAccessRuleProtection(true,false);
            foreach(string sid in new[]{"S-1-5-18","S-1-5-32-544"}) acl.AddAccessRule(new RegistryAccessRule(new SecurityIdentifier(sid),RegistryRights.FullControl,InheritanceFlags.ContainerInherit,PropagationFlags.None,AccessControlType.Allow));
            acl.AddAccessRule(new RegistryAccessRule(new SecurityIdentifier("S-1-5-32-545"),RegistryRights.ReadKey,InheritanceFlags.ContainerInherit,PropagationFlags.None,AccessControlType.Allow));
            return acl;
        }
        static void Save(Dictionary<string,object> policy) {
            using(var hive=RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64))
            {
                using(var created=hive.CreateSubKey(PathKey)) { }
                using(var key=hive.OpenSubKey(PathKey,RegistryKeyPermissionCheck.ReadWriteSubTree,RegistryRights.FullControl)) {
                key.SetAccessControl(PolicySecurity());
                // One registry value makes mode + verifier changes atomic for all readers.
                key.SetValue("ReceiverPolicy",Data.Json(policy),RegistryValueKind.String);
                }
            }
        }
        internal static Dictionary<string,object> Transition(Dictionary<string,object> previous,Dictionary<string,object> settings,string legacyHash,bool legacyLocked) {
            settings=HelperSettings.Validate(settings);
            string operation=Data.Text(settings,"operation"), password=Data.Text(settings,"newPassword"), current=Data.Text(settings,"currentPassword");
            if(operation=="unattended-password") throw new InvalidDataException("Unattended password is separate from receiver policy.");
            string hash=previous==null ? legacyHash : Data.Text(previous,"passwordHash");
            bool locked=previous==null ? legacyLocked : (bool)previous["locked"];
            if(operation=="receiver-unlock" || operation=="receiver-password") {
                if(hash=="" && locked) hash=DefaultHash;
                if(hash=="" || !Data.Equal(hash.ToLowerInvariant(),Data.Hash(Encoding.UTF8.GetBytes(current)).ToLowerInvariant())) throw new InvalidOperationException("Incorrect current receiver unlock password. Device policy was not changed.");
            }
            if(operation=="receiver-lock") {
                string next=Data.Hash(Encoding.UTF8.GetBytes(password)).ToLowerInvariant();
                if(previous!=null && locked && !Data.Equal(hash.ToLowerInvariant(),next)) throw new InvalidOperationException("Device is already locked. Use Change receiver unlock password with the current password.");
                hash=next; locked=true;
            } else if(operation=="receiver-unlock") locked=false;
            else if(operation=="receiver-password") hash=Data.Hash(Encoding.UTF8.GetBytes(password)).ToLowerInvariant();
            long revision=previous==null ? 0 : Convert.ToInt64(previous["revision"]);
            return new Dictionary<string,object>{{"schema",1},{"locked",locked},{"passwordHash",hash},{"revision",checked(revision+1)}};
        }
        internal static string Apply(Dictionary<string,object> settings) {
            if(!Supported(Data.Text(Msi.Inventory(),"version"))) throw new InvalidOperationException("Device-wide receiver policy requires Helper 1.4.5 or later.");
            lock(Gate) {
                var policy=Read(); string legacyHash=""; bool legacyLocked=true;
                if(policy==null && Data.Text(settings,"operation")!="receiver-lock") {
                    legacyHash=HelperSecurity.ReadReceiverOption("incoming-only-password");
                    legacyLocked=legacyHash!="" || HelperSecurity.ReadReceiverOption("incoming-only")=="Y" || HelperSecurity.ReadReceiverOption("incoming-only-initialized")=="locked";
                }
                var updated=Transition(policy,settings,legacyHash,legacyLocked); Save(updated);
                var verified=Read(); if(verified==null || Data.Text(verified,"passwordHash")!=Data.Text(updated,"passwordHash") || Data.Text(verified,"locked")!=Data.Text(updated,"locked") || Data.Text(verified,"revision")!=Data.Text(updated,"revision")) throw new InvalidOperationException("Device receiver policy could not be verified.");
                return (bool)updated["locked"] ? "Device-wide receiver-only policy applied to all Windows accounts. Unattended access password is unchanged. Reopen Helper to refresh its layout." : "Device-wide send-and-receive enabled for all Windows accounts. Unattended access password is unchanged. Reopen Helper to refresh its layout.";
            }
        }
        internal static void AddInventory(Dictionary<string,object> inventory) {
            bool supported=Supported(Data.Text(inventory,"version")); inventory["receiverPolicyProtocol"]=supported ? "1" : "";
            if(!supported) return;
            try {
                var policy=Read(); inventory["receiverScope"]=policy==null ? "profile" : "device";
                if(policy!=null) inventory["receiverOnly"]=(bool)policy["locked"];
            } catch(Exception e) when(e is InvalidDataException || e is UnauthorizedAccessException || e is System.Security.SecurityException) {
                inventory["receiverScope"]="device (policy unreadable)"; inventory["receiverOnly"]=true;
            }
        }
    }
}
