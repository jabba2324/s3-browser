import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/file_operation_result.dart';
import '../platform/file_handler.dart';
import '../utils/format_utils.dart';
import 's3_browser_service.dart';

export '../models/file_operation_result.dart';

/// Service for handling file operations (download, share, delete, rename, upload)
class FileOperationsService {
  final S3BrowserService browserService;

  FileOperationsService({required this.browserService});

  /// Runs [body], converting a thrown exception into a [FileOperationResult.failure]
  /// prefixed with [errorPrefix] - the shape every operation below otherwise
  /// repeated by hand.
  Future<FileOperationResult> _guard(
    Future<FileOperationResult> Function() body, {
    required String errorPrefix,
    String? fileName,
  }) async {
    try {
      return await body();
    } catch (e) {
      return FileOperationResult.failure('$errorPrefix: $e', fileName: fileName);
    }
  }

  /// Downloads/opens a file by launching its URL
  Future<FileOperationResult> downloadFile(S3Object object) {
    return _guard(errorPrefix: 'Error', fileName: object.name, () async {
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
    });
  }

  /// Shares a file - copies URL to clipboard on web, native share on mobile
  Future<FileOperationResult> shareFile(
    S3Object object, {
    Rect? sharePositionOrigin,
  }) {
    return _guard(errorPrefix: 'Error sharing', fileName: object.name, () async {
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

        await SharePlus.instance.share(ShareParams(
          files: [XFile(tempPath)],
          subject: object.name,
          sharePositionOrigin: sharePositionOrigin,
        ));

        return FileOperationResult.success(
          'Shared "${object.name}"',
          fileName: object.name,
        );
      }
    });
  }

  /// Shares multiple files via native share sheet
  Future<FileOperationResult> shareFiles(
    List<S3Object> objects, {
    Rect? sharePositionOrigin,
  }) {
    if (objects.isEmpty) {
      return Future.value(FileOperationResult.failure('No files selected to share'));
    }
    return _guard(errorPrefix: 'Error sharing', () async {
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

      await SharePlus.instance.share(ShareParams(
        files: tempFiles,
        sharePositionOrigin: sharePositionOrigin,
      ));

      if (failures.isEmpty) {
        final label = tempFiles.length == 1 ? '"${objects.first.name}"' : '${tempFiles.length} files';
        return FileOperationResult.success('Shared $label');
      } else {
        return FileOperationResult.success(
          'Shared ${tempFiles.length} file${tempFiles.length == 1 ? '' : 's'}, ${failures.length} failed',
        );
      }
    });
  }

  /// Deletes an object from S3
  Future<FileOperationResult> deleteFile(S3Object object) {
    return _guard(errorPrefix: 'Error deleting file', fileName: object.name, () async {
      await browserService.deleteObject(object.key);
      return FileOperationResult.success(
        'Deleted "${object.name}"',
        fileName: object.name,
      );
    });
  }

  /// Renames an object in S3
  Future<FileOperationResult> renameFile(
    S3Object object,
    String newName,
    String currentPrefix,
  ) {
    return _guard(errorPrefix: 'Error renaming file', fileName: object.name, () async {
      final newKey = currentPrefix + newName;
      await browserService.renameObject(object.key, newKey);
      return FileOperationResult.success(
        'Renamed to "$newName"',
        fileName: newName,
      );
    });
  }

  /// Picks and uploads one or more files to S3
  /// Returns null if user cancelled the picker
  Future<FileOperationResult?> uploadFile(String currentPrefix) async {
    try {
      final files = await FilePicker.pickFiles();

      if (files.isEmpty) {
        return null; // User cancelled
      }

      int succeeded = 0;
      final failures = <String>[];
      final tooLarge = <String>[];

      for (final file in files) {
        try {
          final size = file.lengthSync() ?? await file.length();
          if (size == null) {
            failures.add(file.name);
            continue;
          }
          await browserService.uploadObjectStream(
            currentPrefix + file.name,
            file.readAsByteStream(),
            size,
          );
          succeeded++;
        } on FileTooLargeException {
          tooLarge.add(file.name);
        } catch (_) {
          failures.add(file.name);
        }
      }

      if (failures.isEmpty && tooLarge.isEmpty) {
        final label = succeeded == 1 ? '"${files.first.name}"' : '$succeeded files';
        return FileOperationResult.success('Uploaded $label');
      }

      final parts = <String>[];
      if (succeeded > 0) parts.add('Uploaded $succeeded file(s)');
      if (tooLarge.isNotEmpty) {
        final maxSize = FormatUtils.fileSize(S3BrowserService.maxUploadSizeBytes);
        parts.add('${tooLarge.length} too large (max $maxSize)');
      }
      if (failures.isNotEmpty) parts.add('${failures.length} failed');

      final message = parts.join(', ');
      return succeeded == 0
          ? FileOperationResult.failure(message)
          : FileOperationResult.success(message);
    } catch (e) {
      return FileOperationResult.failure('Error uploading: $e');
    }
  }

  /// Creates a folder in S3 by uploading a zero-byte object with a trailing slash
  Future<FileOperationResult> createFolder(
    String currentPrefix,
    String folderName,
  ) {
    return _guard(errorPrefix: 'Error creating folder', fileName: folderName, () async {
      final objectKey = '$currentPrefix$folderName/';
      await browserService.uploadObject(objectKey, Uint8List(0));
      return FileOperationResult.success(
        'Created folder "$folderName"',
        fileName: folderName,
      );
    });
  }

  /// Uploads raw bytes to S3
  Future<FileOperationResult> uploadBytes(
    String objectKey,
    Uint8List bytes,
    String fileName,
  ) {
    return _guard(errorPrefix: 'Error uploading', fileName: fileName, () async {
      await browserService.uploadObject(objectKey, bytes);
      return FileOperationResult.success(
        'Uploaded "$fileName"',
        fileName: fileName,
      );
    });
  }
}
