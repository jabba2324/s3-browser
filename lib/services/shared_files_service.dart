import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SharedFilesService {
  static const _channel = MethodChannel('com.s3browser/shared_files');
  static Function()? _onSharedFilesReceived;

  /// Initialize the service and set up listener for incoming shared files
  static void initialize({Function()? onSharedFilesReceived}) {
    if (kIsWeb) return;

    _onSharedFilesReceived = onSharedFilesReceived;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFilesReceived') {
        _onSharedFilesReceived?.call();
      }
    });
  }

  /// Get pending shared files from the share extension
  static Future<List<String>> getPendingSharedFiles() async {
    if (kIsWeb) return [];

    try {
      final result = await _channel.invokeMethod('getPendingSharedFiles');
      if (result is List) {
        return result.cast<String>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Clear shared files from the shared container
  static Future<void> clearSharedFiles() async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('clearSharedFiles');
    } catch (_) {
      // Silently fail
    }
  }
}
