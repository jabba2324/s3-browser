// Web implementation for video player with HTML5 video elements
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerVideoElement(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video.src = url;
    video.controls = true;
    video.autoplay = true;
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.backgroundColor = 'black';
    return video;
  });
}

Future<void> playNativeVideo(String url) async {
  // No-op on web - uses HtmlElementView instead
}
