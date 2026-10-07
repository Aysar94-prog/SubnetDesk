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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: Material(
            color: const Color(0xff1d3557),
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
                IconButton(
                  key: const ValueKey('cm-fold'),
                  tooltip: foldLabel,
                  onPressed: onFold,
                  icon: Icon(
                    collapsed ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
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
