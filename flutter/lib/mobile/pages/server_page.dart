import 'package:flutter/material.dart';

import '../../common.dart';
import '../../models/server_model.dart';

// SubnetDesk Helper on Android is an outgoing controller only. The former
// phone-hosting "Share screen" page, its service/permission controls and the
// incoming-connection manager were removed. Only this shared client card
// remains because ServerModel still builds it for its (desktop) dialogs.

class ClientInfo extends StatelessWidget {
  final Client client;
  ClientInfo(this.client);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: -1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildAvatar(context),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(client.peerId, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final fallback = CircleAvatar(
      backgroundColor: str2color(
        client.name,
        Theme.of(context).brightness == Brightness.light ? 255 : 150,
      ),
      child: Text(client.name.isNotEmpty ? client.name[0] : '?'),
    );
    return buildAvatarWidget(
          avatar: client.avatar,
          size: 40,
          fallback: fallback,
        ) ??
        fallback;
  }
}
