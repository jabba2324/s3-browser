import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/services/file_operations_service.dart';
import 'package:s3_browser/services/s3_browser_service.dart';

// This file only covers the FileOperationsService methods whose sole
// dependency is S3BrowserService: deleteFile, renameFile, createFolder,
// uploadBytes. downloadFile/shareFile/shareFiles/uploadFile also call
// url_launcher/share_plus/file_picker/http directly - real plugin channels
// not worth mocking here - so they're intentionally not covered by this file.
class MockS3BrowserService extends Mock implements S3BrowserService {}

void main() {
  late MockS3BrowserService browserService;
  late FileOperationsService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    browserService = MockS3BrowserService();
    service = FileOperationsService(browserService: browserService);
  });

  final file = S3Object(name: 'report.pdf', key: 'report.pdf', isFolder: false);

  group('deleteFile', () {
    test('succeeds when the client call succeeds', () async {
      when(() => browserService.deleteObject(any())).thenAnswer((_) async {});

      final result = await service.deleteFile(file);

      expect(result.success, isTrue);
      expect(result.message, 'Deleted "report.pdf"');
    });

    test('wraps a thrown exception with the error prefix', () async {
      when(() => browserService.deleteObject(any())).thenThrow(Exception('network down'));

      final result = await service.deleteFile(file);

      expect(result.success, isFalse);
      expect(result.message, contains('Error deleting file'));
      expect(result.message, contains('network down'));
    });
  });

  group('renameFile', () {
    test('succeeds and reports the new name', () async {
      when(() => browserService.renameObject(any(), any())).thenAnswer((_) async {});

      final result = await service.renameFile(file, 'final.pdf', '');

      expect(result.success, isTrue);
      expect(result.message, 'Renamed to "final.pdf"');
      expect(result.fileName, 'final.pdf');
    });

    test('prefixes the destination key with the current folder', () async {
      when(() => browserService.renameObject(any(), any())).thenAnswer((_) async {});

      await service.renameFile(file, 'final.pdf', 'archive/');

      verify(() => browserService.renameObject('report.pdf', 'archive/final.pdf')).called(1);
    });

    test('wraps a thrown exception with the error prefix', () async {
      when(() => browserService.renameObject(any(), any())).thenThrow(Exception('conflict'));

      final result = await service.renameFile(file, 'final.pdf', '');

      expect(result.success, isFalse);
      expect(result.message, contains('Error renaming file'));
    });
  });

  group('createFolder', () {
    test('uploads a zero-byte marker at the trailing-slash key', () async {
      when(() => browserService.uploadObject(any(), any())).thenAnswer((_) async {});

      final result = await service.createFolder('photos/', 'vacation');

      expect(result.success, isTrue);
      verify(() => browserService.uploadObject('photos/vacation/', Uint8List(0))).called(1);
    });

    test('wraps a thrown exception with the error prefix', () async {
      when(() => browserService.uploadObject(any(), any())).thenThrow(Exception('denied'));

      final result = await service.createFolder('', 'vacation');

      expect(result.success, isFalse);
      expect(result.message, contains('Error creating folder'));
    });
  });

  group('uploadBytes', () {
    test('succeeds and reports the file name', () async {
      when(() => browserService.uploadObject(any(), any())).thenAnswer((_) async {});

      final result = await service.uploadBytes('key.txt', Uint8List.fromList([1, 2, 3]), 'key.txt');

      expect(result.success, isTrue);
      expect(result.message, 'Uploaded "key.txt"');
    });

    test('wraps a thrown exception with the error prefix', () async {
      when(() => browserService.uploadObject(any(), any())).thenThrow(Exception('timeout'));

      final result = await service.uploadBytes('key.txt', Uint8List.fromList([1, 2, 3]), 'key.txt');

      expect(result.success, isFalse);
      expect(result.message, contains('Error uploading'));
    });
  });
}
