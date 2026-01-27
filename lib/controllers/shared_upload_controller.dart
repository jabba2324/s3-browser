import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import '../services/auth_storage_service.dart';
import '../services/s3_browser_service.dart';
import '../services/shared_files_service.dart';

/// Controller for shared upload screen state and logic
class SharedUploadController extends ChangeNotifier {
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
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;
  double _uploadProgress = 0;
  int _uploadedCount = 0;

  // Getters
  List<SavedConnection> get connections => _connections;
  SavedConnection? get selectedConnection => _selectedConnection;
  String get currentPrefix => _currentPrefix;
  List<S3Object> get folders => _folders;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;
  int get uploadedCount => _uploadedCount;
  int get totalFiles => filePaths.length;
  bool get hasConnections => _connections.isNotEmpty;
  bool get canUpload => _selectedConnection != null && !_isUploading;
  String get displayPath => _currentPrefix.isEmpty ? '/ (root)' : '/$_currentPrefix';

  /// Load saved connections from storage
  Future<void> loadConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final connections = await _authStorage.loadConnections();
      _connections = connections;
      _isLoading = false;

      if (connections.isEmpty) {
        _error = 'No saved buckets found. Please add a bucket in the main app first.';
      } else {
        _selectedConnection = connections.first;
        _initBrowserService();
      }
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load connections: $e';
      notifyListeners();
    }
  }

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
    final minio = Minio(
      endPoint: conn.endpoint?.isNotEmpty == true
          ? conn.endpoint!.replaceAll('https://', '').replaceAll('http://', '')
          : 's3.amazonaws.com',
      accessKey: conn.accessKey,
      secretKey: conn.secretKey,
      useSSL: conn.endpoint?.startsWith('http://') != true,
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

    _isLoading = true;
    notifyListeners();

    try {
      final objects = await _browserService!.listObjects(prefix: _currentPrefix);
      _folders = objects.where((o) => o.isFolder).toList();
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load folders: $e';
      notifyListeners();
    }
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
    _error = null;
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
        final bytes = await file.readAsBytes();

        await _browserService!.uploadObject(objectKey, bytes);

        _uploadedCount = i + 1;
        _uploadProgress = _uploadedCount / filePaths.length;
        notifyListeners();
      }

      // Clean up shared files
      await SharedFilesService.clearSharedFiles();

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isUploading = false;
      _error = 'Upload failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Cancel and clear shared files
  Future<void> cancelUpload() async {
    await SharedFilesService.clearSharedFiles();
  }
}
