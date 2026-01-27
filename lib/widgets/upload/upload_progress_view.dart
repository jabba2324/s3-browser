import 'package:flutter/material.dart';

/// Displays upload progress with file count and progress bar
class UploadProgressView extends StatelessWidget {
  final int uploadedCount;
  final int totalCount;
  final double progress;

  const UploadProgressView({
    super.key,
    required this.uploadedCount,
    required this.totalCount,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Uploading $uploadedCount of $totalCount files...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}
