import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/s3_browser_service.dart';
import '../platform/video_viewer.dart' as platform_media;
import '../widgets/media/media.dart';

class VideoViewerScreen extends StatefulWidget {
  final S3BrowserService browserService;
  final S3Object videoObject;

  const VideoViewerScreen({
    super.key,
    required this.browserService,
    required this.videoObject,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final url = await widget.browserService.getDownloadUrl(
        widget.videoObject.key,
        expiry: const Duration(hours: 2),
      );

      if (kIsWeb) {
        _viewId = 'video-${DateTime.now().millisecondsSinceEpoch}';
        platform_media.registerVideoElement(_viewId!, url);

        if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        await platform_media.playNativeVideo(url);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: _buildVideoContent()),
          MediaViewerTopBar(title: widget.videoObject.name),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return const MediaLoadingState(message: 'Loading video...');
    }

    if (_hasError) {
      return MediaErrorState(
        title: 'Error loading video',
        message: _errorMessage ?? 'Unknown error',
        onRetry: _initializeVideo,
      );
    }

    if (kIsWeb && _viewId != null) {
      return HtmlElementView(viewType: _viewId!);
    }

    return const SizedBox.shrink();
  }
}
