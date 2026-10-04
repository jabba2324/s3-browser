import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minio/minio.dart';
import 'package:minio/src/minio_models.dart' as minio_models;
import 'package:minio/src/minio_models_generated.dart' as minio_gen;
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/screens/photo_viewer_screen.dart';
import 'package:s3_browser/screens/s3_browser_screen.dart';
import 'package:s3_browser/screens/video_viewer_screen.dart';
import 'package:s3_browser/services/auth_s3_service.dart';

class MockAuthS3Service extends Mock implements AuthS3Service {}

class MockMinio extends Mock implements Minio {}

// This covers Dart-side tap routing only (does tapping a tile push the
// right screen?) - it can't prove the native video player actually
// presents, since that goes through a real MethodChannel this test doesn't
// mock. See ios/RunnerTests for the native half of that coverage.
void main() {
  late MockAuthS3Service authS3Service;
  late MockMinio minioClient;

  setUp(() {
    authS3Service = MockAuthS3Service();
    minioClient = MockMinio();

    when(() => authS3Service.client).thenReturn(minioClient);
    when(() => authS3Service.bucketName).thenReturn('test-bucket');

    when(() => minioClient.listObjects(any(), prefix: any(named: 'prefix'))).thenAnswer(
      (_) => Stream.value(
        minio_models.ListObjectsResult(
          prefixes: const [],
          objects: [
            minio_gen.Object(null, 'photo.jpg', DateTime(2024, 1, 1), null, 100, null),
            minio_gen.Object(null, 'clip.mp4', DateTime(2024, 1, 1), null, 200, null),
            minio_gen.Object(null, 'report.pdf', DateTime(2024, 1, 1), null, 300, null),
          ],
        ),
      ),
    );
    when(() => minioClient.presignedGetObject(any(), any(),
        expires: any(named: 'expires'),
        respHeaders: any(named: 'respHeaders'),
        requestDate: any(named: 'requestDate'))).thenAnswer((_) async => 'https://example.com/signed');
  });

  Future<void> pumpBrowserScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: S3BrowserScreen(s3Service: authS3Service)));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('tapping an image file opens the photo viewer', (tester) async {
    await pumpBrowserScreen(tester);

    await tester.tap(find.text('photo.jpg'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.byType(VideoViewerScreen), findsNothing);
  });

  testWidgets('tapping a video file opens the video viewer', (tester) async {
    // Regression guard for the UIScene window-lookup bug: this only proves
    // Dart routes to VideoViewerScreen correctly, which was never the
    // broken part - the native presentation is covered separately.
    await pumpBrowserScreen(tester);

    await tester.tap(find.text('clip.mp4'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VideoViewerScreen), findsOneWidget);
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });

  testWidgets('tapping any other file does not open a media viewer', (tester) async {
    await pumpBrowserScreen(tester);

    await tester.tap(find.text('report.pdf'));
    await tester.pump();

    expect(find.byType(PhotoViewerScreen), findsNothing);
    expect(find.byType(VideoViewerScreen), findsNothing);
  });
}
