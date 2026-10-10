import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Source guards for the outgoing-only Android helper (plan-v002, AO-03..AO-05).
// They complement, and do not replace, merged-manifest inspection of the built
// APK and physical device acceptance.
void main() {
  const androidMain = 'android/app/src/main';
  const kotlinDir = '$androidMain/kotlin/com/carriez/flutter_hbb';

  String read(String path) => File(path).readAsStringSync();

  List<String> usesPermissions(String manifest) {
    final permission = RegExp(
        r'<uses-permission\s+android:name="([^"]+)"\s*(tools:node="remove")?\s*/>');
    return permission
        .allMatches(manifest)
        .where((m) => m.group(2) == null)
        .map((m) => m.group(1)!)
        .toList();
  }

  test('manifest declares only outgoing-controller permissions', () {
    final manifest = read('$androidMain/AndroidManifest.xml');
    expect(
      usesPermissions(manifest).toSet(),
      {
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.ACCESS_WIFI_STATE',
        'android.permission.RECORD_AUDIO',
      },
    );
    for (final removed in [
      'MANAGE_EXTERNAL_STORAGE',
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'POST_NOTIFICATIONS',
      'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      'CHANGE_WIFI_MULTICAST_STATE',
      'FOREGROUND_SERVICE',
      'FOREGROUND_SERVICE_MEDIA_PROJECTION',
      'WAKE_LOCK',
      'RECEIVE_BOOT_COMPLETED',
      'SYSTEM_ALERT_WINDOW',
    ]) {
      expect(
        manifest,
        contains(
            '<uses-permission android:name="android.permission.$removed" tools:node="remove" />'),
        reason: '$removed must be stripped from the merged manifest',
      );
    }
    expect(manifest, isNot(contains('requestLegacyExternalStorage')));
  });

  test('manifest has no hosting components', () {
    final manifest = read('$androidMain/AndroidManifest.xml');
    for (final component in [
      '<service',
      '<receiver',
      'BootReceiver',
      'MainService',
      'InputService',
      'FloatingWindowService',
      'PermissionRequestTransparentActivity',
      'BIND_ACCESSIBILITY_SERVICE',
      'mediaProjection',
    ]) {
      expect(manifest, isNot(contains(component)), reason: component);
    }
  });

  test('hosting Kotlin sources and native entry points are gone', () {
    for (final name in [
      'BootReceiver.kt',
      'MainService.kt',
      'InputService.kt',
      'FloatingWindowService.kt',
      'PermissionRequestTransparentActivity.kt',
    ]) {
      expect(File('$kotlinDir/$name').existsSync(), isFalse, reason: name);
    }
    final ffi = read('$androidMain/kotlin/ffi.kt');
    expect(ffi, isNot(contains('fun startServer(')));
    expect(ffi, isNot(contains('fun startService(')));
    expect(ffi, isNot(contains('fun init(')));
    final activity = read('$kotlinDir/MainActivity.kt');
    for (final method in [
      '"init_service"',
      '"start_capture"',
      '"stop_service"',
      '"check_service"',
      '"stop_input"',
      'START_ON_BOOT',
      'MainService',
      'FloatingWindowService',
      'MediaProjection',
    ]) {
      expect(activity, isNot(contains(method)), reason: method);
    }
  });

  test('mobile UI has no phone-sharing page or LAN host settings', () {
    final home = read('lib/mobile/pages/home_page.dart');
    expect(home, isNot(contains('ServerPage')));
    expect(home, isNot(contains('ChatPageType.mobileMain')));
    final settings = read('lib/mobile/pages/settings_page.dart');
    expect(settings, contains('if (!isAndroid)\n          SettingsSection('));
    final serverPage = read('lib/mobile/pages/server_page.dart');
    expect(serverPage, isNot(contains('toggleService')));
    expect(serverPage, isNot(contains('class ServerPage')));
  });

  test('outgoing file transfer and voice need no broad storage grant', () {
    final common = read('lib/common.dart');
    final connect = common.substring(common.indexOf('    if (isFileTransfer) {'));
    expect(connect.substring(0, connect.indexOf('if (isWeb)')),
        isNot(contains('kManageExternalStorage')));
    final native = read('lib/models/native_model.dart');
    expect(native, isNot(contains('ExternalPath.getExternalStorageDirectories')));
    expect(native, contains('getExternalStorageDirectory()'));
    final files = read('lib/mobile/pages/file_manager_page.dart');
    expect(files, contains('importFilesFromPhone('));
    expect(files, contains('saveFileToPhone('));
    for (final page in [
      'lib/mobile/pages/remote_page.dart',
      'lib/mobile/pages/view_camera_page.dart',
    ]) {
      expect(read(page), contains('await ensureAndroidVoiceCallMicrophone()'),
          reason: page);
    }
  });
}
