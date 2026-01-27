import 'package:flutter/material.dart';

/// A dark-themed loading state for media viewers
class MediaLoadingState extends StatelessWidget {
  final String message;

  const MediaLoadingState({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
