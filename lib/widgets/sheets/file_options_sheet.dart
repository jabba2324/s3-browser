import 'package:flutter/material.dart';
import '../../services/s3_browser_service.dart';
import '../../utils/file_type_utils.dart';

/// A bottom sheet displaying file action options
class FileOptionsSheet extends StatelessWidget {
  final S3Object object;
  final VoidCallback? onViewPhoto;
  final VoidCallback? onPlayVideo;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final VoidCallback? onDetails;
  final VoidCallback? onDelete;

  const FileOptionsSheet({
    super.key,
    required this.object,
    this.onViewPhoto,
    this.onPlayVideo,
    this.onDownload,
    this.onShare,
    this.onRename,
    this.onDetails,
    this.onDelete,
  });

  /// Shows the file options sheet
  static Future<void> show({
    required BuildContext context,
    required S3Object object,
    VoidCallback? onViewPhoto,
    VoidCallback? onPlayVideo,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onRename,
    VoidCallback? onDetails,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => FileOptionsSheet(
        object: object,
        onViewPhoto: onViewPhoto,
        onPlayVideo: onPlayVideo,
        onDownload: onDownload,
        onShare: onShare,
        onRename: onRename,
        onDetails: onDetails,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = FileTypeUtils.isImage(object.name);
    final isVideo = FileTypeUtils.isVideo(object.name);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          if (isImage && onViewPhoto != null)
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('View Photo'),
              onTap: () {
                Navigator.pop(context);
                onViewPhoto!();
              },
            ),
          if (isVideo && onPlayVideo != null)
            ListTile(
              leading: const Icon(Icons.play_circle),
              title: const Text('Play Video'),
              onTap: () {
                Navigator.pop(context);
                onPlayVideo!();
              },
            ),
          if (onDownload != null)
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                onDownload!();
              },
            ),
          if (onShare != null)
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                onShare!();
              },
            ),
          if (onRename != null)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename!();
              },
            ),
          if (onDetails != null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                onDetails!();
              },
            ),
          if (onDelete != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          ],
        ],
        ),
      ),
    );
  }
}
