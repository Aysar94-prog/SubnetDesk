import 'package:flutter/material.dart';

/// The Windows incoming-session dock. Folding changes presentation only;
/// session controls and the chat model remain owned by ConnectionManager.
class CmSessionPanel extends StatelessWidget {
  const CmSessionPanel({
    super.key,
    required this.title,
    required this.collapsed,
    required this.showChat,
    required this.chatLabel,
    required this.controlsLabel,
    required this.foldLabel,
    required this.sessionPicker,
    required this.chat,
    required this.controls,
    required this.onFold,
    required this.onShowChat,
    required this.onShowControls,
    this.unreadCount = 0,
    this.attention = false,
    this.soundMuted = false,
    this.onToggleSound,
    this.voiceRingMuted = false,
    this.onToggleVoiceRing,
    this.voiceRingError,
  });

  final String title;
  final bool collapsed;
  final bool showChat;
  final String chatLabel;
  final String controlsLabel;
  final String foldLabel;
  final Widget sessionPicker;
  final Widget chat;
  final Widget controls;
  final VoidCallback onFold;
  final VoidCallback onShowChat;
  final VoidCallback onShowControls;
  final int unreadCount;
  final bool attention;
  final bool soundMuted;
  final VoidCallback? onToggleSound;
  final bool voiceRingMuted;
  final VoidCallback? onToggleVoiceRing;
  final String? voiceRingError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: Material(
            color: attention ? const Color(0xffad5c00) : const Color(0xff1d3557),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.desktop_windows,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onFold,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$unreadCount',
                      key: const ValueKey('cm-unread-count'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (attention)
                  const Icon(Icons.notifications_active, color: Colors.white,
                    size: 18, key: ValueKey('cm-buzzer-attention')),
                if (onToggleSound != null)
                  IconButton(
                    key: const ValueKey('cm-buzzer-mute'),
                    tooltip: soundMuted ? 'Unmute buzzer' : 'Mute buzzer',
                    onPressed: onToggleSound,
                    icon: Icon(soundMuted ? Icons.notifications_off :
                        Icons.notifications_none, color: Colors.white, size: 18),
                  ),
                IconButton(
                  key: const ValueKey('cm-fold'),
                  tooltip: foldLabel,
                  onPressed: onFold,
                  icon: Icon(
                    collapsed ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ),
                if (onToggleVoiceRing != null)
                  IconButton(
                    key: const ValueKey('cm-voice-ring-mute'),
                    tooltip: voiceRingMuted ? 'Unmute call ringtone' : 'Mute call ringtone',
                    onPressed: onToggleVoiceRing,
                    icon: Icon(voiceRingMuted ? Icons.volume_off : Icons.phone_in_talk,
                      color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          if (voiceRingError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(voiceRingError!, key: const ValueKey('cm-voice-ring-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          sessionPicker,
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey('cm-chat-tab'),
                  onPressed: onShowChat,
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: showChat
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(chatLabel),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey('cm-controls-tab'),
                  onPressed: onShowControls,
                  icon: Icon(
                    Icons.tune,
                    color: !showChat
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(controlsLabel),
                ),
              ),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: showChat ? 0 : 1,
              children: [chat, controls],
            ),
          ),
        ],
      ],
    );
  }
}
