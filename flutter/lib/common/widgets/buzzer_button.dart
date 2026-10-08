import 'package:flutter/material.dart';

class BuzzerButton extends StatelessWidget {
  const BuzzerButton({
    super.key,
    required this.supported,
    required this.coolingDown,
    required this.onPressed,
  });
  final bool supported;
  final bool coolingDown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('chat-buzzer'),
    tooltip: !supported
        ? 'Buzzer: receiver does not support this action'
        : coolingDown
        ? 'Buzzer: wait 5 seconds'
        : 'Buzzer: alert receiver',
    onPressed: supported && !coolingDown ? onPressed : null,
    icon: Icon(
      coolingDown ? Icons.hourglass_empty : Icons.notifications_active,
    ),
  );
}
