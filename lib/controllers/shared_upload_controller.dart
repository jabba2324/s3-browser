import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import '../services/auth_storage_service.dart';
import '../services/s3_browser_service.dart';
import '../services/shared_files_service.dart';
import '../utils/format_utils.dart';
import '../utils/s3_endpoint.dart';
import 'async_loading_mixin.dart';

/// Controller for shared upload screen state and logic
class SharedUploadController extends ChangeNotifier with AsyncLoadingMixin {
  final AuthStorageService _authStorage;
  final List<String> filePaths;

  SharedUploadController({
    required this.filePaths,
    AuthStorageService? authStorage,
  }) : _authStorage = authStorage ?? AuthStorageService();

  // State
  List<SavedConnection> _connections = [];
  SavedConnection? _selectedConnection;
  S3BrowserService? _browserService;
  String _currentPrefix = '';
  List<S3Object> _folders = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _uploadedCount = 0;

  // Getters
  List<SavedConnection> get connections => _connections;
  SavedConnection? get selectedConnection => _selectedConnection;
  String get currentPrefix => _currentPrefix;
  List<S3Object> get folders => _folders;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  int get uploadedCount => _uploadedCount;
  int get totalFiles => filePaths.length;
  bool get hasConnections => _connections.isNotEmpty;
  bool get canUpload => _selectedConnection != null && !_isUploading;
  String get displayPath => _currentPrefix.isEmpty ? '/ (root)' : '/$_currentPrefix';

  /// Load saved connections from storage
  Future<void> loadConnections() => runLoading(errorPrefix: 'Failed to load connections', () async {
    final connections = await _authStorage.loadConnections();
    _connections = connections;

    if (connections.isEmpty) {
      error = 'No saved buckets found. Please add a bucket in the main app first.';
    } else {
      _selectedConnection = connections.first;
      _initBrowserService();
    }
  });

  /// Select a different connection
  void selectConnection(SavedConnection? connection) {
    _selectedConnection = connection;
    _currentPrefix = '';
    _folders = [];
    notifyListeners();
    _initBrowserService();
  }

  void _initBrowserService() {
    if (_selectedConnection == null) return;

    final conn = _selectedConnection!;
    final parsed = S3Endpoint.parse(conn.endpoint);
    final minio = Minio(
      endPoint: parsed.host,
      port: parsed.port,
      accessKey: conn.accessKey,
      secretKey: conn.secretKey,
      useSSL: parsed.useSSL,
      region: parsed.region,
    );

    _browserService = S3BrowserService(
      client: minio,
      bucketName: conn.bucketPath.split('/').first,
    );

    loadFolders();
  }

  /// Load folders at current prefix
  Future<void> loadFolders() async {
    if (_browserService == null) return;

    await runLoading(errorPrefix: 'Failed to load folders', () async {
      final objects = await _browserService!.listObjects(prefix: _currentPrefix);
      _folders = objects.where((o) => o.isFolder).toList();
    });
  }

  /// Navigate into a folder
  void navigateToFolder(String folderKey) {
    _currentPrefix = folderKey;
    notifyListeners();
    loadFolders();
  }

  /// Navigate up one level
  void navigateUp() {
    if (_currentPrefix.isEmpty) return;

    final parts = _currentPrefix.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) {
      _currentPrefix = '';
    } else {
      _currentPrefix = '${parts.sublist(0, parts.length - 1).join('/')}/';
    }
    notifyListeners();
    loadFolders();
  }

  /// Upload all files to current location
  /// Returns true if successful
  Future<bool> uploadFiles() async {
    if (_browserService == null) return false;

    _isUploading = true;
    _uploadProgress = 0;
    _uploadedCount = 0;
    error = null;
    notifyListeners();

    try {
      for (int i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final file = File(filePath);

        if (!await file.exists()) {
          continue;
        }

        final filename = filePath.split('/').last;
        final objectKey = '$_currentPrefix$filename';
        final size = await file.length();
        final stream = file.openRead().map(
          (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
        );

        await _browserService!.uploadObjectStream(objectKey, stream, size);

        _uploadedCount = i + 1;
        _uploadProgress = _uploadedCount / filePaths.length;
        notifyListeners();
      }

      // Clean up shared files
      await SharedFilesService.clearSharedFiles();

      _isUploading = false;
      notifyListeners();
      return true;
    } on FileTooLargeException catch (e) {
      _isUploading = false;
      error = 'File too large to upload (max ${FormatUtils.fileSize(e.maxSize)})';
      notifyListeners();
      return false;
    } catch (e) {
      _isUploading = false;
      error = 'Upload failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Cancel and clear shared files
  Future<void> cancelUpload() async {
    await SharedFilesService.clearSharedFiles();
  }
}
