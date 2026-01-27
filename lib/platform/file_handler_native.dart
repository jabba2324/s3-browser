import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveToTempFile(String filename, List<int> bytes) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsBytes(bytes);
  return tempFile.path;
}
