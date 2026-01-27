// Web implementation for photo viewer with HTML5 image elements
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerImageElement(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.id = viewId;
    container.style.width = '100%';
    container.style.height = '100%';
    container.style.backgroundColor = 'black';
    container.style.overflow = 'hidden';
    container.style.position = 'relative';
    // Disable browser's default touch gestures to enable custom pinch-to-zoom
    container.style.setProperty('touch-action', 'none');

    final img = web.document.createElement('img') as web.HTMLImageElement;
    img.src = url;
    img.style.position = 'absolute';
    img.style.top = '50%';
    img.style.left = '50%';
    img.style.transform = 'translate(-50%, -50%)';
    img.style.maxWidth = '100%';
    img.style.maxHeight = '100%';
    img.style.objectFit = 'contain';
    img.style.cursor = 'grab';
    img.style.setProperty('touch-action', 'none');
    img.draggable = false;
    // Prevent image context menu on long press
    img.style.setProperty('-webkit-touch-callout', 'none');
    img.style.setProperty('user-select', 'none');

    // Create zoom controller
    final controller = _ImageZoomController(container, img);
    controller.attach();

    container.appendChild(img);
    return container;
  });
}

class _ImageZoomController {
  final web.HTMLDivElement container;
  final web.HTMLImageElement img;

  double scale = 1.0;
  double translateX = 0.0;
  double translateY = 0.0;
  double startX = 0.0;
  double startY = 0.0;
  double startTranslateX = 0.0;
  double startTranslateY = 0.0;
  bool isDragging = false;
  double initialPinchDistance = 0.0;
  double initialScale = 1.0;

  // Double-tap detection
  int _lastTapTime = 0;
  double _lastTapX = 0.0;
  double _lastTapY = 0.0;

  _ImageZoomController(this.container, this.img);

  void updateTransform() {
    img.style.transform =
        'translate(-50%, -50%) translate(${translateX}px, ${translateY}px) scale($scale)';
  }

  void attach() {
    // Mouse wheel zoom
    container.onwheel = _onWheel.toJS;

    // Mouse drag for panning
    img.onmousedown = _onMouseDown.toJS;
    web.document.onmousemove = _onMouseMove.toJS;
    web.document.onmouseup = _onMouseUp.toJS;

    // Double-click to reset zoom
    img.ondblclick = _onDblClick.toJS;

    // Touch support
    container.ontouchstart = _onTouchStart.toJS;
    container.ontouchmove = _onTouchMove.toJS;
    container.ontouchend = _onTouchEnd.toJS;
  }

  void _onWheel(web.WheelEvent e) {
    e.preventDefault();

    final delta = e.deltaY > 0 ? 0.9 : 1.1;
    final newScale = (scale * delta).clamp(0.5, 5.0);

    // Zoom towards mouse position
    final rect = container.getBoundingClientRect();
    final mouseX = e.clientX - rect.left - rect.width / 2;
    final mouseY = e.clientY - rect.top - rect.height / 2;

    translateX = mouseX - (mouseX - translateX) * (newScale / scale);
    translateY = mouseY - (mouseY - translateY) * (newScale / scale);
    scale = newScale;

    updateTransform();
  }

  void _onMouseDown(web.MouseEvent e) {
    if (scale > 1.0) {
      isDragging = true;
      startX = e.clientX.toDouble();
      startY = e.clientY.toDouble();
      startTranslateX = translateX;
      startTranslateY = translateY;
      img.style.cursor = 'grabbing';
      e.preventDefault();
    }
  }

  void _onMouseMove(web.MouseEvent e) {
    if (isDragging) {
      translateX = startTranslateX + (e.clientX.toDouble() - startX);
      translateY = startTranslateY + (e.clientY.toDouble() - startY);
      updateTransform();
    }
  }

  void _onMouseUp(web.MouseEvent e) {
    if (isDragging) {
      isDragging = false;
      img.style.cursor = scale > 1.0 ? 'grab' : 'default';
    }
  }

  void _onDblClick(web.MouseEvent e) {
    scale = 1.0;
    translateX = 0.0;
    translateY = 0.0;
    img.style.cursor = 'grab';
    updateTransform();
  }

