import 'package:minio/minio.dart';

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

      // Use custom endpoint if provided, otherwise use AWS S3 endpoint
      final endpointUrl = endpoint?.isNotEmpty == true
          ? endpoint!.replaceAll('https://', '').replaceAll('http://', '')
          : 's3.amazonaws.com';

      // Determine if SSL should be used
      final useSSL = endpoint?.startsWith('http://') != true;

      // Split an optional ":port" suffix out of the host (e.g. a local
      // MinIO/Garage server on 127.0.0.1:3900) - Minio's endPoint must be a
      // bare host, with any non-default port passed separately. Parsing via
      // a dummy-scheme Uri handles this correctly, including bracketed
      // IPv6 hosts, rather than a hand-rolled split on ':'.
      final hostAndPort = Uri.parse('s3://$endpointUrl');
      final host = hostAndPort.host.isNotEmpty ? hostAndPort.host : endpointUrl;
      final port = hostAndPort.hasPort ? hostAndPort.port : null;

      // Extract region from AWS endpoint (e.g. s3.eu-west-2.amazonaws.com)
      final regionMatch = RegExp(r's3\.([^.]+)\.amazonaws\.com').firstMatch(host);
      final region = regionMatch?.group(1);

      _client = Minio(
        endPoint: host,
        port: port,
        accessKey: accessKey,
        secretKey: secretKey,
        useSSL: useSSL,
        region: region,
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
