import 'package:flutter/material.dart';

/// Unauthenticated requests get only a local accept/deny surface, never chat
/// or session controls. The backend owns timeout, identity binding and grant.
class LanApprovalPanel extends StatefulWidget {
  const LanApprovalPanel({super.key, required this.name, required this.source,
    required this.scope, required this.ready, required this.onDecision});
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
  Future<void> _decide(bool accept) async {
    setState(() { _busy = true; _error = ''; });
    String error;
    try { error = await widget.onDecision(accept); }
    catch (_) { error = 'تعذر إرسال القرار؛ لم يتم منح الدخول'; }
    if (mounted) setState(() { _error = error; _busy = error.isEmpty; });
  }
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('طلب اتصال — لم يبدأ التحكم', key: ValueKey('lan-pending-title')),
        const SizedBox(height: 8),
        Text('اسم يعلنه المرسل: ${widget.name}'),
        Text('عنوان الشبكة: ${widget.source}'),
        Text('الوصول المطلوب: ${widget.scope}'),
        const Text('ينتهي الطلب خلال 60 ثانية. اقبل فقط جهازًا تعرفه.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: [
          ElevatedButton(key: const ValueKey('lan-approve'),
            onPressed: widget.ready && !_busy ? () => _decide(true) : null,
            child: const Text('قبول')),
          OutlinedButton(key: const ValueKey('lan-deny'),
            onPressed: widget.ready && !_busy ? () => _decide(false) : null,
            child: const Text('رفض')),
        ]),
        if (_busy) const Text('أُرسل القرار؛ بانتظار تأكيد الجهاز'),
        if (_error.isNotEmpty) Text(_error),
      ]));
}
