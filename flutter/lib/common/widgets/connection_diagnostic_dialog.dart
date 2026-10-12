import 'package:flutter/material.dart';
import '../../common.dart';
import '../connection_diagnostics.dart';

Future<void> showConnectionDiagnostic(
  BuildContext context,
  String endpoint, {
  String Function(String)? translateText,
}) => showDialog<void>(
  context: context,
  builder: (_) => ConnectionDiagnosticDialog(
    endpoint: endpoint,
    translateText: translateText,
  ),
);

class ConnectionDiagnosticDialog extends StatefulWidget {
  const ConnectionDiagnosticDialog({
    super.key,
    required this.endpoint,
    this.translateText,
  });
  final String endpoint;
  final String Function(String)? translateText;
  @override
  State<ConnectionDiagnosticDialog> createState() =>
      _ConnectionDiagnosticDialogState();
}

class _ConnectionDiagnosticDialogState
    extends State<ConnectionDiagnosticDialog> {
  late final _endpoint = TextEditingController(text: widget.endpoint);
  ConnectionDiagnostic? _result;
  bool _busy = false;
  String t(String text) => widget.translateText?.call(text) ?? translate(text);
  @override
  void initState() {
    super.initState();
    if (widget.endpoint.isNotEmpty) _check();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await diagnoseConnection(_endpoint.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Check connection')),
    content: SizedBox(
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _endpoint,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'IP / hostname:port'),
            onChanged: (_) => setState(() => _result = null),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_result != null) ...[
            Icon(
              _result!.state == DiagnosticState.reachable
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
            ),
            Text(t(_result!.message)),
            if (_result!.elapsedMs != null) Text('${_result!.elapsedMs} ms'),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Close')),
      ),
      ElevatedButton(
        onPressed: _busy ? null : _check,
        child: Text(t('Check connection')),
      ),
    ],
  );
}
