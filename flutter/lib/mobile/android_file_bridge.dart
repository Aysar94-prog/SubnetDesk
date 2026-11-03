import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Android system file picker bridge for outgoing file transfer.
///
/// SubnetDesk Helper on Android no longer holds broad storage access
/// (MANAGE_EXTERNAL_STORAGE / READ_/WRITE_EXTERNAL_STORAGE). The local side of
/// the file manager is the app's own transfer folder, which needs no
/// permission. Files are brought in and taken out through Android's system
/// picker (Storage Access Framework), which grants access only to what the user
/// selects.

/// Copies files the user picks with the system picker into [targetDir].
/// Returns the number of files copied (0 when the user cancels).
Future<int> importFilesFromPhone(String targetDir) async {
  final result = await FilePicker.pickFiles(allowMultiple: true);
  if (result == null) return 0;
  var copied = 0;
  try {
    for (final file in result.files) {
      final source = file.path;
      if (source == null || source.isEmpty) continue;
      final destination = _uniquePath(targetDir, p.basename(file.name));
      await File(source).copy(destination);
      copied++;
    }
  } finally {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (e) {
      debugPrint('clear picker cache failed: $e');
    }
  }
  return copied;
}

/// Saves a file from the app transfer folder to a location the user chooses
/// with the system picker. Returns true when the user completed the save.
Future<bool> saveFileToPhone(String sourcePath) async {
  final bytes = await File(sourcePath).readAsBytes();
  final saved = await FilePicker.saveFile(
    fileName: p.basename(sourcePath),
    bytes: bytes,
  );
  return saved != null;
}

String _uniquePath(String dir, String name) {
  var candidate = p.join(dir, name);
  if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) {
    return candidate;
  }
  final stem = p.basenameWithoutExtension(name);
  final ext = p.extension(name);
  for (var i = 1;; i++) {
    candidate = p.join(dir, '$stem ($i)$ext');
    if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) {
      return candidate;
    }
  }
}
