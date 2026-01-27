import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/s3_browser_service.dart';
import '../platform/photo_viewer.dart' as platform;

/// Controller for photo viewer state and navigation logic
class PhotoViewerController extends ChangeNotifier {
  final S3BrowserService browserService;
  final List<S3Object> images;

  PhotoViewerController({
    required this.browserService,
    required this.images,
    required int initialIndex,
  }) : _currentIndex = initialIndex;

  // State
  int _currentIndex;
  String? _currentImageUrl;
  bool _isLoading = true;
  String? _error;
  bool _isFullscreen = false;
  bool _showControls = true;
  String? _imageViewId;
  Timer? _hideControlsTimer;

  static const _controlsHideDelay = Duration(seconds: 3);

  // Getters
  int get currentIndex => _currentIndex;
  String? get currentImageUrl => _currentImageUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isFullscreen => _isFullscreen;
  bool get showControls => _showControls;
  String? get imageViewId => _imageViewId;

  S3Object get currentImage => images[_currentIndex];
  bool get hasNext => _currentIndex < images.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get totalCount => images.length;

  /// Load the current image URL
  Future<void> loadImage() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = await browserService.getDownloadUrl(currentImage.key);

      if (kIsWeb) {
        _imageViewId = 'image-${DateTime.now().millisecondsSinceEpoch}';
        platform.registerImageElement(_imageViewId!, url);
      }

      _currentImageUrl = url;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Navigate to next image
  void navigateNext() {
    if (hasNext) {
      _currentIndex++;
      loadImage();
    }
  }

  /// Navigate to previous image
  void navigatePrevious() {
    if (hasPrevious) {
      _currentIndex--;
      loadImage();
    }
  }

  /// Toggle fullscreen mode
  Future<void> toggleFullscreen() async {
    if (kIsWeb) {
      if (!_isFullscreen) {
        platform.enterFullscreen();
      } else {
        platform.exitFullscreen();
      }
      _isFullscreen = !_isFullscreen;
      notifyListeners();
    } else {
      _isFullscreen = !_isFullscreen;
      notifyListeners();
      if (_isFullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    showControlsTemporarily();
  }

  /// Show controls temporarily then hide after delay
  void showControlsTemporarily() {
    _showControls = true;
    notifyListeners();
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (_isFullscreen) {
        _showControls = false;
        notifyListeners();
      }
    });
  }

  /// Handle user interaction (show controls if in fullscreen)
  void onUserInteraction() {
    if (_isFullscreen) {
      showControlsTemporarily();
    }
  }

  /// Exit fullscreen mode (call on dispose)
  void exitFullscreen() {
    if (kIsWeb) {
      platform.exitFullscreen();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }
}
