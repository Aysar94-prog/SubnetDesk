import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a LAN discovery peer the way the backend projects it: every field,
/// including `last_seen_at`, is serialized as a string.
Peer _lanPeer(String id, {required String reachability, int lastSeenAt = 0}) {
  return Peer.fromJson({
    'id': id,
    'reachability': reachability,
    'last_seen_at': '$lastSeenAt',
  });
}

void main() {
  const now = 1000000000000;

  test('discovered list keeps only currently-online peers', () {
    final peers = [
      _lanPeer('a', reachability: 'online', lastSeenAt: now - 1000),
      _lanPeer('b', reachability: 'unknown', lastSeenAt: now - 1000),
      _lanPeer('c', reachability: 'offline', lastSeenAt: now - 1000),
    ];

    expect(
      peers
          .where((peer) => includeInDiscoveredList(peer, nowMs: now))
          .map((peer) => peer.id)
          .toList(),
      ['a'],
    );
  });

  test('an online device drops out once it stops being observed', () {
    final fresh = _lanPeer('a', reachability: 'online', lastSeenAt: now - 5000);
    final stale = _lanPeer('a', reachability: 'online', lastSeenAt: now - 31000);

    expect(includeInDiscoveredList(fresh, nowMs: now), isTrue);
    expect(includeInDiscoveredList(stale, nowMs: now), isFalse);
  });

  test('a device seen again comes back into the list', () {
    final gone = _lanPeer('a', reachability: 'online', lastSeenAt: now - 31000);
    final back = _lanPeer('a', reachability: 'online', lastSeenAt: now - 500);

    expect(includeInDiscoveredList(gone, nowMs: now), isFalse);
    expect(includeInDiscoveredList(back, nowMs: now), isTrue);
  });

  test('the timestamp is read from the string the backend sends', () {
    expect(_lanPeer('a', reachability: 'online', lastSeenAt: 42).lastSeenAt, 42);
  });

  test('a peer with no observation timestamp falls back to reachability', () {
    final online = Peer.fromJson({'id': 'a', 'reachability': 'online'});
    final offline = Peer.fromJson({'id': 'b', 'reachability': 'offline'});

    expect(online.lastSeenAt, 0);
    expect(includeInDiscoveredList(online, nowMs: now), isTrue);
    expect(includeInDiscoveredList(offline, nowMs: now), isFalse);
  });

  test('legacy peers without reachability stay hidden when offline', () {
    final peer = Peer.fromJson({'id': 'a', 'online': false});

    expect(includeInDiscoveredList(peer, nowMs: now), isFalse);
  });
}
