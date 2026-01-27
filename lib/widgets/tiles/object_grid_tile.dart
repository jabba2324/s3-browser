import 'package:flutter/material.dart';
import '../../services/s3_browser_service.dart';
import '../../utils/file_type_utils.dart';
import '../../utils/format_utils.dart';

/// A grid tile widget for displaying S3 objects (files and folders)
class ObjectGridTile extends StatelessWidget {
  final S3Object object;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsPressed;

  const ObjectGridTile({
    super.key,
    required this.object,
    this.onTap,
    this.onLongPress,
    this.onOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        FileTypeUtils.getIcon(isFolder: object.isFolder, filename: object.name),
                        size: 48,
                        color: FileTypeUtils.getIconColor(isFolder: object.isFolder, filename: object.name),
                      ),
                    ),
                    if (!object.isFolder && onOptionsPressed != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: onOptionsPressed,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    object.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!object.isFolder)
                    Text(
                      FormatUtils.fileSize(object.size),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
