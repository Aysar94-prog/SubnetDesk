#[cfg(not(target_os = "ios"))]
use hbb_common::whoami;
use hbb_common::{
    allow_err,
    anyhow::bail,
    config::Config,
    config::{self},
    log,
    protobuf::Message as _,
    rendezvous_proto::*,
    tokio::{
        self,
        sync::{
            broadcast,
            mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender},
        },
    },
    ResultType,
};

use std::{
    collections::{BTreeMap, HashMap},
    net::{IpAddr, Ipv4Addr, SocketAddr, ToSocketAddrs, UdpSocket},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex as StdMutex, OnceLock,
    },
    time::{Duration, Instant},
};

const LAN_DISCOVERY_PORT: u16 = 21_119;
pub(crate) const LAN_DEVICE_NAME_OPTION: &str = "lan-device-name";

type Message = RendezvousMessage;
pub(crate) type LocalNetwork = (Ipv4Addr, Ipv4Addr, u8);

pub(crate) fn connectable_local_address(address: IpAddr) -> bool {
    if address.is_loopback() || address.is_unspecified() || address.is_multicast() {
        return false;
    }
    match address {
        IpAddr::V4(_) => true,
        IpAddr::V6(address) => (address.segments()[0] & 0xffc0) != 0xfe80,
    }
}

#[cfg(target_os = "windows")]
fn interface_priority(index: u32) -> Option<u8> {
    use winapi::shared::{
        ifdef::IfOperStatusUp,
        netioapi::{GetIfEntry2, MIB_IF_ROW2},
    };
    // Windows requires a zero-initialized row with its interface index set.
    let mut row: MIB_IF_ROW2 = unsafe { std::mem::zeroed() };
    row.InterfaceIndex = index;
    let status = unsafe { GetIfEntry2(&mut row) };
    if status != 0 {
        log::warn!("Could not read interface {index} status: {status}");
        return Some(1);
    }
    if row.OperStatus != IfOperStatusUp {
        return None;
    }
    Some(physical_adapter_priority(row.InterfaceAndOperStatusFlags.HardwareInterface() != 0, row.Type))
}

#[cfg(not(target_os = "windows"))]
fn interface_priority(_index: u32) -> Option<u8> {
    Some(1)
}

fn physical_adapter_priority(hardware: bool, interface_type: u32) -> u8 {
    // Windows interface types 6 and 71 are Ethernet and Wi-Fi.
    if hardware && matches!(interface_type, 6 | 71) {
        0
    } else {
        1
    }
}

#[cfg(not(target_os = "ios"))]
pub(crate) struct LocalAddress {
    pub address: IpAddr,
    pub adapter: String,
}

#[cfg(not(target_os = "ios"))]
pub(crate) fn local_connectable_address_details() -> Vec<LocalAddress> {
    let mut addresses = BTreeMap::new();
    for interface in default_net::get_interfaces() {
        let Some(priority) = interface_priority(interface.index) else { continue };
        let adapter = interface.friendly_name.unwrap_or(interface.name);
        for address in interface.ipv4.into_iter().map(|network| IpAddr::V4(network.addr))
            .chain(interface.ipv6.into_iter().map(|network| IpAddr::V6(network.addr))) {
            if connectable_local_address(address) {
                addresses.entry(address)
                    .and_modify(|existing: &mut (u8, String)| {
                        if priority < existing.0 { *existing = (priority, adapter.clone()); }
                    })
                    .or_insert_with(|| (priority, adapter.clone()));
            }
        }
    }
    if let Some(address) = get_ipaddr_by_peer((Ipv4Addr::new(192, 0, 2, 1), 9)) {
        if connectable_local_address(address) {
            addresses.entry(address).or_insert_with(|| (1, String::new()));
        }
    }
    let mut ordered = addresses.into_iter().map(|(address, (priority, adapter))| (priority, address, adapter)).collect::<Vec<_>>();
    ordered.sort_unstable();
    ordered.into_iter().map(|(_, address, adapter)| LocalAddress { address, adapter }).collect()
}

#[cfg(not(target_os = "ios"))]
pub(crate) fn local_connectable_addresses() -> Vec<IpAddr> {
    local_connectable_address_details().into_iter().map(|item| item.address).collect()
}

#[cfg(target_os = "ios")]
pub(crate) fn local_connectable_addresses() -> Vec<IpAddr> {
    Vec::new()
}

fn directed_broadcast(address: Ipv4Addr, netmask: Ipv4Addr) -> Ipv4Addr {
    Ipv4Addr::from(u32::from(address) | !u32::from(netmask))
}

pub(crate) fn sanitize_lan_device_name(value: &str) -> String {
    value
        .trim()
        .chars()
        .filter(|character| !character.is_control())
        .take(64)
        .collect()
}

fn select_device_display_name(custom_name: &str, system_hostname: &str) -> String {
    let custom_name = sanitize_lan_device_name(custom_name);
    if !custom_name.is_empty() {
        return custom_name;
    }
    let system_hostname = sanitize_lan_device_name(system_hostname);
    if system_hostname.is_empty() {
        "SubnetDesk".to_owned()
    } else {
        system_hostname
    }
}

pub(crate) fn device_display_name() -> String {
    select_device_display_name(
        &Config::get_option(LAN_DEVICE_NAME_OPTION),
        &crate::hostname(),
    )
}