  void _onTouchStart(web.TouchEvent e) {
    // Prevent default to stop browser gestures
    e.preventDefault();

    if (e.touches.length == 2) {
      // Pinch gesture start
      isDragging = false;
      final touch1 = e.touches.item(0)!;
      final touch2 = e.touches.item(1)!;
      final dx = touch2.clientX - touch1.clientX;
      final dy = touch2.clientY - touch1.clientY;
      initialPinchDistance = math.sqrt((dx * dx + dy * dy).toDouble());
      initialScale = scale;
    } else if (e.touches.length == 1) {
      final touch = e.touches.item(0)!;
      final now = DateTime.now().millisecondsSinceEpoch;
      final tapX = touch.clientX.toDouble();
      final tapY = touch.clientY.toDouble();

      // Check for double-tap (within 300ms and 50px)
      if (now - _lastTapTime < 300 &&
          (tapX - _lastTapX).abs() < 50 &&
          (tapY - _lastTapY).abs() < 50) {
        // Double-tap detected - toggle zoom
        if (scale > 1.0) {
          // Zoom out to 1x
          scale = 1.0;
          translateX = 0.0;
          translateY = 0.0;
        } else {
          // Zoom in to 2.5x at tap position
          final rect = container.getBoundingClientRect();
          final centerX = tapX - rect.left - rect.width / 2;
          final centerY = tapY - rect.top - rect.height / 2;
          scale = 2.5;
          translateX = -centerX * 1.5;
          translateY = -centerY * 1.5;
        }
        updateTransform();
        _lastTapTime = 0; // Reset to prevent triple-tap
      } else {
        _lastTapTime = now;
        _lastTapX = tapX;
        _lastTapY = tapY;

        // Start pan if zoomed in
        if (scale > 1.0) {
          isDragging = true;
          startX = tapX;
          startY = tapY;
          startTranslateX = translateX;
          startTranslateY = translateY;
        }
      }
    }
  }

  void _onTouchMove(web.TouchEvent e) {
    e.preventDefault();

    if (e.touches.length == 2) {
      // Pinch gesture
      final touch1 = e.touches.item(0)!;
      final touch2 = e.touches.item(1)!;
      final dx = touch2.clientX - touch1.clientX;
      final dy = touch2.clientY - touch1.clientY;
      final currentDistance = math.sqrt((dx * dx + dy * dy).toDouble());

      if (initialPinchDistance > 0) {
        final newScale = (initialScale * currentDistance / initialPinchDistance)
            .clamp(0.5, 5.0);

        // Calculate pinch center for zoom-to-point
        final centerX = (touch1.clientX + touch2.clientX) / 2;
        final centerY = (touch1.clientY + touch2.clientY) / 2;
        final rect = container.getBoundingClientRect();
        final pinchX = centerX - rect.left - rect.width / 2;
        final pinchY = centerY - rect.top - rect.height / 2;

        // Adjust translation to zoom toward pinch center
        translateX = pinchX - (pinchX - translateX) * (newScale / scale);
        translateY = pinchY - (pinchY - translateY) * (newScale / scale);
        scale = newScale;

        updateTransform();
      }
    } else if (isDragging && e.touches.length == 1) {
      // Pan gesture
      final touch = e.touches.item(0)!;
      translateX = startTranslateX + (touch.clientX.toDouble() - startX);
      translateY = startTranslateY + (touch.clientY.toDouble() - startY);
      updateTransform();
    }
  }

  void _onTouchEnd(web.TouchEvent e) {
    isDragging = false;
    if (e.touches.length < 2) {
      initialPinchDistance = 0.0;
    }
  }
}

bool isMobileWeb() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('mobile') ||
      userAgent.contains('android') ||
      userAgent.contains('iphone') ||
      userAgent.contains('ipad');
}

void enterFullscreen() {
  web.document.documentElement?.requestFullscreen();
}

void exitFullscreen() {
  if (web.document.fullscreenElement != null) {
    web.document.exitFullscreen();
  }
}
