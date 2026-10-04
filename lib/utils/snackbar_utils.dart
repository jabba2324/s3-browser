import 'package:flutter/material.dart';

/// Shared SnackBar presentation for success/failure feedback
class SnackbarUtils {
  static void showResult(
    BuildContext context,
    String message, {
    required bool success,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: duration,
      ),
    );
  }
}
