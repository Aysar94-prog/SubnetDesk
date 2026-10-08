import 'package:flutter/material.dart';
import '../../common.dart';

/// Unauthenticated requests get only a local accept/deny surface, never chat
/// or session controls. The backend owns timeout, identity binding and grant.
class LanApprovalPanel extends StatefulWidget {
  const LanApprovalPanel({super.key, required this.name, required this.source,
    required this.scope, required this.ready, required this.onDecision, this.translateText});
  final String Function(String)? translateText;
  final String name;
  final String source;
  final String scope;
  final bool ready;
  final Future<String> Function(bool accept) onDecision;
  @override
  State<LanApprovalPanel> createState() => _LanApprovalPanelState();
}

class _LanApprovalPanelState extends State<LanApprovalPanel> {
  bool _busy = false;
  String _error = '';
  String t(String text) => widget.translateText?.call(text) ?? translate(text);
  Future<void> _decide(bool accept) async {
    setState(() { _busy = true; _error = ''; });
    String error;
    try { error = await widget.onDecision(accept); }
    catch (_) { error = 'Unable to send decision; access was not granted'; }
    if (mounted) setState(() { _error = error; _busy = error.isEmpty; });
  }
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Connection request — control has not started'), key: const ValueKey('lan-pending-title')),
        const SizedBox(height: 8),
        Text('${t('Claimed sender name')}: ${widget.name}'),
        Text('${t('Network address')}: ${widget.source}'),
        Text('${t('Requested access')}: ${t(widget.scope)}'),
        Text(t('Request expires after 60 seconds. Accept only a device you recognize.')),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: [
          ElevatedButton(key: const ValueKey('lan-approve'),
            onPressed: widget.ready && !_busy ? () => _decide(true) : null,
            child: Text(t('Accept'))),
          OutlinedButton(key: const ValueKey('lan-deny'),
            onPressed: widget.ready && !_busy ? () => _decide(false) : null,
            child: Text(t('Deny'))),
        ]),
        if (_busy) Text(t('Decision sent; waiting for receiver confirmation')),
        if (_error.isNotEmpty) Text(t(_error)),
      ]));
}
