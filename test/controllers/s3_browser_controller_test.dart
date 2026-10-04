import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:s3_browser/controllers/s3_browser_controller.dart';
import 'package:s3_browser/services/file_operations_service.dart';
import 'package:s3_browser/services/s3_browser_service.dart';

class MockS3BrowserService extends Mock implements S3BrowserService {}

class MockFileOperationsService extends Mock implements FileOperationsService {}

void main() {
  late MockS3BrowserService browserService;
  late MockFileOperationsService fileOps;
  late S3BrowserController controller;

  final folder = S3Object(name: 'photos', key: 'photos/', isFolder: true);
  final fileA = S3Object(name: 'b.txt', key: 'b.txt', isFolder: false, size: 10, lastModified: DateTime(2024, 1, 2));
  final fileB = S3Object(name: 'a.txt', key: 'a.txt', isFolder: false, size: 20, lastModified: DateTime(2024, 1, 1));

  setUp(() {
    browserService = MockS3BrowserService();
    fileOps = MockFileOperationsService();
    controller = S3BrowserController(
      browserService: browserService,
      fileOps: fileOps,
      bucketName: 'my-bucket',
    );
  });

  group('loadObjects', () {
    test('populates objects and clears loading/error on success', () async {
      when(() => browserService.listObjects(prefix: any(named: 'prefix')))
          .thenAnswer((_) async => [folder, fileA, fileB]);

      await controller.loadObjects();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.objects, hasLength(3));
    });

    test('sets error and keeps empty objects on failure', () async {
      when(() => browserService.listObjects(prefix: any(named: 'prefix')))
          .thenThrow(Exception('network error'));

      await controller.loadObjects();

      expect(controller.isLoading, isFalse);
      expect(controller.error, contains('network error'));
      expect(controller.objects, isEmpty);
    });
  });

  group('sorting', () {
    setUp(() async {
      when(() => browserService.listObjects(prefix: any(named: 'prefix')))
          .thenAnswer((_) async => [fileA, fileB, folder]);
      await controller.loadObjects();
    });

    test('folders always come first regardless of sort option', () {
      for (final option in SortOption.values) {
        controller.setSortOption(option);
        expect(controller.objects.first.isFolder, isTrue, reason: option.name);
      }
    });

    test('nameAsc sorts case-insensitively among files', () {
      controller.setSortOption(SortOption.nameAsc);
      final fileNames = controller.objects.where((o) => !o.isFolder).map((o) => o.name).toList();
      expect(fileNames, ['a.txt', 'b.txt']);
    });

    test('sizeLargest sorts descending by size among files', () {
      controller.setSortOption(SortOption.sizeLargest);
      final fileNames = controller.objects.where((o) => !o.isFolder).map((o) => o.name).toList();
      expect(fileNames, ['a.txt', 'b.txt']); // a.txt=20, b.txt=10
    });

    test('dateNewest sorts descending by lastModified among files', () {
      controller.setSortOption(SortOption.dateNewest);
      final fileNames = controller.objects.where((o) => !o.isFolder).map((o) => o.name).toList();
      expect(fileNames, ['b.txt', 'a.txt']); // b.txt is 2024-01-02
    });
  });

  group('filter', () {
    setUp(() async {
      when(() => browserService.listObjects(prefix: any(named: 'prefix')))
          .thenAnswer((_) async => [folder, fileA, fileB]);
      await controller.loadObjects();
    });

    test('filteredObjects matches case-insensitively on name', () {
      controller.setFilter('PHOTO');
      expect(controller.filteredObjects.map((o) => o.name), ['photos']);
    });

    test('empty filter returns everything', () {
      controller.setFilter('');
      expect(controller.filteredObjects, hasLength(3));
    });
  });

  group('selection mode', () {
    setUp(() async {
      when(() => browserService.listObjects(prefix: any(named: 'prefix')))
          .thenAnswer((_) async => [fileA, fileB]);
      await controller.loadObjects();
    });

    test('toggling a key enters selection mode and tracks it', () {
      expect(controller.isSelecting, isFalse);

      controller.toggleSelection(fileA.key);

      expect(controller.isSelecting, isTrue);
      expect(controller.isSelected(fileA.key), isTrue);
      expect(controller.selectedFiles.map((o) => o.key), [fileA.key]);
    });

    test('toggling the same key again deselects it', () {
      controller.toggleSelection(fileA.key);
      controller.toggleSelection(fileA.key);

      expect(controller.isSelected(fileA.key), isFalse);
    });

    test('selectAll selects every filtered object, clearSelection resets', () {
      controller.selectAll();
      expect(controller.selectedObjects, hasLength(2));

      controller.clearSelection();
      expect(controller.isSelecting, isFalse);
      expect(controller.selectedObjects, isEmpty);
    });
  });

  group('currentFolderName', () {
    test('is the bucket name at the root', () {
      expect(controller.currentFolderName, 'my-bucket');
    });

    test('is the last path segment at a nested prefix', () {
      final nested = S3BrowserController(
        browserService: browserService,
        fileOps: fileOps,
        bucketName: 'my-bucket',
        currentPrefix: 'docs/archive/',
      );
      expect(nested.currentFolderName, 'archive');
    });
  });
}
