import 'package:minio/minio.dart';
import '../utils/s3_endpoint.dart';

class AuthS3Service {
  Minio? _client;
  String? _accessKey;
  String? _secretKey;
  String? _endpoint;
  String? _bucketPath;

  Minio? get client => _client;
  bool get isConnected => _client != null;
  String? get bucketName => _bucketPath;

  Future<bool> connect({
    required String accessKey,
    required String secretKey,
    String? endpoint,
    required String bucketPath,
  }) async {
    try {
      _accessKey = accessKey;
      _secretKey = secretKey;
      _endpoint = endpoint;
      _bucketPath = bucketPath;

      final parsed = S3Endpoint.parse(endpoint);

      _client = Minio(
        endPoint: parsed.host,
        port: parsed.port,
        accessKey: accessKey,
        secretKey: secretKey,
        useSSL: parsed.useSSL,
        region: parsed.region,
      );

      // Test connection by checking if the bucket exists
      final exists = await _client!.bucketExists(bucketPath);
      if (!exists) {
        throw Exception('Bucket "$bucketPath" does not exist or is not accessible');
      }
      
      return true;
    } catch (e) {
      _client = null;
      rethrow;
    }
  }

  void disconnect() {
    _client = null;
    _accessKey = null;
    _secretKey = null;
    _endpoint = null;
    _bucketPath = null;
  }

  // Getters for credentials (if needed elsewhere)
  String? get accessKey => _accessKey;
  String? get secretKey => _secretKey;
  String? get endpoint => _endpoint;
  String? get bucketPath => _bucketPath;
}
