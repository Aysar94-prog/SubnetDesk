import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/peer_model.dart';

void main() {
  test('recent endpoint timestamp survives JSON and autocomplete copies', () {
    final peer = Peer.fromJson({
      'id': '192.0.2.1',
      'alias': 'Office',
      'last_connected_at': '1791712800000',
    });
    expect(peer.lastConnectedAt, 1791712800000);
    expect(Peer.copy(peer).lastConnectedAt, peer.lastConnectedAt);
    expect(Peer.fromJson(peer.toJson()).lastConnectedAt, peer.lastConnectedAt);
    final old = Peer.fromJson({'id': '192.0.2.1', 'alias': 'Office'});
    expect(old.lastConnectedAt, 0);
    expect(peer.equal(old), false);
  });
}
