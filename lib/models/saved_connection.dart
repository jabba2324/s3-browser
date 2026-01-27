/// Represents a saved S3 connection with credentials
class SavedConnection {
  final String id;
  final String accessKey;
  final String secretKey;
  final String? endpoint;
  final String bucketPath;
  final DateTime lastUsed;

  SavedConnection({
    required this.id,
    required this.accessKey,
    required this.secretKey,
    this.endpoint,
    required this.bucketPath,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'accessKey': accessKey,
    'secretKey': secretKey,
    'endpoint': endpoint,
    'bucketPath': bucketPath,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory SavedConnection.fromJson(Map<String, dynamic> json) => SavedConnection(
    id: json['id'] as String,
    accessKey: json['accessKey'] as String,
    secretKey: json['secretKey'] as String,
    endpoint: json['endpoint'] as String?,
    bucketPath: json['bucketPath'] as String,
    lastUsed: DateTime.parse(json['lastUsed'] as String),
  );
}
