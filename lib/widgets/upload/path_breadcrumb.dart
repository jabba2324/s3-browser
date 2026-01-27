import 'package:flutter/material.dart';

/// Displays the current folder path with an icon
class PathBreadcrumb extends StatelessWidget {
  final String path;

  const PathBreadcrumb({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
