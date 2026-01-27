import 'package:flutter/foundation.dart';
import '../models/connection_result.dart';
import '../services/auth_s3_service.dart';
import '../services/auth_storage_service.dart';

export '../models/connection_result.dart';

/// Controller for credentials screen state and connection logic
class CredentialsController extends ChangeNotifier {
  final AuthStorageService _authStorage;
  final AuthS3Service _s3Service;

  CredentialsController({
    AuthStorageService? authStorage,
    AuthS3Service? s3Service,
  })  : _authStorage = authStorage ?? AuthStorageService(),
        _s3Service = s3Service ?? AuthS3Service();

  // State
  List<SavedConnection> _savedConnections = [];
  bool _isLoading = true;
  bool _isConnecting = false;

  // Getters
  List<SavedConnection> get savedConnections => _savedConnections;
  bool get isLoading => _isLoading;
  bool get isConnecting => _isConnecting;
  bool get hasSavedCredentials => _savedConnections.isNotEmpty;
  AuthS3Service get s3Service => _s3Service;

  /// Load saved connections from storage
  Future<void> loadConnections() async {
    _isLoading = true;
    notifyListeners();

    try {
      _savedConnections = await _authStorage.loadConnections();
    } catch (e) {
      _savedConnections = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connect to S3 with the given credentials
  Future<ConnectionResult> connect({
    required String accessKey,
    required String secretKey,
    String? endpoint,
    required String bucketPath,
  }) async {
    _isConnecting = true;
    notifyListeners();

    try {
      await _s3Service.connect(
        accessKey: accessKey,
        secretKey: secretKey,
        endpoint: endpoint,
        bucketPath: bucketPath,
      );

      // Save credentials after successful connection
      await _authStorage.saveCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
        endpoint: endpoint,
        bucketPath: bucketPath,
      );

      _isConnecting = false;
      notifyListeners();

      return ConnectionResult.success(_s3Service);
    } catch (e) {
      _isConnecting = false;
      notifyListeners();

      return ConnectionResult.failure(_getErrorMessage(e));
    }
  }

  /// Connect using a saved connection
  Future<ConnectionResult> connectWithSaved(SavedConnection connection) async {
    return connect(
      accessKey: connection.accessKey,
      secretKey: connection.secretKey,
      endpoint: connection.endpoint,
      bucketPath: connection.bucketPath,
    );
  }

  /// Delete a single connection
  Future<void> deleteConnection(String id) async {
    await _authStorage.deleteConnection(id);
    _savedConnections.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Clear all saved connections
  Future<void> clearAllConnections() async {
    await _authStorage.clearAllConnections();
    _savedConnections = [];
    notifyListeners();
  }

  /// Convert exception to user-friendly error message
  String _getErrorMessage(Object e) {
    final errorString = e.toString();

    if (errorString.contains('Failed to fetch') ||
        errorString.contains('ClientException')) {
      return 'Connection blocked by browser (CORS policy). '
          'Configure CORS on your S3 bucket or use the iOS app.';
    } else if (errorString.contains('does not exist')) {
      return 'Bucket not found or not accessible';
    } else if (errorString.contains('Access Denied') ||
        errorString.contains('InvalidAccessKeyId')) {
      return 'Invalid credentials';
    }

    return 'Connection failed: $errorString';
  }
}
