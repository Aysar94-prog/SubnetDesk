using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Security.Principal;
using System.Text.RegularExpressions;

namespace SubnetDesk.Deployment {
    internal static class SilentAgentSetup {
        internal static string Server(string address) {
            address=address.Trim();
            IPAddress ip;
            if(IPAddress.TryParse(address,out ip) && ip.AddressFamily==System.Net.Sockets.AddressFamily.InterNetworkV6) address="["+ip+"]";
            if(!address.Contains("://")) address="https://"+address;
            Uri uri;
            if(!Uri.TryCreate(address,UriKind.Absolute,out uri)) throw new InvalidDataException("Invalid management server address.");
            if(uri.AbsolutePath=="/") address=address.TrimEnd('/')+"/subnetdesk/";
            else if(!address.EndsWith("/")) address+="/";
            return Data.Endpoint(address).AbsoluteUri;
        }
        internal static Dictionary<string,object> Configuration(string[] args,Dictionary<string,object> embedded,Dictionary<string,object> previous) {
            var values=new Dictionary<string,string>(StringComparer.Ordinal);
            foreach(string name in new[]{"--install","--silent","--replace-registration"}) values[name]="false";
            for(int i=0;i<args.Length;i++) {
                string key=args[i];
                if(key=="--install" || key=="--silent" || key=="--replace-registration") {
                    if(values[key]=="true") throw new InvalidDataException("Duplicate setup option."); values[key]="true";
                } else if(key=="--server" || key=="--certificate-sha256") {
                    if(values.ContainsKey(key) || i+1>=args.Length || args[i+1].StartsWith("--")) throw new InvalidDataException("Missing or duplicate setup parameter.");
                    values[key]=args[++i];
                } else throw new InvalidDataException("Unknown silent setup option.");
            }
            if(values["--install"]!="true" || values["--silent"]!="true" || !values.ContainsKey("--server")) throw new InvalidDataException("Use --install --silent --server <management-server> [--certificate-sha256 <fingerprint>].");
            string server=Server(values["--server"]), pin="";
            if(values.ContainsKey("--certificate-sha256")) pin=values["--certificate-sha256"].Trim();
            else foreach(var config in new[]{previous,embedded}) {
                if(config!=null && string.Equals(Data.Text(config,"server"),server,StringComparison.OrdinalIgnoreCase)) {pin=Data.Text(config,"certificateSha256"); if(pin!="") break;}
            }
            if(!Regex.IsMatch(pin,"^[A-Fa-f0-9]{64}$")) throw new InvalidDataException("A trusted management certificate fingerprint is required. Use a server-configured Agent setup or --certificate-sha256.");
            pin=pin.ToUpperInvariant();
            bool same=previous!=null && string.Equals(Data.Text(previous,"server"),server,StringComparison.OrdinalIgnoreCase) && string.Equals(Data.Text(previous,"certificateSha256"),pin,StringComparison.OrdinalIgnoreCase);
            if(previous!=null && !same && values["--replace-registration"]!="true") throw new InvalidDataException("Server identity differs. Use --replace-registration only for an intended migration.");
            if(same && values["--replace-registration"]!="true") return new Dictionary<string,object>(previous);
            return new Dictionary<string,object>{{"server",server},{"certificateSha256",pin},{"approvalRequired","true"}};
        }
        internal static int Run(string[] args) {
            try {
                // Remote push/GPO must launch elevated. The EXE manifest requires
                // administrator rights before Main; setup never accepts trust automatically.
                if(!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) return 5;
                Data.SecureRoot();
                string path=Path.Combine(Data.Root,"Agent","config.json");
                var previous=File.Exists(path) ? Data.Read(path) : null;
                var embedded=EmbeddedRegistration.Read(System.Reflection.Assembly.GetExecutingAssembly().Location);
                var config=Configuration(args,embedded,previous);
                AgentSettings.Install(config);
                Data.Log("AgentSetup","Silent installation completed; service running. Registration approval is reviewed in Deploy.");
                return 0;
            } catch(InvalidDataException e) {Console.Error.WriteLine(e.Message); Data.Log("AgentSetup",e.Message); return 2;}
            catch(Exception e) {Data.Log("AgentSetup","Silent installation failed: "+e.GetType().Name); return 1;}
        }
    }
}
