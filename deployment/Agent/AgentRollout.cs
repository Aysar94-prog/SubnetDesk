using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace SubnetDesk.Deployment {
    internal sealed class AgentRollout {
        readonly string root,setup;
        readonly object gate=new object();
        readonly IWindowsAgentPush transport;
        readonly Func<Dictionary<string,object>> server;
        static readonly byte[] Entropy=Encoding.UTF8.GetBytes("SubnetDesk.AgentRollout.Credentials.v1");
        internal AgentRollout(string managementFolder,Func<Dictionary<string,object>> serverConfig,IWindowsAgentPush push=null,string agentSetup=null) {
            root=Path.Combine(managementFolder,"rollout");server=serverConfig;transport=push??new WindowsAgentPush();
            setup=agentSetup??Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"SubnetDeskAgent.exe");
        }
        string PathFor(string kind,string id) {return Path.Combine(root,kind,Data.Id(id)+".json");}
        List<Dictionary<string,object>> Records(string kind) {
            string path=Path.Combine(root,kind);
            return Directory.Exists(path) ? Directory.GetFiles(path,"*.json").Select(Data.Read).ToList() : new List<Dictionary<string,object>>();
        }
        internal static List<string> Targets(string ranges) {
            var result=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(string item in ranges.Split(new[]{'\r','\n',',',';'},StringSplitOptions.RemoveEmptyEntries)) {
                string value=item.Trim();
                if(value.Contains("/")) {
                    var parts=value.Split('/'); IPAddress ip; int prefix;
                    if(parts.Length!=2 || !IPAddress.TryParse(parts[0],out ip) || ip.AddressFamily!=AddressFamily.InterNetwork || !int.TryParse(parts[1],out prefix) || prefix<16 || prefix>32) throw new InvalidDataException("Use IPv4 CIDR /16–/32, an IPv4 range, or one hostname per line.");
                    var bytes=ip.GetAddressBytes(); uint address=((uint)bytes[0]<<24)|((uint)bytes[1]<<16)|((uint)bytes[2]<<8)|bytes[3];
                    uint size=1u<<(32-prefix),network=address & ~(size-1);
                    uint first=prefix<31 ? 1u : 0u, end=prefix<31 ? size-1 : size;
                    for(uint i=first;i<end;i++) {uint n=network+i;result.Add(new IPAddress(new[]{(byte)(n>>24),(byte)(n>>16),(byte)(n>>8),(byte)n}).ToString());}
                } else if(value.Contains("-") && Regex.IsMatch(value,@"^\d+\.\d+\.\d+\.\d+-\d+\.\d+\.\d+\.\d+$")) {
                    var p=value.Split('-');var first=Targets(p[0])[0];var last=Targets(p[1])[0];
                    Func<string,uint> number=s=>{var b=IPAddress.Parse(s).GetAddressBytes();return ((uint)b[0]<<24)|((uint)b[1]<<16)|((uint)b[2]<<8)|b[3];};
                    uint a=number(first),beyond=number(last);if(beyond<a || (ulong)beyond-a>=65536) throw new InvalidDataException("Use ranges of at most 65536 addresses.");
                    for(ulong n=a;n<=(ulong)beyond;n++) result.Add(new IPAddress(new[]{(byte)(n>>24),(byte)(n>>16),(byte)(n>>8),(byte)n}).ToString());
                } else {
                    IPAddress ip;
                    if(IPAddress.TryParse(value,out ip)) {if(ip.AddressFamily!=AddressFamily.InterNetwork) throw new InvalidDataException("IPv4 discovery ranges are required."); value=ip.ToString();}
                    else if(value.Length>253 || !Regex.IsMatch(value,@"^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$")) throw new InvalidDataException("Invalid target hostname or IPv4 address.");
                    result.Add(value);
                }
                if(result.Count>65536) throw new InvalidDataException("Split discovery into jobs of at most 65536 addresses. There is no four-device deployment limit.");
            }
            if(result.Count==0) throw new InvalidDataException("Enter at least one subnet, IP range or hostname.");
            return result.OrderBy(s=>s,StringComparer.OrdinalIgnoreCase).ToList();
        }
        internal static List<object> ConnectedSubnets() {
            var result=new List<object>(); var seen=new HashSet<string>();
            foreach(var nic in NetworkInterface.GetAllNetworkInterfaces()) if(nic.OperationalStatus==OperationalStatus.Up) foreach(var unicast in nic.GetIPProperties().UnicastAddresses) {
                if(unicast.Address.AddressFamily!=AddressFamily.InterNetwork || IPAddress.IsLoopback(unicast.Address) || unicast.Address.ToString().StartsWith("169.254.")) continue;
                var ip=unicast.Address.GetAddressBytes();var mask=unicast.IPv4Mask.GetAddressBytes(); int prefix=0;var network=new byte[4];
                for(int i=0;i<4;i++){network[i]=(byte)(ip[i]&mask[i]);for(int bit=7;bit>=0;bit--) if((mask[i]&(1<<bit))!=0)prefix++;}
                string cidr=new IPAddress(network)+"/"+prefix;
                if(prefix>=16 && seen.Add(cidr)) result.Add(new {range=cidr,adapter=nic.Name});
            }
            return result;
        }
        static int Parallelism(Dictionary<string,object> body) {int n;if(!int.TryParse(Data.Text(body,"parallelism"),out n)) n=20;if(n<1 || n>128) throw new InvalidDataException("Simultaneous operations must be 1–128; remaining devices are queued.");return n;}
        Dictionary<string,object> Credential(string id) {
            var saved=Data.Read(PathFor("profiles",id));
            return Data.Parse(Encoding.UTF8.GetString(ProtectedData.Unprotect(Convert.FromBase64String(Data.Text(saved,"protectedCredential")),Entropy,DataProtectionScope.LocalMachine)));
        }
        internal object Profile(Dictionary<string,object> body) {
            lock(gate) {
            string requestedId=Data.Text(body,"id"),id=requestedId=="" ? Guid.NewGuid().ToString("D") : Data.Id(requestedId);
            Dictionary<string,object> saved=null;
            if(requestedId!="") {saved=Data.Read(PathFor("profiles",id));CheckProfileIdle(id);}
            string user=Data.Text(body,"username").Trim(),password=Data.Text(body,"password"),kind=Data.Text(body,"accountType");
            if(kind!="local" && kind!="domain") throw new InvalidDataException("Select local or domain administrator.");
            if(kind=="local" && user.StartsWith(".\\")) user=user.Substring(2);
            if(user=="" || user.Length>256 || user.Any(char.IsControl) || (password=="" && saved==null) || password.Length>1024) throw new InvalidDataException("Enter a valid Windows username and password, not a PIN.");
            if(kind=="local" && (user.Contains("\\") || user.Contains("@"))) throw new InvalidDataException("For local administrator, enter only the account name; the target computer is supplied automatically.");
            if(kind=="domain" && !user.Contains("\\") && !user.Contains("@")) throw new InvalidDataException("Use DOMAIN\\user or user@domain for domain credentials.");
            string name=Data.Text(body,"name").Trim();if(name=="") name=user;
            if(name.Length>128 || name.Any(char.IsControl)) throw new InvalidDataException("Use a profile name of at most 128 characters without control characters.");
            if(Records("profiles").Any(p=>Data.Text(p,"id")!=id && string.Equals(Data.Text(p,"name").Trim(),name,StringComparison.OrdinalIgnoreCase))) throw new InvalidDataException("A credential profile with this name already exists. Choose another name or edit that profile.");
            if(password=="") {
                if(Data.Text(saved,"username")!=user || Data.Text(saved,"accountType")!=kind) throw new InvalidDataException("Enter the password when changing the account name or account type.");
                password=Data.Text(Credential(id),"password");
            }
            var secret=new {username=user,password=password,accountType=kind};
            string encrypted=Convert.ToBase64String(ProtectedData.Protect(Encoding.UTF8.GetBytes(Data.Json(secret)),Entropy,DataProtectionScope.LocalMachine));
            Data.Save(PathFor("profiles",id),new {id=id,name=name,username=user,accountType=kind,protectedCredential=encrypted});
            return new {id=id,name=name,username=user,accountType=kind};
            }
        }
        void CheckProfileIdle(string id) {
            if(Records("jobs").Any(j=>Data.Text(j,"profileId")==id && (Data.Text(j,"state")=="queued" || Data.Text(j,"state")=="running"))) throw new InvalidOperationException("This credential profile is used by a queued or running job. Finish or cancel that job first.");
        }
        void DeleteProfile(string id) {
            string path=PathFor("profiles",id);Data.Read(path);CheckProfileIdle(id);
            if(Records("schedules").Any(s=>Data.Text(s,"profileId")==id)) throw new InvalidOperationException("This credential profile is used by a schedule and cannot be deleted.");
            File.Delete(path);
        }
        Dictionary<string,object> Plan(string kind,Dictionary<string,object> body) {
            if(kind!="discover" && kind!="push") throw new InvalidDataException("Unsupported Agent deployment operation.");
            string profile=Data.Id(Data.Text(body,"profileId"));Credential(profile);
            var plan=new Dictionary<string,object>{{"kind",kind},{"profileId",profile},{"parallelism",Parallelism(body)}};
            if(kind=="discover") {string ranges=Data.Text(body,"ranges");Targets(ranges);plan["ranges"]=ranges;}
            else {
                object raw; if(!body.TryGetValue("deviceIds",out raw) || !(raw is IEnumerable) || raw is string) throw new InvalidDataException("Select verified Windows devices.");
                var devices=new List<object>(); var unique=new HashSet<string>();
                foreach(object idValue in (IEnumerable)raw) {
                    string id=Data.Id(Convert.ToString(idValue));if(!unique.Add(id))continue;
                    var device=Data.Read(PathFor("devices",id));
                    if(Data.Text(device,"verifiedWindows")!="True") throw new InvalidDataException("Only verified Windows devices can receive Agent.");
                    if(Data.Text(device,"uuid")=="") throw new InvalidDataException("Windows was identified, but a stable hardware identity is required before push.");
                    devices.Add(device);
                }
                if(devices.Count==0) throw new InvalidDataException("Select at least one verified Windows device.");
                plan["devices"]=devices;
                var settings=server();Data.Endpoint(Data.Text(settings,"server"));
                plan["managementServer"]=Data.Text(settings,"server");plan["certificateSha256"]=Data.Text(settings,"certificateSha256");
            }
            return plan;
        }
        Dictionary<string,object> Queue(Dictionary<string,object> plan,string schedule="") {
            var job=new Dictionary<string,object>(plan);string id=Guid.NewGuid().ToString("D");
            job["id"]=id;job["state"]="queued";job["scheduleId"]=schedule;job["createdUtc"]=DateTime.UtcNow.ToString("o");
            job["completed"]=0;job["failed"]=0;job["windows"]=0;Data.Save(PathFor("jobs",id),job);return job;
        }
        object PublicJob(Dictionary<string,object> job) {
            object failures;job.TryGetValue("failures",out failures);
            return new {id=Data.Text(job,"id"),kind=Data.Text(job,"kind"),state=Data.Text(job,"state"),createdUtc=Data.Text(job,"createdUtc"),
                completed=Data.Text(job,"completed"),failed=Data.Text(job,"failed"),windows=Data.Text(job,"windows"),total=Data.Text(job,"total"),message=Data.Text(job,"message"),failures=failures,scheduleId=Data.Text(job,"scheduleId")};
        }
        internal void Route(string route,string method,Dictionary<string,object> body,Action<object,int> reply) {
            lock(gate) {
                if(route=="status" && method=="GET") {
                    reply(new {devices=Records("devices").Where(d=>Data.Text(d,"verifiedWindows")=="True").ToArray(),
                        profiles=Records("profiles").Select(p=>new {id=Data.Text(p,"id"),name=Data.Text(p,"name"),username=Data.Text(p,"username"),accountType=Data.Text(p,"accountType")}).ToArray(),
                        jobs=Records("jobs").OrderByDescending(j=>Data.Text(j,"createdUtc")).Take(40).Select(PublicJob).ToArray(),
                        schedules=Records("schedules").Select(s=>new {id=Data.Text(s,"id"),name=Data.Text(s,"name"),kind=Data.Text(s,"kind"),enabled=Data.Text(s,"enabled"),nextRunUtc=Data.Text(s,"nextRunUtc"),intervalMinutes=Data.Text(s,"intervalMinutes")}).ToArray()},200);return;
                }
                if(route=="subnets" && method=="GET") {reply(new {subnets=ConnectedSubnets()},200);return;}
                if(method!="POST" || body==null) throw new InvalidDataException("Invalid Agent deployment request.");
                if(route=="profile") {reply(Profile(body),200);return;}
                if(route=="profile-delete") {DeleteProfile(Data.Id(Data.Text(body,"id")));reply(new {ok=true},200);return;}
                if(route=="discover" || route=="push") {reply(new {job=PublicJob(Queue(Plan(route,body)))},200);return;}
                if(route=="schedule") {
                    string kind=Data.Text(body,"kind");var plan=Plan(kind,body);int minutes;
                    if(!int.TryParse(Data.Text(body,"intervalMinutes"),out minutes) || minutes<5 || minutes>525600) throw new InvalidDataException("Schedule interval must be 5 minutes–365 days.");
                    DateTimeOffset next;if(!DateTimeOffset.TryParse(Data.Text(body,"nextRunUtc"),out next) || next.UtcDateTime<=DateTime.UtcNow) throw new InvalidDataException("Choose a future first run time.");
                    string id=Guid.NewGuid().ToString("D");plan["id"]=id;plan["name"]=Data.Text(body,"name");plan["enabled"]=true;plan["nextRunUtc"]=next.UtcDateTime.ToString("o");plan["intervalMinutes"]=minutes;
                    Data.Save(PathFor("schedules",id),plan);reply(new {ok=true,id=id},200);return;
                }
                if(route=="schedule-toggle") {string id=Data.Id(Data.Text(body,"id"));var saved=Data.Read(PathFor("schedules",id));saved["enabled"]=Data.Text(body,"enabled")=="True";Data.Save(PathFor("schedules",id),saved);reply(new {ok=true},200);return;}
                if(route=="cancel") {string id=Data.Id(Data.Text(body,"id"));var saved=Data.Read(PathFor("jobs",id));if(Data.Text(saved,"state")=="queued")saved["state"]="cancelled";else saved["cancelRequested"]=true;Data.Save(PathFor("jobs",id),saved);reply(new {ok=true},200);return;}
                throw new InvalidDataException("Unknown Agent deployment action.");
            }
        }
        internal void Tick(DateTime utc) {
            lock(gate) foreach(var schedule in Records("schedules")) {
                if(Data.Text(schedule,"enabled")!="True" || DateTime.Parse(Data.Text(schedule,"nextRunUtc")).ToUniversalTime()>utc) continue;
                string id=Data.Text(schedule,"id");
                bool outstanding=Records("jobs").Any(j=>Data.Text(j,"scheduleId")==id && (Data.Text(j,"state")=="queued" || Data.Text(j,"state")=="running"));
                if(!outstanding) Queue(schedule,id);
                schedule["nextRunUtc"]=utc.AddMinutes(Convert.ToInt32(schedule["intervalMinutes"])).ToString("o");Data.Save(PathFor("schedules",id),schedule);
            }
        }
        internal void Run(CancellationToken stop) {
            lock(gate) foreach(var job in Records("jobs").Where(j=>Data.Text(j,"state")=="running")) {
                job["state"]="interrupted";job["message"]="Management service restarted; installation outcome may be unknown. No automatic retry.";Data.Save(PathFor("jobs",Data.Text(job,"id")),job);
            }
            Task worker=null;
            while(!stop.IsCancellationRequested) {
                try {
                    Tick(DateTime.UtcNow);
                    if(worker==null || worker.IsCompleted) {
                        if(worker!=null && worker.IsFaulted) Data.Log("Management","Agent deployment worker failed; inspect persisted job state.");
                        worker=Task.Run(()=>ProcessNext(stop));
                    }
                }catch(Exception e){Data.Log("Management","Agent deployment scheduler: "+e.GetType().Name);}
                stop.WaitHandle.WaitOne(1000);
            }
        }
        internal bool ProcessNext(CancellationToken stop) {
            Dictionary<string,object> job;
            lock(gate) {
                job=Records("jobs").Where(j=>Data.Text(j,"state")=="queued").OrderBy(j=>Data.Text(j,"createdUtc")).FirstOrDefault();
                if(job==null)return false;job["state"]="running";Data.Save(PathFor("jobs",Data.Text(job,"id")),job);
            }
            string jobId=Data.Text(job,"id"),kind=Data.Text(job,"kind");
            try {
                var credential=Credential(Data.Text(job,"profileId"));
                var targets=kind=="discover" ? Targets(Data.Text(job,"ranges")).Select(t=>new Dictionary<string,object>{{"target",t}}).ToList() : ((IEnumerable)job["devices"]).Cast<Dictionary<string,object>>().ToList();
                int completed=0,failed=0,windows=0;job["total"]=targets.Count;
                var failures=new List<Dictionary<string,object>>();job["failures"]=failures;
                Parallel.ForEach(targets,new ParallelOptions{MaxDegreeOfParallelism=Convert.ToInt32(job["parallelism"])},(device,loop)=> {
                    lock(gate) {if(stop.IsCancellationRequested || Data.Text(Data.Read(PathFor("jobs",jobId)),"cancelRequested")=="True"){loop.Stop();return;}}
                    Dictionary<string,object> verified=null;string message="";bool ok=false;
                    try {
                        string target=Data.Text(device,"target");
                        if(kind=="discover") {verified=transport.Probe(target,credential); if(Data.Text(verified,"verifiedWindows")!="True")throw new InvalidDataException("Windows was not verified.");ok=true;}
                        else {message=transport.Push(device,credential,setup,new Dictionary<string,object>{{"server",job["managementServer"]},{"certificateSha256",job["certificateSha256"]}},stop);verified=device;ok=true;}
                    } catch(Exception e){message=WindowsAgentPush.Failure(e);if(kind=="discover")verified=null;}
                    lock(gate) {
                        completed++;if(!ok)failed++;if(verified!=null && kind=="discover")windows++;
                        if(!ok) {
                            string reason=message;
                            var failure=failures.FirstOrDefault(f=>Data.Text(f,"message")==reason);
                            if(failure==null && failures.Count>=31) {reason="Other failures; inspect individual targets.";failure=failures.FirstOrDefault(f=>Data.Text(f,"message")==reason);}
                            if(failure==null) {failure=new Dictionary<string,object>{{"message",reason},{"count",0},{"targets",new List<string>()}};failures.Add(failure);}
                            failure["count"]=Convert.ToInt32(failure["count"])+1;
                            var examples=(List<string>)failure["targets"];if(examples.Count<3)examples.Add(Data.Text(device,"target"));
                        }
                        if(verified!=null) {
                            string target=Data.Text(verified,"target"),id=new Guid(Data.Hash(Encoding.UTF8.GetBytes(target.ToUpperInvariant())).Substring(0,32)).ToString("D");
                            verified["id"]=id;verified["verifiedUtc"]=DateTime.UtcNow.ToString("o");
                            if(kind=="push") {verified["pushStatus"]=ok ? "Service running — check Agent requests" : "Failed";verified["message"]=message;}
                            Data.Save(PathFor("devices",id),verified);
                        } else if(kind=="push") {device["pushStatus"]="Failed";device["message"]=message;Data.Save(PathFor("devices",Data.Text(device,"id")),device);}
                        // Unknown/non-Windows candidates never enter the device list.
                        var fresh=Data.Read(PathFor("jobs",jobId));job["cancelRequested"]=Data.Text(fresh,"cancelRequested")=="True";
                        job["completed"]=completed;job["failed"]=failed;job["windows"]=windows;
                        if(message!="")job["message"]=Data.Text(device,"target")+": "+message;
                        Data.Save(PathFor("jobs",jobId),job);
                    }
                });
                lock(gate) {job["state"]=stop.IsCancellationRequested || Data.Text(Data.Read(PathFor("jobs",jobId)),"cancelRequested")=="True" ? "cancelled" : "completed";Data.Save(PathFor("jobs",jobId),job);}
            } catch(Exception e) {lock(gate){job["state"]="failed";job["message"]=WindowsAgentPush.Failure(e);Data.Save(PathFor("jobs",jobId),job);}}
            return true;
        }
    }
}
