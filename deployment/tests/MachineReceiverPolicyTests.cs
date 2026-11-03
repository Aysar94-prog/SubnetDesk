using System;
using System.Collections.Generic;
using System.Security.AccessControl;
using System.Security.Principal;
using SubnetDesk.Deployment;

internal static class MachineReceiverPolicyTests {
    static void Assert(bool value,string message){if(!value)throw new Exception("Device policy: "+message);}
    static Dictionary<string,object> Settings(string operation,string current="",string password="")=>new Dictionary<string,object>{{"operation",operation},{"currentPassword",current},{"newPassword",password}};
    internal static void Run(){
        const string original="synthetic-device-unlock", replacement="synthetic-device-rotation";
        var locked=MachineReceiverPolicy.Transition(null,Settings("receiver-lock",password:original),"legacy-per-user-hash",true);
        Assert((bool)locked["locked"] && !Data.Json(locked).Contains(original),"first device policy stores verifier only");
        foreach(string legacy in new[]{"different-user-hash","",new string('a',64)}) {
            var unlocked=MachineReceiverPolicy.Transition(locked,Settings("receiver-unlock",original),legacy,false);
            Assert(!(bool)unlocked["locked"] && Data.Text(unlocked,"passwordHash")==Data.Text(locked,"passwordHash"),"shared policy wins over each account and retains unlock credential");
        }
        string before=Data.Json(locked); bool denied=false;
        try{MachineReceiverPolicy.Transition(locked,Settings("receiver-unlock","incorrect"),"",false);}catch(InvalidOperationException){denied=true;}
        Assert(denied && Data.Json(locked)==before,"incorrect unlock leaves global policy unchanged");
        denied=false;try{MachineReceiverPolicy.Transition(locked,Settings("receiver-lock",password:replacement),"",false);}catch(InvalidOperationException){denied=true;}
        Assert(denied,"relocking cannot replace existing locked policy password");
        var rotated=MachineReceiverPolicy.Transition(locked,Settings("receiver-password",original,replacement),"",false);
        Assert((bool)rotated["locked"] && Data.Text(rotated,"passwordHash")!=Data.Text(locked,"passwordHash"),"rotation preserves locked mode");
        denied=false;try{MachineReceiverPolicy.Transition(rotated,Settings("receiver-unlock",original),"",false);}catch(InvalidOperationException){denied=true;}
        Assert(denied,"previous password rejected after rotation");
        var unlockedNow=MachineReceiverPolicy.Transition(rotated,Settings("receiver-unlock",replacement),"",true);
        var rotatedUnlocked=MachineReceiverPolicy.Transition(unlockedNow,Settings("receiver-password",replacement,original),"",true);
        Assert(!(bool)rotatedUnlocked["locked"],"rotating an unlocked device does not re-lock it");
        var persisted=Data.Parse(Data.Json(rotatedUnlocked));
        Assert(!(bool)persisted["locked"] && Convert.ToInt64(persisted["revision"])>Convert.ToInt64(locked["revision"]),"mode/verifier survive persistence independent of profiles");
        string encrypted=HelperSettings.Protect(Settings("receiver-password",original,replacement));
        Assert(Data.Text(HelperSettings.Unprotect(encrypted),"currentPassword")==original,"receiver credentials use protected queue");
        foreach(RegistryAccessRule rule in MachineReceiverPolicy.PolicySecurity().GetAccessRules(true,true,typeof(SecurityIdentifier))) {
            if(rule.IdentityReference.Value=="S-1-5-32-545") Assert((rule.RegistryRights & (RegistryRights.SetValue|RegistryRights.CreateSubKey|RegistryRights.ChangePermissions|RegistryRights.Delete))==0,"ordinary account policy access is read only");
        }
        Console.WriteLine("PASS device policy: first adoption, all-account precedence, wrong-password rejection, rotation without mode change, persistence, protected credentials and read-only user ACL.");
    }
}
