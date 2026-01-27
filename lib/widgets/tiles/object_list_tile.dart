import 'package:flutter/material.dart';
import '../../services/s3_browser_service.dart';
import '../../utils/file_type_utils.dart';
import '../../utils/format_utils.dart';

/// A list tile widget for displaying S3 objects (files and folders)
class ObjectListTile extends StatelessWidget {
  final S3Object object;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsPressed;

  const ObjectListTile({
    super.key,
    required this.object,
    this.onTap,
    this.onOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ListTile(
        leading: Icon(
          FileTypeUtils.getIcon(isFolder: object.isFolder, filename: object.name),
          size: 40,
          color: FileTypeUtils.getIconColor(isFolder: object.isFolder, filename: object.name),
        ),
        title: Text(
          object.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: object.isFolder
            ? const Text('Folder')
            : Text(
                '${FormatUtils.fileSize(object.size)} • ${FormatUtils.dateTime(object.lastModified)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
        trailing: object.isFolder
            ? const Icon(Icons.chevron_right)
            : IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onOptionsPressed,
              ),
        onTap: onTap,
      ),
    );
  }
}
