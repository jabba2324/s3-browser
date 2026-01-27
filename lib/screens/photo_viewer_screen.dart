import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/photo_viewer_controller.dart';
import '../services/s3_browser_service.dart';
import '../platform/photo_viewer.dart' as platform;
import '../widgets/media/media.dart';

class PhotoViewerScreen extends StatefulWidget {
  final S3BrowserService browserService;
  final List<S3Object> images;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.browserService,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PhotoViewerController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewerController(
      browserService: widget.browserService,
      images: widget.images,
      initialIndex: widget.initialIndex,
    );
    _controller.loadImage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.exitFullscreen();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight && _controller.hasNext) {
        _controller.navigateNext();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _controller.hasPrevious) {
        _controller.navigatePrevious();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_controller.isFullscreen) {
          _controller.toggleFullscreen();
        } else {
          Navigator.pop(context);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _controller.toggleFullscreen();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _controller.onUserInteraction(),
            child: GestureDetector(
              onTap: _controller.onUserInteraction,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: _buildImageContent()),
                  MediaViewerTopBar(
                    title: _controller.currentImage.name,
                    subtitle: '${_controller.currentIndex + 1} of ${_controller.totalCount}',
                    visible: _controller.showControls,
                    actions: [
                      if (!kIsWeb || !platform.isMobileWeb())
                        IconButton(
                          icon: Icon(_controller.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                          color: Colors.white,
                          onPressed: _controller.toggleFullscreen,
                          iconSize: 28,
                          tooltip: _controller.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                        ),
                    ],
                  ),
                  if (_controller.hasPrevious)
                    Positioned(
                      left: 16 + MediaQuery.of(context).padding.left,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: MediaNavigationButton(
                          icon: Icons.chevron_left,
                          visible: _controller.showControls,
                          onPressed: _controller.navigatePrevious,
                        ),
                      ),
                    ),
                  if (_controller.hasNext)
                    Positioned(
                      right: 16 + MediaQuery.of(context).padding.right,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: MediaNavigationButton(
                          icon: Icons.chevron_right,
                          visible: _controller.showControls,
                          onPressed: _controller.navigateNext,
                        ),
                      ),
                    ),
                  MediaNavigationBar(
                    currentIndex: _controller.currentIndex,
                    totalCount: _controller.totalCount,
                    visible: _controller.showControls,
                    onPrevious: _controller.navigatePrevious,
                    onNext: _controller.navigateNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_controller.isLoading) {
      return const MediaLoadingState(message: 'Loading image...');
    }

    if (_controller.error != null) {
      return MediaErrorState(
        title: 'Error loading image',
        message: _controller.error,
        onRetry: _controller.loadImage,
      );
    }

    if (_controller.currentImageUrl == null) {
      return const Text(
        'No image URL',
        style: TextStyle(color: Colors.white70),
      );
    }

    if (kIsWeb && _controller.imageViewId != null) {
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: HtmlElementView(viewType: _controller.imageViewId!),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Image.network(
          _controller.currentImageUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.white54),
                SizedBox(height: 16),
                Text('Failed to load image', style: TextStyle(color: Colors.white70)),
              ],
            );
          },
        ),
      ),
    );
  }
}
