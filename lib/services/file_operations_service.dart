import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/file_operation_result.dart';
import '../platform/file_handler.dart';
import 's3_browser_service.dart';

export '../models/file_operation_result.dart';

/// Service for handling file operations (download, share, delete, rename, upload)
class FileOperationsService {
  final S3BrowserService browserService;

  FileOperationsService({required this.browserService});

  /// Downloads/opens a file by launching its URL
  Future<FileOperationResult> downloadFile(S3Object object) async {
    try {
      final url = await browserService.getDownloadUrl(object.key);
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return FileOperationResult.success(
          'Opening "${object.name}"',
          fileName: object.name,
        );
      } else {
        return FileOperationResult.failure(
          'Could not open download URL',
          fileName: object.name,
        );
      }
    } catch (e) {
      return FileOperationResult.failure(
        'Error: ${e.toString()}',
        fileName: object.name,
      );
    }
  }

  /// Shares a file - copies URL to clipboard on web, native share on mobile
  Future<FileOperationResult> shareFile(
    S3Object object, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      final url = await browserService.getDownloadUrl(object.key);

      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: url));
        return FileOperationResult.success(
          'Link copied to clipboard',
          fileName: object.name,
        );
      } else {
        // Download file for native sharing
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download file');
        }

        final tempPath = await saveToTempFile(object.name, response.bodyBytes);

        await Share.shareXFiles(
          [XFile(tempPath)],
          subject: object.name,
          sharePositionOrigin: sharePositionOrigin,
        );

        return FileOperationResult.success(
          'Shared "${object.name}"',
          fileName: object.name,
        );
      }
    } catch (e) {
      return FileOperationResult.failure(
        'Error sharing: ${e.toString()}',
        fileName: object.name,
      );
    }
  }

  /// Deletes an object from S3
  Future<FileOperationResult> deleteFile(S3Object object) async {
    try {
      await browserService.deleteObject(object.key);
      return FileOperationResult.success(
        'Deleted "${object.name}"',
        fileName: object.name,
      );
    } catch (e) {
      return FileOperationResult.failure(
        'Error deleting file: ${e.toString()}',
        fileName: object.name,
      );
    }
  }

  /// Renames an object in S3
  Future<FileOperationResult> renameFile(
    S3Object object,
    String newName,
    String currentPrefix,
  ) async {
    try {
      final newKey = currentPrefix + newName;
      await browserService.renameObject(object.key, newKey);
      return FileOperationResult.success(
        'Renamed to "$newName"',
        fileName: newName,
      );
    } catch (e) {
      return FileOperationResult.failure(
        'Error renaming file: ${e.toString()}',
        fileName: object.name,
      );
    }
  }

  /// Picks and uploads a file to S3
  /// Returns null if user cancelled the picker
  Future<FileOperationResult?> uploadFile(String currentPrefix) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return FileOperationResult.failure(
          'Could not read file data',
          fileName: file.name,
        );
      }

      final objectKey = currentPrefix + file.name;
      await browserService.uploadObject(objectKey, file.bytes!);

      return FileOperationResult.success(
        'Uploaded "${file.name}"',
        fileName: file.name,
      );
    } catch (e) {
      return FileOperationResult.failure('Error uploading: ${e.toString()}');
    }
  }

  /// Uploads raw bytes to S3
  Future<FileOperationResult> uploadBytes(
    String objectKey,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      await browserService.uploadObject(objectKey, bytes);
      return FileOperationResult.success(
        'Uploaded "$fileName"',
        fileName: fileName,
      );
    } catch (e) {
      return FileOperationResult.failure(
        'Error uploading: ${e.toString()}',
        fileName: fileName,
      );
    }
  }
}
