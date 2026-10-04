import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/controllers/shared_upload_controller.dart';
import 'package:s3_browser/services/auth_storage_service.dart';

class MockAuthStorageService extends Mock implements AuthStorageService {}

// Unlike the other controllers, SharedUploadController builds its own Minio
// client (and S3BrowserService) internally in _initBrowserService() once a
// connection is selected - there's no constructor seam to inject a mock
// there. That means only the branches reachable BEFORE _browserService gets
// created are network-free and covered here: navigateUp/navigateToFolder's
// prefix math (loadFolders() no-ops while _browserService is null) and
// loadConnections()'s empty/exception paths (the non-empty path calls
// _initBrowserService(), which calls the real listObjects network call).
// Covering loadConnections()'s non-empty path and uploadFiles would need
// either a real-but-unreachable-endpoint test (see test/upload_size_guard_test.dart
// for that pattern) or refactoring SharedUploadController to accept an
// injectable S3BrowserService factory - left as a follow-up, not done here.
void main() {
  late MockAuthStorageService authStorage;
  late SharedUploadController controller;

  setUp(() {
    authStorage = MockAuthStorageService();
    controller = SharedUploadController(filePaths: ['/tmp/a.txt'], authStorage: authStorage);
  });

  group('navigateToFolder / navigateUp (no connection selected)', () {
    test('navigateToFolder sets the prefix directly', () {
      controller.navigateToFolder('docs/');
      expect(controller.currentPrefix, 'docs/');
    });

    test('navigateUp from a single-level prefix returns to root', () {
      controller.navigateToFolder('docs/');
      controller.navigateUp();
      expect(controller.currentPrefix, '');
    });

    test('navigateUp from a nested prefix goes up exactly one level', () {
      controller.navigateToFolder('docs/archive/');
      controller.navigateUp();
      expect(controller.currentPrefix, 'docs/');
    });

    test('navigateUp at the root is a no-op', () {
      controller.navigateUp();
      expect(controller.currentPrefix, '');
    });
  });

  group('loadConnections', () {
    test('sets a "no saved buckets" error without throwing when none exist', () async {
      when(() => authStorage.loadConnections()).thenAnswer((_) async => []);

      await controller.loadConnections();

      expect(controller.isLoading, isFalse);
      expect(controller.connections, isEmpty);
      expect(controller.error, contains('No saved buckets found'));
    });

    test('wraps a storage exception with the error prefix', () async {
      when(() => authStorage.loadConnections()).thenThrow(Exception('disk error'));

      await controller.loadConnections();

      expect(controller.isLoading, isFalse);
      expect(controller.error, contains('Failed to load connections'));
      expect(controller.error, contains('disk error'));
    });
  });
}
