// Native iOS implementation for photo viewer

void registerImageElement(String viewId, String url) {
  // No-op on native platforms - uses Flutter Image widget
}

bool isMobileWeb() {
  // Always false on native platforms
  return false;
}

void enterFullscreen() {
  // No-op on native - uses SystemChrome instead
}

void exitFullscreen() {
  // No-op on native - uses SystemChrome instead
}
