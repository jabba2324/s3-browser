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

  /// Shares multiple files via native share sheet
  Future<FileOperationResult> shareFiles(
    List<S3Object> objects, {
    Rect? sharePositionOrigin,
  }) async {
    if (objects.isEmpty) {
      return FileOperationResult.failure('No files selected to share');
    }
    try {
      final tempFiles = <XFile>[];
      final failures = <String>[];

      for (final object in objects) {
        try {
          final url = await browserService.getDownloadUrl(object.key);
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) throw Exception('Download failed');
          final tempPath = await saveToTempFile(object.name, response.bodyBytes);
          tempFiles.add(XFile(tempPath));
        } catch (_) {
          failures.add(object.name);
        }
      }

      if (tempFiles.isEmpty) {
        return FileOperationResult.failure('Failed to prepare files for sharing');
      }

      await Share.shareXFiles(tempFiles, sharePositionOrigin: sharePositionOrigin);

      if (failures.isEmpty) {
        final label = tempFiles.length == 1 ? '"${objects.first.name}"' : '${tempFiles.length} files';
        return FileOperationResult.success('Shared $label');
      } else {
        return FileOperationResult.success(
          'Shared ${tempFiles.length} file${tempFiles.length == 1 ? '' : 's'}, ${failures.length} failed',
        );
      }
    } catch (e) {
      return FileOperationResult.failure('Error sharing: ${e.toString()}');
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

  /// Picks and uploads one or more files to S3
  /// Returns null if user cancelled the picker
  Future<FileOperationResult?> uploadFile(String currentPrefix) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      int succeeded = 0;
      final failures = <String>[];

      for (final file in result.files) {
        if (file.bytes == null) {
          failures.add(file.name);
          continue;
        }
        try {
          await browserService.uploadObject(currentPrefix + file.name, file.bytes!);
          succeeded++;
        } catch (_) {
          failures.add(file.name);
        }
      }

      if (failures.isEmpty) {
        final label = succeeded == 1 ? '"${result.files.first.name}"' : '$succeeded files';
        return FileOperationResult.success('Uploaded $label');
      } else if (succeeded == 0) {
        return FileOperationResult.failure('Failed to upload ${failures.length} file(s)');
      } else {
        return FileOperationResult.success(
          'Uploaded $succeeded file(s), ${failures.length} failed',
        );
      }
    } catch (e) {
      return FileOperationResult.failure('Error uploading: ${e.toString()}');
    }
  }

  /// Creates a folder in S3 by uploading a zero-byte object with a trailing slash
  Future<FileOperationResult> createFolder(
    String currentPrefix,
    String folderName,
  ) async {
    try {
      final objectKey = '$currentPrefix$folderName/';
      await browserService.uploadObject(objectKey, Uint8List(0));
      return FileOperationResult.success(
        'Created folder "$folderName"',
        fileName: folderName,
      );
    } catch (e) {
      return FileOperationResult.failure(
        'Error creating folder: ${e.toString()}',
        fileName: folderName,
      );
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
