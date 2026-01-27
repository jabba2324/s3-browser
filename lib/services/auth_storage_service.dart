import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/saved_connection.dart';
import 'share_extension_service.dart';

export '../models/saved_connection.dart';

class AuthStorageService {
  static const _storage = FlutterSecureStorage();
  
  // Key for storing connections list
  static const _connectionsKey = 'saved_connections';

  // Save a new connection or update existing one
  Future<void> saveConnection({
    required String accessKey,
    required String secretKey,
    String? endpoint,
    required String bucketPath,
  }) async {
    final connections = await loadConnections();
    
    // Create a unique ID based on bucket and endpoint
    final id = '${endpoint ?? 'aws'}_$bucketPath';
    
    // Remove existing connection with same ID
    connections.removeWhere((conn) => conn.id == id);
    
    // Add new connection at the beginning
    connections.insert(0, SavedConnection(
      id: id,
      accessKey: accessKey,
      secretKey: secretKey,
      endpoint: endpoint,
      bucketPath: bucketPath,
      lastUsed: DateTime.now(),
    ));
    
    // Keep only the last 10 connections
    if (connections.length > 10) {
      connections.removeRange(10, connections.length);
    }
    
    // Save to storage
    final jsonList = connections.map((c) => c.toJson()).toList();
    await _storage.write(key: _connectionsKey, value: jsonEncode(jsonList));

    // Sync with Share Extension
    await _syncWithExtension(connections);
  }

  // Sync credentials with iOS Share Extension
  Future<void> _syncWithExtension(List<SavedConnection> connections) async {
    final extensionCredentials = connections.map((conn) => {
      'endpoint': conn.endpoint ?? '',
      'accessKey': conn.accessKey,
      'secretKey': conn.secretKey,
      'bucket': conn.bucketPath,
    }).toList();

    await ShareExtensionService.saveCredentialsForExtension(extensionCredentials);
  }

  // Load all saved connections
  Future<List<SavedConnection>> loadConnections() async {
    try {
      final jsonString = await _storage.read(key: _connectionsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => SavedConnection.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Delete a specific connection
  Future<void> deleteConnection(String id) async {
    final connections = await loadConnections();
    connections.removeWhere((conn) => conn.id == id);

    final jsonList = connections.map((c) => c.toJson()).toList();
    await _storage.write(key: _connectionsKey, value: jsonEncode(jsonList));

    // Sync with Share Extension
    await _syncWithExtension(connections);
  }

  // Clear all stored connections
  Future<void> clearAllConnections() async {
    await _storage.delete(key: _connectionsKey);
    await ShareExtensionService.clearCredentialsForExtension();
  }

  // Legacy methods for backward compatibility
  Future<Map<String, dynamic>> loadCredentials() async {
    final connections = await loadConnections();
    if (connections.isEmpty) {
      return {};
    }
    
    final latest = connections.first;
    return {
      'accessKey': latest.accessKey,
      'secretKey': latest.secretKey,
      'endpoint': latest.endpoint,
      'bucketPath': latest.bucketPath,
    };
  }

  Future<void> saveCredentials({
    required String accessKey,
    required String secretKey,
    String? endpoint,
    required String bucketPath,
  }) async {
    await saveConnection(
      accessKey: accessKey,
      secretKey: secretKey,
      endpoint: endpoint,
      bucketPath: bucketPath,
    );
  }

  Future<bool> hasCredentials() async {
    final connections = await loadConnections();
    return connections.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await clearAllConnections();
  }

  // Clear all storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
