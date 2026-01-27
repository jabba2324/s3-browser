import 'dart:typed_data';
import 'package:minio/minio.dart';
import '../models/s3_object.dart';

export '../models/s3_object.dart';

class S3BrowserService {
  final Minio client;
  final String bucketName;

  S3BrowserService({
    required this.client,
    required this.bucketName,
  });

  /// List objects and folders at the given prefix (path)
  /// Returns a list of S3Object representing files and folders
  Future<List<S3Object>> listObjects({String prefix = ''}) async {
    final objects = <S3Object>[];
    final seenFolders = <String>{};
    final seenFiles = <String>{};

    // List ALL objects with the given prefix
    final stream = client.listObjects(
      bucketName,
      prefix: prefix,
    );

    await for (final result in stream) {
      // Handle common prefixes (folders)
      if (result.prefixes.isNotEmpty) {
        for (final prefixPath in result.prefixes) {
          // Extract folder name from the prefix
          String folderName;
          if (prefix.isEmpty) {
            // Remove trailing slash
            folderName = prefixPath.endsWith('/')
                ? prefixPath.substring(0, prefixPath.length - 1)
                : prefixPath;
          } else {
            // Get the part after our current prefix
            final relativePath = prefixPath.substring(prefix.length);
            folderName = relativePath.endsWith('/')
                ? relativePath.substring(0, relativePath.length - 1)
                : relativePath;
          }

          if (folderName.isNotEmpty && !seenFolders.contains(folderName)) {
            seenFolders.add(folderName);
            objects.add(S3Object(
              name: folderName,
              key: prefixPath,
              isFolder: true,
            ));
          }
        }
      }

      // Handle objects (files)
      if (result.objects.isNotEmpty) {
        for (final obj in result.objects) {
          if (obj.key == null || obj.key!.isEmpty) continue;

          // Skip the prefix itself if it's returned
          if (obj.key == prefix) {
            continue;
          }

          // Get the path relative to current prefix
          String relativePath;
          if (prefix.isEmpty) {
            relativePath = obj.key!;
          } else {
            if (obj.key!.startsWith(prefix)) {
              relativePath = obj.key!.substring(prefix.length);
            } else {
              continue;
            }
          }

          // Skip empty paths or folder markers
          if (relativePath.isEmpty || relativePath.endsWith('/')) {
            continue;
          }

          // Only show files in the current directory (no slashes in relative path)
          if (!relativePath.contains('/')) {
            if (!seenFiles.contains(relativePath)) {
              seenFiles.add(relativePath);
              objects.add(S3Object(
                name: relativePath,
                key: obj.key!,
                size: obj.size,
                lastModified: obj.lastModified,
                isFolder: false,
              ));
            }
          }
        }
      }
    }

    // Sort: folders first, then files, both alphabetically
    objects.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return objects;
  }

  /// Get a presigned URL for downloading an object
  Future<String> getDownloadUrl(String objectKey, {Duration expiry = const Duration(hours: 1)}) async {
    return await client.presignedGetObject(bucketName, objectKey, expires: expiry.inSeconds);
  }

  /// Delete an object from S3
  Future<void> deleteObject(String objectKey) async {
    await client.removeObject(bucketName, objectKey);
  }

  /// Copy an object to a new key
  Future<void> copyObject(String sourceKey, String destinationKey) async {
    await client.copyObject(bucketName, destinationKey, '/$bucketName/$sourceKey');
  }

  /// Rename an object (copy to new key, then delete original)
  Future<void> renameObject(String sourceKey, String destinationKey) async {
    await copyObject(sourceKey, destinationKey);
    await deleteObject(sourceKey);
  }

  /// Upload a file to S3
  Future<void> uploadObject(String objectKey, Uint8List data) async {
    await client.putObject(
      bucketName,
      objectKey,
      Stream.value(data),
      size: data.length,
    );
  }
}
