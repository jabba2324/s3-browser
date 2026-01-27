/// Result of a file operation (download, upload, delete, etc.)
class FileOperationResult {
  final bool success;
  final String message;
  final String? fileName;

  const FileOperationResult({
    required this.success,
    required this.message,
    this.fileName,
  });

  factory FileOperationResult.success(String message, {String? fileName}) =>
      FileOperationResult(success: true, message: message, fileName: fileName);

  factory FileOperationResult.failure(String message, {String? fileName}) =>
      FileOperationResult(success: false, message: message, fileName: fileName);
}
