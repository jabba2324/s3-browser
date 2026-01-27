import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class ShareExtensionService {
  static const _channel = MethodChannel('com.s3browser/credentials');

  /// Save credentials to shared storage for the iOS Share Extension
  static Future<void> saveCredentialsForExtension(List<Map<String, String>> credentials) async {
    if (kIsWeb) return; // Not applicable on web

    try {
      await _channel.invokeMethod('saveCredentialsForExtension', {
        'credentials': credentials,
      });
    } catch (_) {
      // Silently fail on platforms that don't support this
    }
  }

  /// Clear credentials from shared storage
  static Future<void> clearCredentialsForExtension() async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('clearCredentialsForExtension');
    } catch (_) {
      // Silently fail on platforms that don't support this
    }
  }
}
