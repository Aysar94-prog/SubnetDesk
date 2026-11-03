import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'platform_model.dart';

class Peer {
  final String id;
  String username; // pc username
  String hostname;
  String platform;
  String alias;
  String fingerprint;
  String rdpPort;
  String rdpUsername;
  bool online = false;

  /// When LAN discovery last observed this peer (Unix ms), or 0 if unknown.
  /// Only LAN discovery peers carry it; recent/favorite peers do not.
  int lastSeenAt = 0;
  int lastConnectedAt = 0;

  String getId() {
    if (alias != '') {
      return alias;
    }
    return id;
  }

  Peer.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        username = json['username'] ?? '',
        hostname = json['hostname'] ?? '',
        platform = json['platform'] ?? '',
        alias = json['alias'] ?? '',
        fingerprint = json['fingerprint'] ?? '',
        rdpPort = json['rdpPort'] ?? '',
        rdpUsername = json['rdpUsername'] ?? '' {
    lastConnectedAt = int.tryParse(json['last_connected_at']?.toString() ?? '') ?? 0;
    // LAN discovery peers carry a tri-state `reachability` string
    // ('online'|'unknown'|'offline') and a `last_seen_at` timestamp; recent
    // and favorite peers still carry the legacy `online` bool. Prefer
    // reachability when present so a discovered device is only "online" while
    // it is actually reachable. The backend serializes every field of this
    // projection as a string, so the timestamp arrives as text.
    final reachability = json['reachability'];
    if (reachability is String && reachability.isNotEmpty) {
      online = reachability == 'online';
      final lastSeenAt = json['last_seen_at'];
      this.lastSeenAt = lastSeenAt is int
          ? lastSeenAt
          : int.tryParse(lastSeenAt?.toString() ?? '') ?? 0;
    } else {
      online = json['online'] == true;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "username": username,
      "hostname": hostname,
      "platform": platform,
      "alias": alias,
      "fingerprint": fingerprint,
      "rdpPort": rdpPort,
      "rdpUsername": rdpUsername,
      "last_connected_at": lastConnectedAt,
    };
  }

  Peer({
    required this.id,
    required this.username,
    required this.hostname,
    required this.platform,
    required this.alias,
    required this.fingerprint,
    required this.rdpPort,
    required this.rdpUsername,
  });

  Peer.loading()
      : this(
          id: '...',
          username: '...',
          hostname: '...',
          platform: '...',
          alias: '',
          fingerprint: '',
          rdpPort: '',
          rdpUsername: '',
        );
  bool equal(Peer other) {
    return id == other.id &&
        username == other.username &&
        hostname == other.hostname &&
        platform == other.platform &&
        alias == other.alias &&
        fingerprint == other.fingerprint &&
        rdpPort == other.rdpPort &&
        rdpUsername == other.rdpUsername &&
        lastConnectedAt == other.lastConnectedAt;
  }

  factory Peer.copy(Peer other) {
    final peer = Peer(
        id: other.id,
        username: other.username,
        hostname: other.hostname,
        platform: other.platform,
        alias: other.alias,
        fingerprint: other.fingerprint,
        rdpPort: other.rdpPort,
        rdpUsername: other.rdpUsername);
    peer.online = other.online;
    peer.lastSeenAt = other.lastSeenAt;
    peer.lastConnectedAt = other.lastConnectedAt;
    return peer;
  }
}

/// How long a device stays in the live Discovered list after LAN discovery
/// last saw it. Once this elapses the device drops out; it reappears as soon
/// as it is observed again.
const discoveredOnlineWindowMs = 30 * 1000;

/// Filter for the live Discovered ("LAN") list: only devices that are
/// currently reachable are shown, so an offline device drops out instead of
/// lingering forever. A peer the backend reports as online but that has not
/// been observed within [discoveredOnlineWindowMs] is treated as gone. Peers
/// without a timestamp fall back to the backend's reachability.
bool includeInDiscoveredList(Peer peer, {int? nowMs}) {
  if (!peer.online) {
    return false;
  }
  if (peer.lastSeenAt <= 0) {
    return true;
  }
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return now - peer.lastSeenAt <= discoveredOnlineWindowMs;
}

enum UpdateEvent { online, load }

typedef GetInitPeers = RxList<Peer> Function();

class Peers extends ChangeNotifier {
  final String name;
  final String loadEvent;
  List<Peer> peers = List.empty(growable: true);
  // Part of the peers that are not in the rest peers list.
  // When there're too many peers, we may want to load the front 100 peers first,
  // so we can see peers in UI quickly. `restPeerIds` is the rest peers' ids.
  // And then load all peers later.
  List<String> restPeerIds = List.empty(growable: true);
  final GetInitPeers? getInitPeers;
  UpdateEvent event = UpdateEvent.load;

  Peers(
      {required this.name,
      required this.getInitPeers,
      required this.loadEvent}) {
    peers = getInitPeers?.call() ?? [];
    platformFFI.registerEventHandler(loadEvent, name, (evt) async {
      _updatePeers(evt);
    });
  }

  @override
  void dispose() {
    platformFFI.unregisterEventHandler(loadEvent, name);
    super.dispose();
  }

  Peer getByIndex(int index) {
    if (index < peers.length) {
      return peers[index];
    } else {
      return Peer.loading();
    }
  }

  int getPeersCount() {
    return peers.length;
  }

  void _updatePeers(Map<String, dynamic> evt) {
    if (getInitPeers != null) {
      peers = getInitPeers?.call() ?? [];
    } else {
      peers = _decodePeers(evt['peers']);
    }

    restPeerIds = [];
    if (evt['ids'] != null) {
      restPeerIds = (evt['ids'] as String).split(',');
    }

    event = UpdateEvent.load;
    notifyListeners();
  }

  Map<String, bool> _getOnlineStates() {
    var onlineStates = <String, bool>{};
    for (var peer in peers) {
      onlineStates[peer.id] = peer.online;
    }
    return onlineStates;
  }

  List<Peer> _decodePeers(String peersStr) {
    try {
      if (peersStr == "") return [];
      List<dynamic> peers = json.decode(peersStr);
      return peers.map((peer) {
        return Peer.fromJson(peer as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('peers(): $e');
    }
    return [];
  }
}
