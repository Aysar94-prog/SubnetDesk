import 'package:flutter/foundation.dart';

import '../common.dart';

/// Handles the few messages the Android host activity sends to Flutter.
///
/// SubnetDesk Helper on Android is an outgoing controller only, so there are no
/// hosting/screen-capture/input-service messages any more: only runtime
/// permission results (e.g. the microphone for a user-initiated voice call in
/// an outgoing PC session) and native message boxes.
void androidChannelInit() {
  gFFI.setMethodCallHandler((method, arguments) {
    debugPrint("flutter got android message: $method");
    try {
      switch (method) {
        case "on_android_permission_result":
          {
            var type = arguments["type"] as String;
            var result = arguments["result"] as bool;
            AndroidPermissionManager.complete(type, result);
            break;
          }
        case "msgbox":
          {
            var type = arguments["type"] as String;
            var title = arguments["title"] as String;
            var text = arguments["text"] as String;
            var link = (arguments["link"] ?? '') as String;
            msgBox(gFFI.sessionId, type, title, text, link, gFFI.dialogManager);
            break;
          }
      }
    } catch (e) {
      debugPrintStack(label: "MethodCallHandler err:$e");
    }
    return "";
  });
}
