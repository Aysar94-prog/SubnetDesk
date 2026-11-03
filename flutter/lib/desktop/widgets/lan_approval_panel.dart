import 'package:flutter/material.dart';
import '../../common.dart';

/// Unauthenticated requests get only a local accept/deny surface, never chat
/// or session controls. The backend owns timeout, identity binding and grant.
class LanApprovalPanel extends StatefulWidget {
  const LanApprovalPanel({super.key, required this.name, required this.source,
    required this.scope, required this.ready, required this.onDecision, this.onDecisionWithPermissions, this.translateText});
  final String Function(String)? translateText;
  final String name;
  final String source;
  final String scope;
  final bool ready;
  final Future<String> Function(bool accept) onDecision;
  final Future<String> Function(bool accept, Map<String, bool> permissions)? onDecisionWithPermissions;
  @override
  State<LanApprovalPanel> createState() => _LanApprovalPanelState();
}

class _LanApprovalPanelState extends State<LanApprovalPanel> {
  bool _busy = false;
  String _error = '';
  bool _control = true;
  bool _clipboard = true;
  bool _file = true;
  bool get _fileOnly => widget.scope == 'File transfer';
  bool get _advanced => widget.scope == 'Terminal' || widget.scope == 'Port forwarding';
  String t(String text) => widget.translateText?.call(text) ?? translate(text);
  Future<void> _decide(bool accept) async {
    setState(() { _busy = true; _error = ''; });
    String error;
    try { error = widget.onDecisionWithPermissions == null
        ? await widget.onDecision(accept)
        : await widget.onDecisionWithPermissions!(accept,
            {'keyboard': !_fileOnly && _control, 'clipboard': !_fileOnly && _clipboard, 'file': _file}); }
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
        if (widget.onDecisionWithPermissions != null) ...[
          if (!_fileOnly) ...[
            Text(t(_advanced ? 'Approve only the requested access' : 'View only unless control is enabled')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
              title: Text(t(_advanced ? 'Allow requested access' : 'Control')), value: _control,
              onChanged: _busy ? null : (value) => setState(() => _control = value == true)),
            if (!_advanced) CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
              title: Text(t('Clipboard')), value: _clipboard,
              onChanged: _busy ? null : (value) => setState(() => _clipboard = value == true)),
          ],
          if (!_advanced) CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
            title: Text(t('Transfer file')), value: _file,
            onChanged: _busy ? null : (value) => setState(() => _file = value == true)),
        ],
        Wrap(spacing: 10, children: [
          ElevatedButton(key: const ValueKey('lan-approve'),
            onPressed: widget.ready && !_busy &&
                (widget.onDecisionWithPermissions == null ||
                    (_fileOnly ? _file : _advanced ? _control : true)) ? () => _decide(true) : null,
            child: Text(t('Accept'))),
          OutlinedButton(key: const ValueKey('lan-deny'),
            onPressed: widget.ready && !_busy ? () => _decide(false) : null,
            child: Text(t('Deny'))),
        ]),
        if (_busy) Text(t('Decision sent; waiting for receiver confirmation')),
        if (_error.isNotEmpty) Text(t(_error)),
      ]));
}
