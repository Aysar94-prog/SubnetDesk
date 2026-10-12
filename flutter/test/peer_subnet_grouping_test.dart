import 'package:flutter_hbb/common/peer_subnet_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives /24 label from IPv4 endpoints and plain IPs', () {
    expect(subnetLabelForId('10.96.20.5:21118'), '10.96.20.x');
    expect(subnetLabelForId('10.96.30.17'), '10.96.30.x');
  });

  test('non-IPv4 ids have no subnet label', () {
    expect(subnetLabelForId('[fd00::5]:21118'), isNull);
    expect(subnetLabelForId('office-pc.local:21118'), isNull);
    expect(subnetLabelForId('10.96.300.1:21118'), isNull);
    expect(subnetLabelForId('10.96.20:21118'), isNull);
  });

  test('groups numerically by subnet, keeps in-group order, other last', () {
    final ids = [
      'host.local:21118',
      '10.96.30.9:21118',
      '10.96.100.1:21118',
      '10.96.20.7:21118',
      '10.96.30.2:21118',
      '10.96.20.3:21118',
    ];
    final groups = groupBySubnet<String>(ids, (id) => id);

    expect(groups.map((g) => g.label).toList(),
        ['10.96.20.x', '10.96.30.x', '10.96.100.x', null]);
    expect(groups[0].items, ['10.96.20.7:21118', '10.96.20.3:21118']);
    expect(groups[1].items, ['10.96.30.9:21118', '10.96.30.2:21118']);
    expect(groups[3].items, ['host.local:21118']);
  });

  test('empty input yields no groups', () {
    expect(groupBySubnet<String>([], (id) => id), isEmpty);
  });
}
