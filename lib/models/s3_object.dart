/// Represents an object (file or folder) in S3
class S3Object {
  final String name;
  final String key;
  final int? size;
  final DateTime? lastModified;
  final bool isFolder;

  S3Object({
    required this.name,
    required this.key,
    this.size,
    this.lastModified,
    required this.isFolder,
  });
}
