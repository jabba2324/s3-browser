import 'package:flutter/material.dart';

/// Banner showing the number of files ready to upload
class FileCountBanner extends StatelessWidget {
  final int fileCount;

  const FileCountBanner({
    super.key,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          const Icon(Icons.file_present),
          const SizedBox(width: 8),
          Text(
            '$fileCount file(s) ready to upload',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
