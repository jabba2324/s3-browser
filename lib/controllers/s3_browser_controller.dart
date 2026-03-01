import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/file_operations_service.dart';
import '../services/s3_browser_service.dart';
import '../utils/file_type_utils.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  sizeLargest,
  sizeSmallest,
}

extension SortOptionLabel on SortOption {
  String get label => switch (this) {
    SortOption.nameAsc => 'Name (A → Z)',
    SortOption.nameDesc => 'Name (Z → A)',
    SortOption.dateNewest => 'Date (Newest)',
    SortOption.dateOldest => 'Date (Oldest)',
    SortOption.sizeLargest => 'Size (Largest)',
    SortOption.sizeSmallest => 'Size (Smallest)',
  };
}

/// Controller for S3 browser screen state and business logic
class S3BrowserController extends ChangeNotifier {
  final S3BrowserService browserService;
  final FileOperationsService fileOps;
  final String bucketName;

  S3BrowserController({
    required this.browserService,
    required this.fileOps,
    required this.bucketName,
  });

  // State
  List<S3Object> _objects = [];
  bool _isLoading = true;
  bool _isGridView = false;
  String _currentPrefix = '';
  String? _error;
  SortOption _sortOption = SortOption.nameAsc;
  String _filterQuery = '';

  // Getters
  List<S3Object> get objects => _objects;
  String get filterQuery => _filterQuery;
  List<S3Object> get filteredObjects {
    if (_filterQuery.isEmpty) return _objects;
    final q = _filterQuery.toLowerCase();
    return _objects.where((o) => o.name.toLowerCase().contains(q)).toList();
  }
  SortOption get sortOption => _sortOption;
  bool get isLoading => _isLoading;
  bool get isGridView => _isGridView;
  String get currentPrefix => _currentPrefix;
  String? get error => _error;
  bool get canNavigateUp => _currentPrefix.isNotEmpty;

  String get currentFolderName {
    if (_currentPrefix.isEmpty) return bucketName;
    final parts = _currentPrefix.split('/');
    parts.removeLast(); // Remove empty string at end
    return parts.isEmpty ? bucketName : parts.last;
  }

  List<S3Object> get images =>
      _objects.where((obj) => !obj.isFolder && FileTypeUtils.isImage(obj.name)).toList();

  int getImageIndex(S3Object imageObject) {
    return images.indexWhere((img) => img.key == imageObject.key);
  }

  // Actions
  Future<void> loadObjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await browserService.listObjects(prefix: _currentPrefix);
      _objects = _sorted(raw);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void navigateToFolder(String folderKey) {
    _currentPrefix = folderKey;
    _filterQuery = '';
    notifyListeners();
    loadObjects();
  }

  void navigateUp() {
    if (_currentPrefix.isEmpty) return;

    final parts = _currentPrefix.split('/');
    parts.removeLast(); // Remove empty string at end
    if (parts.isNotEmpty) {
      parts.removeLast(); // Remove last folder
    }

    _currentPrefix = parts.isEmpty ? '' : '${parts.join('/')}/';
    _filterQuery = '';
    notifyListeners();
    loadObjects();
  }

  void toggleGridView() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void setFilter(String query) {
    _filterQuery = query;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _objects = _sorted(List.of(_objects));
    notifyListeners();
  }

  List<S3Object> _sorted(List<S3Object> items) {
    items.sort((a, b) {
      // Folders always first
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;

      return switch (_sortOption) {
        SortOption.nameAsc => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortOption.nameDesc => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        SortOption.dateNewest => (b.lastModified ?? DateTime(0)).compareTo(a.lastModified ?? DateTime(0)),
        SortOption.dateOldest => (a.lastModified ?? DateTime(0)).compareTo(b.lastModified ?? DateTime(0)),
        SortOption.sizeLargest => (b.size ?? 0).compareTo(a.size ?? 0),
        SortOption.sizeSmallest => (a.size ?? 0).compareTo(b.size ?? 0),
      };
    });
    return items;
  }

  // File operations - return results for UI to handle feedback
  Future<FileOperationResult?> uploadFile() async {
    final result = await fileOps.uploadFile(_currentPrefix);
    if (result != null && result.success) {
      loadObjects();
    }
    return result;
  }

  Future<FileOperationResult> downloadFile(S3Object object) async {
    return fileOps.downloadFile(object);
  }

  Future<FileOperationResult> shareFile(S3Object object, {Rect? sharePositionOrigin}) async {
    return fileOps.shareFile(object, sharePositionOrigin: sharePositionOrigin);
  }

  Future<FileOperationResult> deleteFile(S3Object object) async {
    final result = await fileOps.deleteFile(object);
    if (result.success) {
      loadObjects();
    }
    return result;
  }

  Future<FileOperationResult> renameFile(S3Object object, String newName) async {
    final result = await fileOps.renameFile(object, newName, _currentPrefix);
    if (result.success) {
      loadObjects();
    }
    return result;
  }

  Future<FileOperationResult> createFolder(String folderName) async {
    final result = await fileOps.createFolder(_currentPrefix, folderName);
    if (result.success) {
      loadObjects();
    }
    return result;
  }
}
