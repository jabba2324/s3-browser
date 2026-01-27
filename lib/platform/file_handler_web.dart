// Stub for web - file operations not needed on web
Future<String> saveToTempFile(String filename, List<int> bytes) async {
  throw UnsupportedError('File operations not supported on web');
}
