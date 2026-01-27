import '../services/auth_s3_service.dart';

/// Result of an S3 connection attempt
class ConnectionResult {
  final bool success;
  final String? errorMessage;
  final AuthS3Service? s3Service;

  const ConnectionResult._({
    required this.success,
    this.errorMessage,
    this.s3Service,
  });

  factory ConnectionResult.success(AuthS3Service s3Service) =>
      ConnectionResult._(success: true, s3Service: s3Service);

  factory ConnectionResult.failure(String message) =>
      ConnectionResult._(success: false, errorMessage: message);
}
