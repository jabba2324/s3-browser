import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minio/minio.dart';
import 'package:s3_browser/services/s3_browser_service.dart';

void main() {
  test('uploadObjectStream rejects files over maxUploadSizeBytes without touching the network', () async {
    // Bogus/unreachable endpoint: if the size guard didn't short-circuit
    // before the network call, this would hang or throw a socket error
    // instead of FileTooLargeException.
    final client = Minio(
      endPoint: '127.0.0.1',
      port: 1,
      accessKey: 'x',
      secretKey: 'x',
      useSSL: false,
    );
    final service = S3BrowserService(client: client, bucketName: 'test-bucket');

    final oversizedBytes = S3BrowserService.maxUploadSizeBytes + 1;

    await expectLater(
      service.uploadObjectStream(
        'big-file.bin',
        Stream<Uint8List>.empty(),
        oversizedBytes,
      ),
      throwsA(
        isA<FileTooLargeException>()
            .having((e) => e.size, 'size', oversizedBytes)
            .having((e) => e.maxSize, 'maxSize', S3BrowserService.maxUploadSizeBytes),
      ),
    );
  });

  test('uploadObjectStream allows files at or under maxUploadSizeBytes to proceed to the client', () async {
    final client = Minio(
      endPoint: '127.0.0.1',
      port: 1,
      accessKey: 'x',
      secretKey: 'x',
      useSSL: false,
    );
    final service = S3BrowserService(client: client, bucketName: 'test-bucket');

    // An unreachable endpoint means this will fail - the point is *how* it
    // fails: a connection error (proving the guard let it through to the
    // client), not FileTooLargeException.
    await expectLater(
      service.uploadObjectStream(
        'ok-file.bin',
        Stream.value(Uint8List.fromList([1, 2, 3])),
        3,
      ),
      throwsA(isNot(isA<FileTooLargeException>())),
    );
  });
}
