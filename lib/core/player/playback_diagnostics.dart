import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PlaybackDiagnostics {
  PlaybackDiagnostics._();

  static Future<File> get _logFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/playback_diagnostics.txt');
  }

  static Future<void> log(String message) async {
    try {
      final file = await _logFile;
      final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
      final logLine = '[$timestamp] $message\n';
      
      if (kDebugMode) {
        debugPrint('[PlaybackDiagnostics] $message');
      }
      
      await file.writeAsString(
        logLine,
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static Future<String> readLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return 'No diagnostic logs found.';
  }

  static Future<void> clearLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
      await log('Logs cleared by user.');
    } catch (_) {}
  }
}
