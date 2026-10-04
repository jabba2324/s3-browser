/// Shared input validators for dialogs
class Validators {
  /// Validates a name for an S3 object/folder: non-empty and no path separator
  static String? objectName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
    if (value.contains('/')) return 'Name cannot contain /';
    return null;
  }
}
