import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/controllers/credentials_controller.dart';
import 'package:s3_browser/services/auth_s3_service.dart';
import 'package:s3_browser/services/auth_storage_service.dart';

class MockAuthStorageService extends Mock implements AuthStorageService {}

class MockAuthS3Service extends Mock implements AuthS3Service {}

void main() {
  late MockAuthStorageService authStorage;
  late MockAuthS3Service s3Service;
  late CredentialsController controller;

  setUp(() {
    authStorage = MockAuthStorageService();
    s3Service = MockAuthS3Service();
    controller = CredentialsController(authStorage: authStorage, s3Service: s3Service);

    // Stub unconditionally-called side effects so individual tests only
    // need to override what they care about.
    when(() => authStorage.saveCredentials(
          accessKey: any(named: 'accessKey'),
          secretKey: any(named: 'secretKey'),
          endpoint: any(named: 'endpoint'),
          bucketPath: any(named: 'bucketPath'),
        )).thenAnswer((_) async {});
  });

  group('loadConnections', () {
    test('populates savedConnections on success', () async {
      final saved = SavedConnection(
        id: '1',
        accessKey: 'a',
        secretKey: 's',
        bucketPath: 'bucket',
        lastUsed: DateTime(2024),
      );
      when(() => authStorage.loadConnections()).thenAnswer((_) async => [saved]);

      await controller.loadConnections();

      expect(controller.isLoading, isFalse);
      expect(controller.savedConnections, [saved]);
      expect(controller.hasSavedCredentials, isTrue);
    });

    test('falls back to an empty list if storage throws', () async {
      when(() => authStorage.loadConnections()).thenThrow(Exception('corrupt storage'));

      await controller.loadConnections();

      expect(controller.isLoading, isFalse);
      expect(controller.savedConnections, isEmpty);
    });
  });

  group('connect', () {
    test('saves credentials and returns success when the S3 connection succeeds', () async {
      when(() => s3Service.connect(
            accessKey: any(named: 'accessKey'),
            secretKey: any(named: 'secretKey'),
            endpoint: any(named: 'endpoint'),
            bucketPath: any(named: 'bucketPath'),
          )).thenAnswer((_) async => true);

      final result = await controller.connect(
        accessKey: 'a',
        secretKey: 's',
        bucketPath: 'bucket',
      );

      expect(result.success, isTrue);
      expect(result.s3Service, s3Service);
      expect(controller.isConnecting, isFalse);
      verify(() => authStorage.saveCredentials(
            accessKey: 'a',
            secretKey: 's',
            endpoint: null,
            bucketPath: 'bucket',
          )).called(1);
    });

    test('maps a CORS-shaped exception to a friendly message', () async {
      when(() => s3Service.connect(
            accessKey: any(named: 'accessKey'),
            secretKey: any(named: 'secretKey'),
            endpoint: any(named: 'endpoint'),
            bucketPath: any(named: 'bucketPath'),
          )).thenThrow(Exception('ClientException: Failed to fetch'));

      final result = await controller.connect(accessKey: 'a', secretKey: 's', bucketPath: 'bucket');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('CORS'));
    });

    test('maps a "does not exist" exception to a bucket-not-found message', () async {
      when(() => s3Service.connect(
            accessKey: any(named: 'accessKey'),
            secretKey: any(named: 'secretKey'),
            endpoint: any(named: 'endpoint'),
            bucketPath: any(named: 'bucketPath'),
          )).thenThrow(Exception('Bucket "x" does not exist or is not accessible'));

      final result = await controller.connect(accessKey: 'a', secretKey: 's', bucketPath: 'bucket');

      expect(result.errorMessage, 'Bucket not found or not accessible');
    });

    test('maps an access-denied exception to an invalid-credentials message', () async {
      when(() => s3Service.connect(
            accessKey: any(named: 'accessKey'),
            secretKey: any(named: 'secretKey'),
            endpoint: any(named: 'endpoint'),
            bucketPath: any(named: 'bucketPath'),
          )).thenThrow(Exception('Access Denied'));

      final result = await controller.connect(accessKey: 'a', secretKey: 's', bucketPath: 'bucket');

      expect(result.errorMessage, 'Invalid credentials');
    });

    test('falls back to a generic connection-failed message for anything else', () async {
      when(() => s3Service.connect(
            accessKey: any(named: 'accessKey'),
            secretKey: any(named: 'secretKey'),
            endpoint: any(named: 'endpoint'),
            bucketPath: any(named: 'bucketPath'),
          )).thenThrow(Exception('mystery error'));

      final result = await controller.connect(accessKey: 'a', secretKey: 's', bucketPath: 'bucket');

      expect(result.errorMessage, contains('Connection failed'));
      expect(result.errorMessage, contains('mystery error'));
    });
  });

  group('deleteConnection / clearAllConnections', () {
    test('deleteConnection removes only the matching connection locally', () async {
      final a = SavedConnection(id: 'a', accessKey: 'x', secretKey: 'y', bucketPath: 'b', lastUsed: DateTime(2024));
      final b = SavedConnection(id: 'b', accessKey: 'x', secretKey: 'y', bucketPath: 'b', lastUsed: DateTime(2024));
      when(() => authStorage.loadConnections()).thenAnswer((_) async => [a, b]);
      await controller.loadConnections();

      when(() => authStorage.deleteConnection(any())).thenAnswer((_) async {});
      await controller.deleteConnection('a');

      expect(controller.savedConnections, [b]);
    });

    test('clearAllConnections empties the local list', () async {
      when(() => authStorage.loadConnections()).thenAnswer((_) async => [
            SavedConnection(id: 'a', accessKey: 'x', secretKey: 'y', bucketPath: 'b', lastUsed: DateTime(2024)),
          ]);
      await controller.loadConnections();

      when(() => authStorage.clearAllConnections()).thenAnswer((_) async {});
      await controller.clearAllConnections();

      expect(controller.savedConnections, isEmpty);
    });
  });
}