#[cfg(not(target_os = "ios"))]
pub(super) fn start_listening() -> ResultType<()> {
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    std::thread::spawn(|| {
        if let Err(err) = crate::lan_mdns::start_publisher() {
            log::warn!("mDNS publisher stopped: {err}");
        }
    });

    let addr = SocketAddr::from(([0, 0, 0, 0], get_broadcast_port()));
    let socket = std::net::UdpSocket::bind(addr)?;
    socket.set_read_timeout(Some(std::time::Duration::from_millis(1000)))?;
    log::info!("lan discovery listener started");
    loop {
        let mut buf = [0; 2048];
        if let Ok((len, addr)) = socket.recv_from(&mut buf) {
            if let Ok(msg_in) = Message::parse_from_bytes(&buf[0..len]) {
                match msg_in.union {
                    Some(rendezvous_message::Union::PeerDiscovery(p)) => {
                        if p.cmd == "ping"
                            && Config::get_option("lan-discovery-enabled") != "N"
                            && crate::lan_server::LanServer::is_discoverable()
                            && crate::lan_server::source_allowed(addr.ip())
                        {
                            let fingerprint =
                                crate::lan_protocol::fingerprint(&Config::get_key_pair().1);
                            if p.id == fingerprint {
                                continue;
                            }
                            if let Some(self_addr) = get_ipaddr_by_peer(&addr) {
                                let mut msg_out = Message::new();
                                let peer = PeerDiscovery {
                                    cmd: "pong".to_owned(),
                                    mac: get_mac(&self_addr),
                                    id: fingerprint.clone(),
                                    hostname: device_display_name(),
                                    username: String::new(),
                                    platform: whoami::platform().to_string(),
                                    misc: serde_json::json!({
                                        "protocol_version": hbb_common::lan::PROTOCOL_VERSION,
                                        "port": Config::get_option("lan-listen-port")
                                            .parse::<u16>()
                                            .ok()
                                            .filter(|port| *port > 0)
                                            .unwrap_or(hbb_common::lan::DEFAULT_PORT),
                                        "fingerprint": fingerprint,
                                    })
                                    .to_string(),
                                    ..Default::default()
                                };
                                msg_out.set_peer_discovery(peer);
                                socket.send_to(&msg_out.write_to_bytes()?, addr).ok();
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

/// The normal collection window never ends before this, even if no pongs
/// arrive at all, so a quiet LAN still gets a fair chance to respond.
const DISCOVERY_MIN_COLLECTION: Duration = Duration::from_secs(3);
/// After the minimum window, collection ends once this long passes with no
/// *valid* pong (pings and malformed/nonmatching packets don't reset this).
const DISCOVERY_QUIET_PERIOD: Duration = Duration::from_millis(500);
/// Collection always stops here, even if valid pongs keep arriving, so
/// continuous LAN traffic can't turn every scan into a timeout. A scan that
/// stops for this reason is reported as successful-with-limited-coverage
/// rather than failed, since the data collected so far is still usable.
const DISCOVERY_HARD_CAP: Duration = Duration::from_secs(6);
const DISCOVERY_SETUP_BUDGET: Duration = Duration::from_secs(10);
/// Collection and reconciliation budget after transport setup. The gap
/// above `DISCOVERY_HARD_CAP` allows the workers to finish and results to be
/// committed.
const DISCOVERY_OVERALL_BUDGET: Duration = Duration::from_secs(8);

/// Outcome of one discovery scan, shared with every caller that joined it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum DiscoveryOutcome {
    Success,
    /// Collection was cut off (hard cap, or a transport didn't start) before
    /// every enabled transport completed its normal window. Positive
    /// observations collected so far are still committed and usable; a
    /// limited scan must never be allowed to apply negative evidence.
    LimitedCoverage,
    /// The collection budget elapsed before final reconciliation. Earlier
    /// positive observations may already have been published.
    Timeout,
    /// No discovery transport could even start.
    TransportFailure,
}

/// Monotonically increasing scan identifier, used so the cross-process
/// `_lan_peers` merge can tell an older, still-in-flight scan's result apart
/// from the newest one and refuse to let it apply negative evidence.
static SCAN_GENERATION: AtomicU64 = AtomicU64::new(0);

/// Holds the in-flight scan's result channel, if any, so concurrent callers
/// in this process join one scan instead of each starting their own. `None`
/// when no scan is running.
fn discovery_coordinator() -> &'static StdMutex<Option<broadcast::Sender<DiscoveryOutcome>>> {
    static COORDINATOR: OnceLock<StdMutex<Option<broadcast::Sender<DiscoveryOutcome>>>> =
        OnceLock::new();
    COORDINATOR.get_or_init(|| StdMutex::new(None))
}

/// Runs a LAN discovery scan, or joins one already running in this process.
/// A caller may wrap this in its own timeout without affecting the scan
/// itself or other joined callers — only this caller's own wait ends early.
pub(crate) async fn discover_coordinated() -> DiscoveryOutcome {
    if config::is_incoming_only() {
        return DiscoveryOutcome::Timeout;
    }
    crate::discovery_coordinator::run(discovery_coordinator(), run_discovery_scan)
        .await.unwrap_or(DiscoveryOutcome::TransportFailure)
}

async fn run_discovery_scan() -> DiscoveryOutcome {
    if config::is_incoming_only() {
        return DiscoveryOutcome::Timeout;
    }
    let generation = SCAN_GENERATION.fetch_add(1, Ordering::Relaxed) + 1;
    let hit_hard_cap = Arc::new(AtomicBool::new(false));

    let (tx, rx) = unbounded_channel::<_>();
    let mut udp_ok = false;
    let mut local_networks = Vec::new();
    let mut udp_handles = Vec::new();
    let query = match tokio::time::timeout(
        DISCOVERY_SETUP_BUDGET,
        tokio::task::spawn_blocking(send_query),
    ).await {
        Ok(Ok(result)) => result,
        Ok(Err(err)) => Err(hbb_common::anyhow::anyhow!("LAN discovery setup failed: {err}")),
        Err(_) => Err(hbb_common::anyhow::anyhow!("LAN discovery setup timed out")),
    };
    // Interface enumeration and broadcast setup can take several seconds on
    // multi-adapter Windows hosts. Give responses a full collection window.
    let scan_start = Instant::now();
    match query {
        Ok((sockets, networks, fingerprint)) => {
            local_networks = networks;
            udp_handles = spawn_wait_responses(sockets, tx.clone(), scan_start, hit_hard_cap.clone(), &fingerprint);
            udp_ok = true;
        }
        Err(err) => log::warn!("UDP LAN discovery unavailable: {err}"),
    }
    #[cfg(not(target_os = "ios"))]
    let mdns_ok = match crate::lan_mdns::spawn_browse(tx.clone(), local_networks.clone()) {
        Ok(()) => true,
        Err(err) => {
            log::warn!("mDNS discovery unavailable: {err}");
            false
        }
    };
    #[cfg(target_os = "ios")]
    let mdns_ok = true; // Not an enabled transport on this platform.

    drop(tx);
    if !udp_ok && !mdns_ok {
        return DiscoveryOutcome::TransportFailure;
    }

    // Transport setup is blocking and happens before collection. Do not
    // consume the response budget while discovering local interfaces.
    let deadline = Instant::now() + DISCOVERY_OVERALL_BUDGET;
    let remaining = deadline.saturating_duration_since(Instant::now());
    let processing = handle_received_peers(rx, generation, udp_ok, mdns_ok, hit_hard_cap.clone(), &local_networks);
    let processing_result = tokio::time::timeout(remaining, processing).await;

    // Join the raw UDP worker threads (bounded by the hard cap, so this
    // returns promptly) before releasing the coordinator slot, so a new scan
    // never starts while a prior one's workers might still be writing.
    if !udp_handles.is_empty() {
        let _ = tokio::task::spawn_blocking(move || {
            for handle in udp_handles {
                let _ = handle.join();
            }
        })
        .await;
    }

    match processing_result {
        Ok(Ok(())) => {
            if hit_hard_cap.load(Ordering::Relaxed) || !udp_ok || !mdns_ok {
                DiscoveryOutcome::LimitedCoverage
            } else {
                DiscoveryOutcome::Success
            }
        }
        Ok(Err(err)) => {
            log::warn!("LAN discovery persistence failed: {err}");
            DiscoveryOutcome::Timeout
        }
        Err(_) => {
            log::warn!("LAN discovery scan exceeded its overall budget");
            DiscoveryOutcome::Timeout
        }
    }
}

pub(crate) async fn discover_async() -> ResultType<()> {
    match discover_coordinated().await {
        DiscoveryOutcome::TransportFailure => bail!("No LAN discovery transport is available"),
        outcome => {
            log::info!("discover ping done: {outcome:?}");
            Ok(())
        }
    }
}

#[tokio::main(flavor = "current_thread")]
pub async fn discover() -> ResultType<()> {
    if hbb_common::config::is_incoming_only() {
        return Ok(());
    }
    discover_async().await
}

/// Distinguishes a connection whose expected identity comes from verified
/// evidence (a prior successful, fingerprint-recorded connection) from one
/// resolved only from unauthenticated LAN advertisements (UDP/mDNS discovery
/// cache) or typed manually. Only `SavedDevice` may be trusted or logged into
/// automatically. A changed saved identity must pass the explicit fingerprint
/// confirmation step.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ConnectionIntent {
    SavedDevice,
    ManualEndpoint,
}

pub(crate) fn connection_candidates(
    endpoint: &str,
) -> (ConnectionIntent, Option<String>, Vec<String>) {
    let recent = config::LocalConfig::get_recent_lan_endpoints();
    let favorites = config::LocalConfig::get_favorites();
    let peers = config::LanPeers::load().peers;
    connection_candidates_from(endpoint, &recent, &favorites, &peers)
}

/// Resolves a saved device's current best-known endpoint from its verified
/// fingerprint, for the tray/CLI `--connect-saved` entry point. Prefers the
/// freshest verified endpoint (a recent successful connection); falls back
/// to the canonical favorite's last-known endpoint. Returns `None` for an
/// unrecognized or malformed fingerprint — callers must treat that as a
/// rejection, never fall back to treating the fingerprint as an endpoint.
pub(crate) fn resolve_saved_endpoint(fingerprint: &str) -> Option<String> {
    let fingerprint = fingerprint.to_ascii_lowercase();
    if fingerprint.len() != 64 || !fingerprint.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return None;
    }
    if let Some(endpoint) = config::LocalConfig::get_recent_lan_endpoints()
        .into_iter()
        .find(|recent| recent.fingerprint.eq_ignore_ascii_case(&fingerprint))
        .map(|recent| recent.endpoint)
    {
        return Some(endpoint);
    }
    config::LocalConfig::get_favorites()
        .into_iter()
        .find(|favorite| favorite.fingerprint.eq_ignore_ascii_case(&fingerprint))
        .map(|favorite| favorite.endpoint)
        .filter(|endpoint| !endpoint.is_empty())
}

fn connection_candidates_from(
    endpoint: &str,
    recent: &[config::RecentLanEndpoint],
    favorites: &[config::FavoriteDevice],
    peers: &[config::DiscoveryPeer],
) -> (ConnectionIntent, Option<String>, Vec<String>) {
    let Ok(requested) = hbb_common::lan::Endpoint::parse(endpoint) else {
        return (ConnectionIntent::ManualEndpoint, None, vec![endpoint.to_owned()]);
    };
    let requested = requested.authority().to_owned();
    // Only a fingerprint recorded from a prior verified connection (`recent`)
    // or a canonical favorite (itself only ever assigned from unambiguous
    // verified evidence, see `LocalConfig::migrate_legacy_favorites_if_needed`
    // and `update_favorite_endpoint_for_fingerprint`) proves identity. The
    // discovery cache (`peers`) merely reflects unauthenticated UDP/mDNS
    // advertisements and must never grant saved intent, since another device
    // can claim the same IP or fingerprint.
    let verified_fingerprint = recent
        .iter()
        .find(|recent| recent.endpoint == requested)
        .map(|recent| recent.fingerprint.to_ascii_lowercase())
        .or_else(|| {
            favorites
                .iter()
                .find(|favorite| favorite.endpoint == requested && !favorite.fingerprint.is_empty())
                .map(|favorite| favorite.fingerprint.to_ascii_lowercase())
        });

    let intent = if verified_fingerprint.is_some() {
        ConnectionIntent::SavedDevice
    } else {
        ConnectionIntent::ManualEndpoint
    };

    let mut fingerprint = verified_fingerprint;
    if fingerprint.is_none() {
        fingerprint = peers.iter().find_map(|peer| {
            if peer.endpoint == requested {
                return Some(peer.fingerprint.to_ascii_lowercase());
            }
            let requested_endpoint = hbb_common::lan::Endpoint::parse(&requested).ok()?;
            if peer.ip_mac.contains_key(requested_endpoint.host()) {
                Some(peer.fingerprint.to_ascii_lowercase())
            } else {
                None
            }
        });
    }
    let fingerprint = fingerprint
        .filter(|value| value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit()));

    let mut candidates = Vec::new();
    push_unique(&mut candidates, requested);
    if let Some(fingerprint) = fingerprint.as_ref() {
        for recent in recent
            .iter()
            .filter(|recent| recent.fingerprint.eq_ignore_ascii_case(fingerprint))
        {
            push_unique(&mut candidates, recent.endpoint.clone());
        }
        for peer in peers
            .iter()
            .filter(|peer| peer.fingerprint.eq_ignore_ascii_case(fingerprint))
        {
            push_unique(&mut candidates, peer.endpoint.clone());
            let port = hbb_common::lan::Endpoint::parse(&peer.endpoint)
                .map(|endpoint| endpoint.port())
                .unwrap_or(hbb_common::lan::DEFAULT_PORT);
            let mut addresses = peer.ip_mac.keys().collect::<Vec<_>>();
            addresses.sort();
            for address in addresses {
                if let Ok(address) = address.parse::<IpAddr>() {
                    let endpoint = match address {
                        IpAddr::V4(address) => format!("{address}:{port}"),
                        IpAddr::V6(address) => format!("[{address}]:{port}"),
                    };
                    push_unique(&mut candidates, endpoint);
                }
            }
        }
    }
    (intent, fingerprint, candidates)
}

fn push_unique(values: &mut Vec<String>, value: String) {
    if !value.is_empty() && !values.contains(&value) {
        values.push(value);
    }
}

pub fn send_wol(id: String) {
    let interfaces = default_net::get_interfaces();
    for peer in &config::LanPeers::load().peers {
        if peer.id == id {
            for (_, mac) in peer.ip_mac.iter() {
                if let Ok(mac_addr) = mac.parse() {
                    for interface in &interfaces {
                        for ipv4 in &interface.ipv4 {
                            // remove below mask check to avoid unexpected bug
                            // if (u32::from(ipv4.addr) & u32::from(ipv4.netmask)) == (u32::from(peer_ip) & u32::from(ipv4.netmask))
                            log::info!("Send wol to {mac_addr} of {}", ipv4.addr);
                            allow_err!(wol::send_wol(mac_addr, None, Some(IpAddr::V4(ipv4.addr))));
                        }
                    }
                }
            }
            break;
        }
    }
}

#[inline]
fn get_broadcast_port() -> u16 {
    LAN_DISCOVERY_PORT
}

fn get_mac(_ip: &IpAddr) -> String {
    #[cfg(not(target_os = "ios"))]
    if let Ok(mac) = get_mac_by_ip(_ip) {
        mac.to_string()
    } else {
        "".to_owned()
    }
    #[cfg(target_os = "ios")]
    "".to_owned()
}

#[cfg(not(target_os = "ios"))]
fn get_mac_by_ip(ip: &IpAddr) -> ResultType<String> {
    for interface in default_net::get_interfaces() {
        match ip {
            IpAddr::V4(local_ipv4) => {
                if interface.ipv4.iter().any(|x| x.addr == *local_ipv4) {
                    if let Some(mac_addr) = interface.mac_addr {
                        return Ok(mac_addr.address());
                    }
                }
            }
            IpAddr::V6(local_ipv6) => {
                if interface.ipv6.iter().any(|x| x.addr == *local_ipv6) {
                    if let Some(mac_addr) = interface.mac_addr {
                        return Ok(mac_addr.address());
                    }
                }
            }
        }
    }
    bail!("No interface found for ip: {:?}", ip);
}

// Mainly from https://github.com/shellrow/default-net/blob/cf7ca24e7e6e8e566ed32346c9cfddab3f47e2d6/src/interface/shared.rs#L4
fn get_ipaddr_by_peer<A: ToSocketAddrs>(peer: A) -> Option<IpAddr> {
    let socket = match UdpSocket::bind("0.0.0.0:0") {
        Ok(s) => s,
        Err(_) => return None,
    };

    match socket.connect(peer) {
        Ok(()) => (),
        Err(_) => return None,
    };

    match socket.local_addr() {
        Ok(addr) => return Some(addr.ip()),
        Err(_) => return None,
    };
}

fn create_broadcast_sockets() -> (Vec<(UdpSocket, Ipv4Addr)>, Vec<LocalNetwork>) {
    let mut ipv4s = Vec::new();
    let mut local_networks = Vec::new();
    // TODO: maybe we should use a better way to get ipv4 addresses.
    // But currently, it's ok to use `[Ipv4Addr::UNSPECIFIED]` for discovery.
    // `default_net::get_interfaces()` causes undefined symbols error when `flutter build` on iOS simulator x86_64
    #[cfg(not(any(target_os = "ios")))]
    for interface in default_net::get_interfaces() {
        let Some(priority) = interface_priority(interface.index) else { continue };
        for ipv4 in &interface.ipv4 {
            if connectable_local_address(IpAddr::V4(ipv4.addr)) {
                ipv4s.push((ipv4.addr, directed_broadcast(ipv4.addr, ipv4.netmask)));
                local_networks.push((ipv4.addr, ipv4.netmask, priority));
            }
        }
    }
    #[cfg(not(target_os = "ios"))]
    if let Some(IpAddr::V4(address)) = get_ipaddr_by_peer((Ipv4Addr::new(192, 0, 2, 1), 9)) {
        if connectable_local_address(IpAddr::V4(address))
            && !ipv4s.iter().any(|(candidate, _)| *candidate == address)
        {
            ipv4s.push((address, Ipv4Addr::BROADCAST));
        }
    }
    ipv4s.push((Ipv4Addr::UNSPECIFIED, Ipv4Addr::BROADCAST)); // for robustness
    let mut sockets = Vec::new();
    for (v4_addr, broadcast) in ipv4s {
        // removing v4_addr.is_private() check, https://github.com/rustdesk/rustdesk/issues/4663
        if let Ok(s) = UdpSocket::bind(SocketAddr::from((v4_addr, 0))) {
            if s.set_broadcast(true).is_ok() {
                sockets.push((s, broadcast));
            }
        }
    }
    (sockets, local_networks)
}

fn send_query() -> ResultType<(Vec<UdpSocket>, Vec<LocalNetwork>, String)> {
    let (sockets, local_networks) = create_broadcast_sockets();
    if sockets.is_empty() {
        bail!("Found no bindable ipv4 addresses");
    }

    let mut msg_out = Message::new();
    let id = crate::lan_protocol::fingerprint(&Config::get_key_pair().1);
    let peer = PeerDiscovery {
        cmd: "ping".to_owned(),
        id: id.clone(),
        ..Default::default()
    };
    msg_out.set_peer_discovery(peer);
    let out = msg_out.write_to_bytes()?;
    let maddr = SocketAddr::from(([255, 255, 255, 255], get_broadcast_port()));
    for (socket, broadcast) in &sockets {
        let directed = SocketAddr::from((*broadcast, get_broadcast_port()));
        allow_err!(socket.send_to(&out, directed));
        if *broadcast != Ipv4Addr::BROADCAST {
            allow_err!(socket.send_to(&out, maddr));
        }
    }
    log::info!("discover ping sent");
    Ok((sockets.into_iter().map(|(socket, _)| socket).collect(), local_networks, id))
}

fn wait_response(
    socket: UdpSocket,
    scan_start: Instant,
    hit_hard_cap: Arc<AtomicBool>,
    tx: UnboundedSender<config::DiscoveryPeer>,
    local_fingerprint: &str,
) -> ResultType<()> {
    // A valid pong resets the quiet timer; pings and malformed/nonmatching
    // packets must not, or continuous LAN traffic could keep a scan open
    // indefinitely. `None` means "no valid pong yet", so the quiet period is
    // measured from `scan_start` until the first one arrives.
    let mut last_valid_pong: Option<Instant> = None;

    socket.set_read_timeout(Some(Duration::from_millis(10)))?;
    loop {
        let mut buf = [0; 2048];
        if let Ok((len, addr)) = socket.recv_from(&mut buf) {
            if let Ok(msg_in) = Message::parse_from_bytes(&buf[0..len]) {
                match msg_in.union {
                    Some(rendezvous_message::Union::PeerDiscovery(p)) => {
                        if p.cmd == "pong" {
                            if p.id.len() != 64
                                || !p.id.bytes().all(|value| value.is_ascii_hexdigit())
                            {
                                log::warn!(
                                    "Ignoring LAN discovery response from {} with invalid fingerprint",
                                    addr
                                );
                            } else if !p.id.eq_ignore_ascii_case(local_fingerprint) {
                                last_valid_pong = Some(Instant::now());

                                let misc = serde_json::from_str::<serde_json::Value>(&p.misc)
                                    .unwrap_or_default();
                                let port = misc
                                    .get("port")
                                    .and_then(|value| value.as_u64())
                                    .and_then(|value| u16::try_from(value).ok())
                                    .filter(|value| *value > 0)
                                    .unwrap_or(hbb_common::lan::DEFAULT_PORT);
                                let endpoint = if addr.ip().is_ipv6() {
                                    format!("[{}]:{}", addr.ip(), port)
                                } else {
                                    format!("{}:{}", addr.ip(), port)
                                };

                                allow_err!(tx.send(config::DiscoveryPeer {
                                    id: endpoint.clone(),
                                    endpoint,
                                    fingerprint: p.id,
                                    ip_mac: HashMap::from([
                                        (addr.ip().to_string(), p.mac,)
                                    ]),
                                    username: p.username,
                                    hostname: p.hostname,
                                    platform: p.platform,
                                    online: true,
                                    ..Default::default()
                                }));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        let elapsed = scan_start.elapsed();
        if elapsed >= DISCOVERY_HARD_CAP {
            hit_hard_cap.store(true, Ordering::Relaxed);
            break;
        }
        let quiet_since = last_valid_pong.unwrap_or(scan_start);
        if elapsed >= DISCOVERY_MIN_COLLECTION && quiet_since.elapsed() >= DISCOVERY_QUIET_PERIOD {
            break;
        }
    }
    Ok(())
}

fn spawn_wait_responses(
    sockets: Vec<UdpSocket>,
    tx: UnboundedSender<config::DiscoveryPeer>,
    scan_start: Instant,
    hit_hard_cap: Arc<AtomicBool>,
    local_fingerprint: &str,
) -> Vec<std::thread::JoinHandle<()>> {
    let local_fingerprint: Arc<str> = Arc::from(local_fingerprint);
    sockets
        .into_iter()
        .map(|socket| {
            let tx_clone = tx.clone();
            let hit_hard_cap = hit_hard_cap.clone();
            let local_fingerprint = local_fingerprint.clone();
            std::thread::spawn(move || {
                allow_err!(wait_response(socket, scan_start, hit_hard_cap, tx_clone, &local_fingerprint));
            })
        })
        .collect()
}

async fn handle_received_peers(
    mut rx: UnboundedReceiver<config::DiscoveryPeer>,
    generation: u64,
    udp_ok: bool,
    mdns_ok: bool,
    hit_hard_cap: Arc<AtomicBool>,
    local_networks: &[LocalNetwork],
) -> ResultType<()> {
    let mut observed: Vec<config::DiscoveryPeer> = Vec::new();
    let mut last_publish_time: Option<Instant> = None;
    loop {
        tokio::select! {
            data = rx.recv() => match data {
                Some(mut peer) => {
                    if let Some(pos) = observed.iter().position(|x| x.is_same_peer(&peer)) {
                        let peer1 = observed.remove(pos);
                        if observed_endpoint_priority(&peer1.endpoint, local_networks)
                            < observed_endpoint_priority(&peer.endpoint, local_networks)
                        {
                            peer.id = peer1.id.clone();
                            peer.endpoint = peer1.endpoint.clone();
                        }
                        if let Ok(endpoint) = hbb_common::lan::Endpoint::parse(&peer1.endpoint) {
                            if endpoint.host().parse::<IpAddr>().is_ok() {
                                peer.ip_mac
                                    .entry(endpoint.host().to_owned())
                                    .or_default();
                            }
                        }
                        peer.ip_mac.extend(peer1.ip_mac);
                    }
                    observed.insert(0, peer);
                    // Interim publish for UI responsiveness while the scan is
                    // still running: always `full_coverage = false` so a
                    // still-in-progress batch can never apply negative
                    // evidence or an Offline transition, only add positive
                    // observations.
                    if last_publish_time.map(|t| t.elapsed().as_millis() > 300).unwrap_or(true) {
                        publish_observed(&observed, generation, false);
                        last_publish_time = Some(Instant::now());
                    }
                }
                None => break,
            }
        }
    }

    // The channel closed because every transport finished (or never
    // started); this is the authoritative, final result for this
    // generation. It only counts as full coverage if every transport that
    // was expected to run actually started and none of them was cut off by
    // the hard cap — otherwise a silent device must stay Unknown, not be
    // allowed to accumulate a miss toward Offline.
    let full_coverage = udp_ok && mdns_ok && !hit_hard_cap.load(Ordering::Relaxed);
    publish_observed(&observed, generation, full_coverage);
    Ok(())
}

fn observed_endpoint_priority(endpoint: &str, local_networks: &[LocalNetwork]) -> u8 {
    #[cfg(not(target_os = "ios"))]
    if let Ok(endpoint) = hbb_common::lan::Endpoint::parse(endpoint) {
        if let Ok(address) = endpoint.host().parse::<IpAddr>() {
            return crate::lan_mdns::address_priority(address, local_networks);
        }
    }
    #[cfg(target_os = "ios")]
    let _ = (endpoint, local_networks);
    u8::MAX
}

fn publish_observed(observed: &[config::DiscoveryPeer], generation: u64, full_coverage: bool) {
    let now_ms = hbb_common::get_time();
    match config::LanPeers::merge_scan(generation, full_coverage, observed.to_owned(), now_ms) {
        Ok(_) => {
            #[cfg(feature = "flutter")]
            crate::flutter_ffi::main_load_lan_peers();
        }
        Err(err) => log::error!("Failed to merge discovered LAN peers: {err}"),
    }
}

/// Maximum number of addresses a single manual range/CIDR scan will probe, to
/// bound worst-case packet volume and scan duration from a mistyped range
/// (e.g. a /8 instead of a /24).
const MAX_UNICAST_PROBE_TARGETS: usize = 1024;

/// Parses a manual scan target into the list of addresses to probe. Accepts:
/// - a single IP ("10.96.160.130")
/// - a CIDR block ("10.96.160.0/24")
/// - a dash range sharing the first three octets ("10.96.160.1-254" or
///   "10.96.160.1-10.96.160.254")
pub(crate) fn parse_ip_range(input: &str) -> ResultType<Vec<IpAddr>> {
    let input = input.trim();
    if input.is_empty() {
        bail!("Empty range");
    }
    if let Some((base, bits)) = input.split_once('/') {
        let base: Ipv4Addr = base.trim().parse()?;
        let bits: u32 = bits.trim().parse()?;
        if bits > 32 || bits < 16 {
            bail!("CIDR prefix must be between 16 and 32");
        }
        let mask = if bits == 0 { 0 } else { u32::MAX << (32 - bits) };
        let network = u32::from(base) & mask;
        let host_bits = 32 - bits;
        let count = 1u64 << host_bits;
        let mut addresses = Vec::new();
        for offset in 0..count {
            if addresses.len() >= MAX_UNICAST_PROBE_TARGETS {
                break;
            }
            addresses.push(IpAddr::V4(Ipv4Addr::from(network + offset as u32)));
        }
        return Ok(addresses);
    }
    if let Some((start, end)) = input.split_once('-') {
        let start: Ipv4Addr = start.trim().parse()?;
        let end = end.trim();
        let end: Ipv4Addr = if end.contains('.') {
            end.parse()?
        } else {
            let last: u8 = end.parse()?;
            let octets = start.octets();
            Ipv4Addr::new(octets[0], octets[1], octets[2], last)
        };
        let start_u32 = u32::from(start);
        let end_u32 = u32::from(end);
        if end_u32 < start_u32 {
            bail!("Range end must not be before range start");
        }
        let mut addresses = Vec::new();
        for value in start_u32..=end_u32 {
            if addresses.len() >= MAX_UNICAST_PROBE_TARGETS {
                break;
            }
            addresses.push(IpAddr::V4(Ipv4Addr::from(value)));
        }
        return Ok(addresses);
    }
    Ok(vec![input.parse::<IpAddr>()?])
}

/// Sends a unicast discovery ping directly to each address in `targets` on
/// the LAN discovery port and collects any pongs, independent of UDP
/// broadcast/mDNS. This is how a cross-subnet device (reachable by routed
/// unicast but never seeing our broadcast/multicast traffic) can still be
/// found or have its reachability refreshed: the discovery listener
/// (`start_listening`) already answers any ping addressed to it, broadcast or
/// not.
///
/// Runs synchronously on the calling thread; callers that must not block
/// (e.g. an FFI entry point) should spawn this onto a background thread.
fn probe_unicast(targets: &[IpAddr]) -> Vec<config::DiscoveryPeer> {
    if targets.is_empty() {
        return Vec::new();
    }
    let Ok(socket) = UdpSocket::bind(SocketAddr::from(([0, 0, 0, 0], 0))) else {
        log::warn!("Unicast LAN probe: failed to bind socket");
        return Vec::new();
    };

    let mut msg_out = Message::new();
    let id = crate::lan_protocol::fingerprint(&Config::get_key_pair().1);
    let peer = PeerDiscovery {
        cmd: "ping".to_owned(),
        id: id.clone(),
        ..Default::default()
    };
    msg_out.set_peer_discovery(peer);
    let Ok(out) = msg_out.write_to_bytes() else {
        return Vec::new();
    };
    for target in targets {
        allow_err!(socket.send_to(&out, SocketAddr::from((*target, get_broadcast_port()))));
    }
    log::info!("unicast discover ping sent to {} target(s)", targets.len());

    let (tx, mut rx) = unbounded_channel::<config::DiscoveryPeer>();
    let scan_start = Instant::now();
    let hit_hard_cap = Arc::new(AtomicBool::new(false));
    allow_err!(wait_response(socket, scan_start, hit_hard_cap, tx, &id));

    let mut observed = Vec::new();
    while let Ok(peer) = rx.try_recv() {
        observed.push(peer);
    }
    observed
}

/// Probes a set of IPv4 addresses by unicast and merges whatever responds
/// into the shared LAN peers cache, refreshing the UI. `full_coverage` is
/// always `false`: a partial, targeted probe must only ever add positive
/// observations, never mark an unanswering address Offline (it may simply be
/// outside this probe's target list, not actually gone).
pub(crate) fn probe_ips_async(targets: Vec<IpAddr>) {
    if targets.is_empty() || config::is_incoming_only() {
        return;
    }
    std::thread::spawn(move || {
        let observed = probe_unicast(&targets);
        let generation = SCAN_GENERATION.fetch_add(1, Ordering::Relaxed) + 1;
        publish_observed(&observed, generation, false);
    });
}

/// Entry point for a user-initiated manual IP range scan, bypassing
/// broadcast/mDNS entirely. `range` is parsed by [`parse_ip_range`].
pub(crate) fn discover_range_async(range: String) -> ResultType<usize> {
    if config::is_incoming_only() {
        return Ok(0);
    }
    let targets = parse_ip_range(&range)?;
    let count = targets.len();
    probe_ips_async(targets);
    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn custom_device_name_is_trimmed_filtered_and_bounded() {
        assert_eq!(sanitize_lan_device_name("  Meeting Room  "), "Meeting Room");
        assert_eq!(sanitize_lan_device_name("会议\n室"), "会议室");
        assert_eq!(sanitize_lan_device_name(&"a".repeat(80)).len(), 64);
    }

    #[test]
    fn custom_device_name_overrides_hostname_and_empty_value_restores_it() {
        assert_eq!(
            select_device_display_name("Studio Mac", "host.local"),
            "Studio Mac"
        );
        assert_eq!(select_device_display_name("", "host.local"), "host.local");
        assert_eq!(select_device_display_name("", "\n"), "SubnetDesk");
    }

    #[test]
    fn connection_candidates_keep_vpn_endpoint_and_add_discovered_addresses() {
        let fingerprint = "a".repeat(64);
        let recent = config::RecentLanEndpoint {
            endpoint: "10.8.0.15:21118".to_owned(),
            fingerprint: fingerprint.clone(),
            ..Default::default()
        };
        let peers = vec![config::DiscoveryPeer {
            endpoint: "192.168.1.99:21118".to_owned(),
            fingerprint: fingerprint.clone(),
            ip_mac: HashMap::from([
                ("192.168.1.99".to_owned(), String::new()),
                ("10.8.0.15".to_owned(), String::new()),
            ]),
            ..Default::default()
        }];

        let (intent, resolved_fingerprint, candidates) =
            connection_candidates_from(&recent.endpoint, &[recent.clone()], &[], &peers);

        assert_eq!(intent, ConnectionIntent::SavedDevice);
        assert_eq!(resolved_fingerprint, Some(fingerprint));
        assert_eq!(candidates[0], "10.8.0.15:21118");
        assert!(candidates.contains(&"192.168.1.99:21118".to_owned()));
        assert_eq!(
            candidates
                .iter()
                .filter(|endpoint| endpoint.as_str() == "10.8.0.15:21118")
                .count(),
            1
        );
    }

    #[test]
    fn connection_candidates_can_identify_device_from_discovery_cache() {
        let fingerprint = "b".repeat(64);
        let peers = vec![config::DiscoveryPeer {
            endpoint: "192.168.1.20:21118".to_owned(),
            fingerprint: fingerprint.clone(),
            ip_mac: HashMap::from([("10.9.0.20".to_owned(), String::new())]),
            ..Default::default()
        }];

        let (intent, resolved_fingerprint, candidates) =
            connection_candidates_from("10.9.0.20:21118", &[], &[], &peers);

        assert_eq!(intent, ConnectionIntent::ManualEndpoint);
        assert_eq!(resolved_fingerprint, Some(fingerprint));
        assert_eq!(candidates[0], "10.9.0.20:21118");
        assert!(candidates.contains(&"192.168.1.20:21118".to_owned()));
    }

    #[test]
    fn connection_candidates_mark_saved_device_only_from_verified_recent_history() {
        let fingerprint = "c".repeat(64);
        let recent = config::RecentLanEndpoint {
            endpoint: "192.168.1.50:21118".to_owned(),
            fingerprint: fingerprint.clone(),
            ..Default::default()
        };

        let (intent, resolved_fingerprint, _candidates) =
            connection_candidates_from(&recent.endpoint.clone(), &[recent], &[], &[]);

        assert_eq!(intent, ConnectionIntent::SavedDevice);
        assert_eq!(resolved_fingerprint, Some(fingerprint));
    }

    #[test]
    fn connection_candidates_mark_saved_device_from_canonical_favorite_without_recent_history() {
        let fingerprint = "d".repeat(64);
        let favorite = config::FavoriteDevice {
            fingerprint: fingerprint.clone(),
            endpoint: "192.168.1.77:21118".to_owned(),
            group_id: String::new(),
        };

        let (intent, resolved_fingerprint, _candidates) =
            connection_candidates_from(&favorite.endpoint.clone(), &[], &[favorite], &[]);

        assert_eq!(intent, ConnectionIntent::SavedDevice);
        assert_eq!(resolved_fingerprint, Some(fingerprint));
    }

    #[test]
    fn connection_candidates_does_not_trust_unmatched_legacy_favorite() {
        let favorite = config::FavoriteDevice {
            fingerprint: String::new(),
            endpoint: "192.168.1.78:21118".to_owned(),
            group_id: String::new(),
        };

        let (intent, resolved_fingerprint, _candidates) =
            connection_candidates_from(&favorite.endpoint.clone(), &[], &[favorite], &[]);

        assert_eq!(intent, ConnectionIntent::ManualEndpoint);
        assert_eq!(resolved_fingerprint, None);
    }

    #[test]
    fn parses_manual_scan_ranges() {
        let cidr = parse_ip_range("10.96.160.0/24").unwrap();
        assert_eq!(cidr.len(), 256);
        assert_eq!(cidr[0], "10.96.160.0".parse::<IpAddr>().unwrap());
        assert_eq!(cidr[255], "10.96.160.255".parse::<IpAddr>().unwrap());

        let short = parse_ip_range("10.96.160.1-254").unwrap();
        assert_eq!(short.len(), 254);
        assert_eq!(short[253], "10.96.160.254".parse::<IpAddr>().unwrap());

        let full = parse_ip_range(" 10.96.39.10-10.96.39.12 ").unwrap();
        assert_eq!(full.len(), 3);

        assert_eq!(parse_ip_range("10.96.160.130").unwrap().len(), 1);
        assert_eq!(parse_ip_range("10.0.0.0/16").unwrap().len(), MAX_UNICAST_PROBE_TARGETS);

        assert!(parse_ip_range("").is_err());
        assert!(parse_ip_range("10.0.0.0/8").is_err());
        assert!(parse_ip_range("10.96.160.20-10").is_err());
        assert!(parse_ip_range("not-an-ip").is_err());
    }

    #[test]
    fn calculates_interface_directed_broadcast() {
        assert_eq!(
            directed_broadcast(
                "192.168.42.19".parse().unwrap(),
                "255.255.255.0".parse().unwrap()
            ),
            "192.168.42.255".parse::<Ipv4Addr>().unwrap()
        );
        assert_eq!(
            directed_broadcast("10.12.3.4".parse().unwrap(), "255.255.0.0".parse().unwrap()),
            "10.12.255.255".parse::<Ipv4Addr>().unwrap()
        );
    }

    #[test]
    fn excludes_unscoped_or_unusable_local_addresses() {
        assert!(connectable_local_address("192.168.1.20".parse().unwrap()));
        assert!(connectable_local_address("fd00::20".parse().unwrap()));
        assert!(!connectable_local_address("0.0.0.0".parse().unwrap()));
        assert!(!connectable_local_address("127.0.0.1".parse().unwrap()));
        assert!(!connectable_local_address("fe80::20".parse().unwrap()));
        assert!(!connectable_local_address("ff02::fb".parse().unwrap()));
    }

    #[test]
    fn physical_ethernet_and_wifi_rank_ahead_of_virtual_adapters() {
        assert_eq!(physical_adapter_priority(true, 6), 0);
        assert_eq!(physical_adapter_priority(true, 71), 0);
        assert_eq!(physical_adapter_priority(false, 6), 1);
        assert_eq!(physical_adapter_priority(false, 71), 1);
        assert_eq!(physical_adapter_priority(true, 24), 1);
    }

    #[test]
    fn udp_discovery_ignores_own_fingerprint_and_accepts_another_device() {
        let local = "a".repeat(64);
        for (fingerprint, expected) in [(local.clone(), false), ("b".repeat(64), true)] {
            let receiver = UdpSocket::bind("127.0.0.1:0").unwrap();
            let sender = UdpSocket::bind("127.0.0.1:0").unwrap();
            let mut message = Message::new();
            message.set_peer_discovery(PeerDiscovery {
                cmd: "pong".to_owned(), id: fingerprint, ..Default::default()
            });
            sender.send_to(&message.write_to_bytes().unwrap(), receiver.local_addr().unwrap()).unwrap();
            let (tx, mut rx) = unbounded_channel();
            wait_response(receiver, Instant::now() - Duration::from_secs(7), Arc::new(AtomicBool::new(false)), tx, &local).unwrap();
            assert_eq!(rx.try_recv().is_ok(), expected);
        }
    }

    #[test]
    fn malformed_udp_responses_cannot_bypass_the_scan_deadline() {
        let receiver = UdpSocket::bind("127.0.0.1:0").unwrap();
        let remaining = receiver.try_clone().unwrap();
        remaining.set_read_timeout(Some(Duration::from_millis(100))).unwrap();
        let sender = UdpSocket::bind("127.0.0.1:0").unwrap();
        let mut message = Message::new();
        message.set_peer_discovery(PeerDiscovery {
            cmd: "pong".to_owned(), id: "invalid".to_owned(), ..Default::default()
        });
        let bytes = message.write_to_bytes().unwrap();
        for _ in 0..2 {
            sender.send_to(&bytes, receiver.local_addr().unwrap()).unwrap();
        }
        let (tx, _rx) = unbounded_channel();
        wait_response(receiver, Instant::now() - Duration::from_secs(7), Arc::new(AtomicBool::new(false)), tx, &"a".repeat(64)).unwrap();
        assert!(remaining.recv_from(&mut [0; 2048]).is_ok());
    }

    #[cfg(not(target_os = "ios"))]
    #[test]
    fn observations_on_physical_networks_rank_ahead_of_virtual_ones() {
        let networks = [
            ("10.0.0.1".parse().unwrap(), "255.255.255.0".parse().unwrap(), 1),
            ("192.168.50.2".parse().unwrap(), "255.255.255.0".parse().unwrap(), 0),
        ];
        assert!(observed_endpoint_priority("192.168.50.101:21118", &networks)
            < observed_endpoint_priority("10.0.0.20:21118", &networks));
    }
}
