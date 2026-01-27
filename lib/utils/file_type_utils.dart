import 'package:flutter/material.dart';

/// Utility class for file type detection and visual representation
class FileTypeUtils {
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'};
  static const _videoExtensions = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm', '.flv', '.wmv'};

  /// Check if a filename represents an image file
  static bool isImage(String filename) {
    final lowerName = filename.toLowerCase();
    return _imageExtensions.any((ext) => lowerName.endsWith(ext));
  }

  /// Check if a filename represents a video file
  static bool isVideo(String filename) {
    final lowerName = filename.toLowerCase();
    return _videoExtensions.any((ext) => lowerName.endsWith(ext));
  }

  /// Get the appropriate icon for a file or folder
  static IconData getIcon({required bool isFolder, required String filename}) {
    if (isFolder) return Icons.folder;
    if (isImage(filename)) return Icons.photo;
    if (isVideo(filename)) return Icons.video_library;
    return Icons.insert_drive_file;
  }

  /// Get the appropriate color for a file or folder icon
  static Color getIconColor({required bool isFolder, required String filename}) {
    if (isFolder) return Colors.grey[700]!;
    if (isImage(filename)) return Colors.purple;
    if (isVideo(filename)) return Colors.red;
    return Colors.grey;
  }
}
