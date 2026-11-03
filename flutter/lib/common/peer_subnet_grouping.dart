/// A run of items that share one IPv4 /24 subnet, e.g. every device in
/// `10.96.20.x`. [label] is null for the catch-all group of items whose id
/// isn't an IPv4 endpoint (IPv6, hostname), which always sorts last.
class SubnetGroup<T> {
  final String? label;
  final List<T> items;

  SubnetGroup(this.label, this.items);
}

/// Returns the `/24` subnet label for a peer id such as `10.96.20.5:21118`
/// (→ `10.96.20.x`), or null when the id isn't an IPv4 address/endpoint.
String? subnetLabelForId(String id) {
  final value = id.trim();
  if (value.startsWith('[')) return null;
  final host = value.split(':').first;
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return null;
    octets.add(octet);
  }
  return '${octets[0]}.${octets[1]}.${octets[2]}.x';
}

int _compareSubnetLabels(String a, String b) {
  final pa = a.split('.').take(3).map(int.parse).toList();
  final pb = b.split('.').take(3).map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final diff = pa[i].compareTo(pb[i]);
    if (diff != 0) return diff;
  }
  return 0;
}

/// Splits [items] into subnet groups ordered numerically by subnet, with
/// non-IPv4 items last. The relative order of items within each group is
/// preserved, so the user's chosen sort still applies inside a group.
List<SubnetGroup<T>> groupBySubnet<T>(
    List<T> items, String Function(T item) idOf) {
  final groups = <String, List<T>>{};
  final other = <T>[];
  for (final item in items) {
    final label = subnetLabelForId(idOf(item));
    if (label == null) {
      other.add(item);
    } else {
      groups.putIfAbsent(label, () => <T>[]).add(item);
    }
  }
  final labels = groups.keys.toList()..sort(_compareSubnetLabels);
  return [
    for (final label in labels) SubnetGroup<T>(label, groups[label]!),
    if (other.isNotEmpty) SubnetGroup<T>(null, other),
  ];
}
