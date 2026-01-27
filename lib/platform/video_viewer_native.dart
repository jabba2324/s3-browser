// Native iOS implementation for video player using method channel
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.s3browser/video');

void registerVideoElement(String viewId, String url) {
  // No-op on native platforms - HtmlElementView not used
}

Future<void> playNativeVideo(String url) async {
  await _channel.invokeMethod('playVideo', {'url': url});
}
