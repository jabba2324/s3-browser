/// A user-supplied S3-compatible endpoint, parsed into the pieces Minio's
/// constructor needs.
class S3Endpoint {
  final String host;
  final int? port;
  final bool useSSL;
  final String? region;

  const S3Endpoint({
    required this.host,
    this.port,
    required this.useSSL,
    this.region,
  });

  /// Parses an optional endpoint string (e.g. "https://s3.eu-west-2.amazonaws.com",
  /// "127.0.0.1:9000") into host/port/useSSL/region, defaulting to AWS S3 when
  /// absent. Splits an optional ":port" suffix out of the host - Minio's
  /// endPoint must be a bare host, with any non-default port passed
  /// separately. Parsing via a dummy-scheme Uri handles this correctly,
  /// including bracketed IPv6 hosts, rather than a hand-rolled split on ':'.
  static S3Endpoint parse(String? endpoint) {
    final useSSL = endpoint?.startsWith('http://') != true;
    final stripped = endpoint?.isNotEmpty == true
        ? endpoint!.replaceAll('https://', '').replaceAll('http://', '')
        : 's3.amazonaws.com';

    final hostAndPort = Uri.parse('s3://$stripped');
    final host = hostAndPort.host.isNotEmpty ? hostAndPort.host : stripped;
    final port = hostAndPort.hasPort ? hostAndPort.port : null;

    // Extract region from AWS endpoint (e.g. s3.eu-west-2.amazonaws.com)
    final regionMatch = RegExp(r's3\.([^.]+)\.amazonaws\.com').firstMatch(host);
    final region = regionMatch?.group(1);

    return S3Endpoint(host: host, port: port, useSSL: useSSL, region: region);
  }
}
