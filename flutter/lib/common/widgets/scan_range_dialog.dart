import 'package:flutter/material.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

/// Scans an IP range/CIDR by direct unicast, bypassing UDP broadcast/mDNS.
/// Normal discovery never crosses a routed subnet/VLAN boundary because the
/// router drops broadcast and multicast, while a routed unicast ping to a
/// known IP still gets a reply. Results arrive through the usual discovery
/// event, so they show up in the Discovered list.
Future<void> showScanRangeDialog(BuildContext context) async {
  final controller = TextEditingController();
  final saved = (await bind.mainGetSavedSubnets()).toList();
  if (!context.mounted) return;
  String? error;
  var saveSubnet = true;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> startScan([String? preset]) async {
          final range = (preset ?? controller.text).trim();
          if (range.isEmpty) return;
          final err = await bind.mainDiscoverRange(range: range);
          if (err.isNotEmpty) {
            setDialogState(() => error = err);
            return;
          }
          if (preset == null && saveSubnet && !saved.contains(range)) {
            await bind.mainAddSavedSubnet(subnet: range);
          }
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
          showToast('${translate('Scanning')} $range');
        }

        Future<void> removeSaved(String subnet) async {
          await bind.mainRemoveSavedSubnet(subnet: subnet);
          setDialogState(() => saved.remove(subnet));
        }

        return AlertDialog(
          scrollable: true,
          title: Text(translate('Scan IP range')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (saved.isNotEmpty) ...[
                  Text(translate('Saved subnets'),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: saved
                        .map((subnet) => InputChip(
                              avatar: const Icon(Icons.lan_outlined, size: 18),
                              label: Text(subnet),
                              tooltip: translate('Scan'),
                              onPressed: () => startScan(subnet),
                              onDeleted: () => removeSaved(subnet),
                              deleteButtonTooltipMessage: translate('Delete'),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: translate('IP, CIDR, or range'),
                    hintText: '10.96.160.0/24',
                    prefixIcon: const Icon(Icons.travel_explore),
                    errorText: error,
                  ),
                  onChanged: (_) {
                    if (error != null) setDialogState(() => error = null);
                  },
                  onSubmitted: (_) => startScan(),
                ),
                CheckboxListTile(
                  value: saveSubnet,
                  onChanged: (value) =>
                      setDialogState(() => saveSubnet = value == true),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(translate('Save this subnet')),
                ),
                Text(
                  translate(
                    'Use this when a device on another subnet does not show up automatically, e.g. 10.96.160.0/24 or 10.96.160.1-254.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(translate('Cancel')),
            ),
            ElevatedButton(
              onPressed: startScan,
              child: Text(translate('Scan')),
            ),
          ],
        );
      },
    ),
  );
}
