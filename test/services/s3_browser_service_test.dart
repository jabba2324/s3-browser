import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minio/minio.dart';
// `minio`'s result/data model classes (ListObjectsResult, CopyObjectResult,
// CopyConditions, its own Object) aren't part of the public `minio.dart`
// export surface, only used as return/field types - reach into src/ to
// construct them for these tests.
import 'package:minio/src/minio_models.dart' as minio_models;
import 'package:minio/src/minio_models_generated.dart' as minio_gen;
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/services/s3_browser_service.dart';

class MockMinio extends Mock implements Minio {}

class FakeCopyConditions extends Fake implements minio_models.CopyConditions {}

void main() {
  late MockMinio client;
  late S3BrowserService service;

  setUpAll(() {
    registerFallbackValue(FakeCopyConditions());
    registerFallbackValue(const Stream<Uint8List>.empty());
  });

  setUp(() {
    client = MockMinio();
    service = S3BrowserService(client: client, bucketName: 'test-bucket');
  });

  group('copyObject', () {
    test('URL-encodes a source key with special characters, preserving slashes', () async {
      when(() => client.copyObject(any(), any(), any()))
          .thenAnswer((_) async => minio_gen.CopyObjectResult(null, DateTime.now()));

      await service.copyObject('folder/a b & c.txt', 'dest.txt');

      final captured = verify(() => client.copyObject('test-bucket', 'dest.txt', captureAny())).captured;
      expect(captured.single, '/test-bucket/folder/a%20b%20%26%20c.txt');
    });

    test('leaves a plain key unchanged', () async {
      when(() => client.copyObject(any(), any(), any()))
          .thenAnswer((_) async => minio_gen.CopyObjectResult(null, DateTime.now()));

      await service.copyObject('report.pdf', 'archive.pdf');

      verify(() => client.copyObject('test-bucket', 'archive.pdf', '/test-bucket/report.pdf')).called(1);
    });
  });

  group('renameObject', () {
    test('copies then deletes the source, in that order', () async {
      when(() => client.copyObject(any(), any(), any()))
          .thenAnswer((_) async => minio_gen.CopyObjectResult(null, DateTime.now()));
      when(() => client.removeObject(any(), any())).thenAnswer((_) async {});

      await service.renameObject('old name.txt', 'new.txt');

      verify(() => client.copyObject('test-bucket', 'new.txt', '/test-bucket/old%20name.txt')).called(1);
      verify(() => client.removeObject('test-bucket', 'old name.txt')).called(1);
    });
  });

  group('listObjects', () {
    test('partitions a single level into folders and files, skipping nested and empty markers', () async {
      when(() => client.listObjects(any(), prefix: any(named: 'prefix'))).thenAnswer((_) => Stream.value(
            minio_models.ListObjectsResult(
              prefixes: ['photos/'],
              objects: [
                minio_gen.Object(null, 'report.pdf', DateTime(2024, 1, 1), null, 1234, null),
                minio_gen.Object(null, 'photos/', DateTime(2024, 1, 1), null, 0, null), // folder marker
                minio_gen.Object(null, 'photos/beach.jpg', DateTime(2024, 1, 1), null, 999, null), // nested, not this level
              ],
            ),
          ));

      final result = await service.listObjects();

      expect(result, hasLength(2));
      final folder = result.firstWhere((o) => o.isFolder);
      expect(folder.name, 'photos');
      final file = result.firstWhere((o) => !o.isFolder);
      expect(file.name, 'report.pdf');
      expect(file.size, 1234);
    });

    test('computes names relative to a non-empty prefix', () async {
      when(() => client.listObjects(any(), prefix: any(named: 'prefix'))).thenAnswer((_) => Stream.value(
            minio_models.ListObjectsResult(
              prefixes: ['docs/archive/'],
              objects: [
                minio_gen.Object(null, 'docs/report.pdf', DateTime(2024, 1, 1), null, 1234, null),
              ],
            ),
          ));

      final result = await service.listObjects(prefix: 'docs/');

      final folder = result.firstWhere((o) => o.isFolder);
      expect(folder.name, 'archive');
      final file = result.firstWhere((o) => !o.isFolder);
      expect(file.name, 'report.pdf');
    });
  });

  group('uploadObjectStream size guard', () {
    // Kept as a real-but-unreachable-client test (not mocked) - see
    // test/upload_size_guard_test.dart for the existing coverage of this
    // exact behavior with that pattern.
    test('rejects files over maxUploadSizeBytes without calling the client', () async {
      final oversized = S3BrowserService.maxUploadSizeBytes + 1;

      await expectLater(
        service.uploadObjectStream('big.bin', const Stream<Uint8List>.empty(), oversized),
        throwsA(isA<FileTooLargeException>()),
      );

      verifyNever(() => client.putObject(any(), any(), any(), size: any(named: 'size')));
    });
  });
}
