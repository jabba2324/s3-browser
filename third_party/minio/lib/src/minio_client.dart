import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:minio/minio.dart';
import 'package:minio/src/minio_helpers.dart';
import 'package:minio/src/minio_s3.dart';
import 'package:minio/src/minio_sign.dart';
import 'package:minio/src/utils.dart';

/// Strictly percent-encodes a raw path segment using the same AWS SigV4
/// canonical-URI rules as [encodePath] in minio_helpers.dart, so the actual
/// request sent on the wire matches what was signed byte-for-byte - instead
/// of relying on Dart's lenient Uri(pathSegments: ...) encoding, which
/// leaves sub-delimiter characters (&()!*'+,;=) unescaped. Without this,
/// object keys containing those characters are signed as if the path were
/// percent-encoded but actually sent unescaped, so some S3-compatible
/// servers (e.g. Garage) reject the request with "Forbidden: Invalid
/// signature" - see the s3-browser repo history for the reproduction.
String _strictEncodeSegment(String segment) {
  final result = StringBuffer();
  for (final char in segment.codeUnits) {
    final isUpper = char >= 65 && char <= 90; // A-Z
    final isLower = char >= 97 && char <= 122; // a-z
    final isDigit = char >= 48 && char <= 57; // 0-9
    final isUnreserved = char == 45 || // -
        char == 95 || // _
        char == 46 || // .
        char == 126; // ~
    if (isUpper || isLower || isDigit || isUnreserved) {
      result.writeCharCode(char);
      continue;
    }
    if (char == 32 || char == 43) {
      // space or +
      result.write('%20');
      continue;
    }
    result.write('%');
    result.write(char.toRadixString(16).toUpperCase().padLeft(2, '0'));
  }
  return result.toString();
}

class MinioRequest extends StreamedRequest {
  MinioRequest(super.method, super.url, {this.onProgress});

  dynamic body;

  final void Function(int)? onProgress;

  @override
  ByteStream finalize() {
    super.finalize();

    if (body == null) {
      return const ByteStream(Stream.empty());
    }

    late Stream<Uint8List> stream;

    if (body is Stream<Uint8List>) {
      stream = body;
    } else if (body is String) {
      final data = const Utf8Encoder().convert(body);
      headers['content-length'] = data.length.toString();
      stream = Stream<Uint8List>.value(data);
    } else if (body is Uint8List) {
      stream = Stream<Uint8List>.value(body);
      headers['content-length'] = body.length.toString();
    } else {
      throw UnsupportedError('Unsupported body type: ${body.runtimeType}');
    }

    if (onProgress == null) {
      return ByteStream(stream);
    }

    var bytesRead = 0;

    stream = stream.transform(MaxChunkSize(1 << 16));

    return ByteStream(
      stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            sink.add(data);
            bytesRead += data.length;
            onProgress!(bytesRead);
          },
        ),
      ),
    );
  }

  MinioRequest replace({
    String? method,
    Uri? url,
    Map<String, String>? headers,
    body,
  }) {
    final result = MinioRequest(method ?? this.method, url ?? this.url);
    result.body = body ?? this.body;
    result.headers.addAll(headers ?? this.headers);
    return result;
  }
}

/// An HTTP response where the entire response body is known in advance.
class MinioResponse extends BaseResponse {
  /// Create a new HTTP response with a byte array body.
  MinioResponse.bytes(
    this.bodyBytes,
    int statusCode, {
    BaseRequest? request,
    Map<String, String> headers = const {},
    bool isRedirect = false,
    bool persistentConnection = true,
    String? reasonPhrase,
  }) : super(
          statusCode,
          contentLength: bodyBytes.length,
          request: request,
          headers: headers,
          isRedirect: isRedirect,
          persistentConnection: persistentConnection,
          reasonPhrase: reasonPhrase,
        );

  /// The bytes comprising the body of this response.
  final Uint8List bodyBytes;

  /// Body of s3 response is always encoded as UTF-8.
  String get body => utf8.decode(bodyBytes);

  static Future<MinioResponse> fromStream(StreamedResponse response) async {
    final body = await response.stream.toBytes();
    return MinioResponse.bytes(
      body,
      response.statusCode,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

class MinioClient {
  MinioClient(this.minio) {
    anonymous = minio.accessKey.isEmpty && minio.secretKey.isEmpty;
    enableSHA256 = !anonymous && !minio.useSSL;
    port = minio.port;
  }

  final Minio minio;
  final String userAgent = 'MinIO (Unknown; Unknown) minio-dart/2.0.0';

  late bool enableSHA256;
  late bool anonymous;
  late final int port;

  Future<StreamedResponse> _request({
    required String method,
    String? bucket,
    String? object,
    String? region,
    String? resource,
    dynamic payload = '',
    Map<String, dynamic>? queries,
    Map<String, String>? headers,
    void Function(int)? onProgress,
  }) async {
    if (bucket != null) {
      region ??= await minio.getBucketRegion(bucket);
    }

    region ??= 'us-east-1';

    final request = getBaseRequest(
      method,
      bucket,
      object,
      region,
      resource,
      queries,
      headers,
      onProgress,
    );
    request.body = payload;

    final date = DateTime.now().toUtc();
    final sha256sum = enableSHA256 ? sha256Hex(payload) : 'UNSIGNED-PAYLOAD';
    request.headers.addAll({
      'user-agent': userAgent,
      'x-amz-date': makeDateLong(date),
      'x-amz-content-sha256': sha256sum,
    });

    if (minio.sessionToken != null) {
      request.headers['x-amz-security-token'] = minio.sessionToken!;
    }

    final authorization = signV4(minio, request, date, region);
    request.headers['authorization'] = authorization;
    logRequest(request);
    final response = await request.send();
    return response;
  }

  Future<MinioResponse> request({
    required String method,
    String? bucket,
    String? object,
    String? region,
    String? resource,
    dynamic payload = '',
    Map<String, dynamic>? queries,
    Map<String, String>? headers,
    void Function(int)? onProgress,
  }) async {
    final stream = await _request(
      method: method,
      bucket: bucket,
      object: object,
      region: region,
      payload: payload,
      resource: resource,
      queries: queries,
      headers: headers,
      onProgress: onProgress,
    );

    final response = await MinioResponse.fromStream(stream);
    logResponse(response);

    return response;
  }

  Future<StreamedResponse> requestStream({
    required String method,
    String? bucket,
    String? object,
    String? region,
    String? resource,
    dynamic payload = '',
    Map<String, dynamic>? queries,
    Map<String, String>? headers,
  }) async {
    final response = await _request(
      method: method,
      bucket: bucket,
      object: object,
      region: region,
      payload: payload,
      resource: resource,
      queries: queries,
      headers: headers,
    );

    logResponse(response);
    return response;
  }

  MinioRequest getBaseRequest(
    String method,
    String? bucket,
    String? object,
    String region,
    String? resource,
    Map<String, dynamic>? queries,
    Map<String, String>? headers,
    void Function(int)? onProgress,
  ) {
    final url = getRequestUrl(bucket, object, resource, queries);
    final request = MinioRequest(method, url, onProgress: onProgress);
    request.headers['host'] = url.authority;

    if (headers != null) {
      request.headers.addAll(headers);
    }

    return request;
  }

  Uri getRequestUrl(
    String? bucket,
    String? object,
    String? resource,
    Map<String, dynamic>? queries,
  ) {
    var host = minio.endPoint.toLowerCase();
    var path = '/';

    bool pathStyle = minio.pathStyle ?? true;
    if (isAmazonEndpoint(host)) {
      host = getS3Endpoint(minio.region!);
      pathStyle = !isVirtualHostStyle(host, minio.useSSL, bucket);
    }

    if (!pathStyle) {
      if (bucket != null) host = '$bucket.$host';
      if (object != null) path = '/$object';
    } else {
      if (bucket != null) path = '/$bucket';
      if (object != null) path = '/$bucket/$object';
    }

    final query = StringBuffer();
    if (resource != null) {
      query.write(resource);
    }
    if (queries != null) {
      if (query.isNotEmpty) query.write('&');
      query.write(encodeQueries(queries));
    }

    final scheme = minio.useSSL ? 'https' : 'http';
    final encodedPath = path.split('/').map(_strictEncodeSegment).join('/');
    final queryStr = query.toString();
    return Uri.parse(
      '$scheme://$host:${minio.port}$encodedPath${queryStr.isNotEmpty ? '?$queryStr' : ''}',
    );
  }

  void logRequest(MinioRequest request) {
    if (!minio.enableTrace) return;

    final buffer = StringBuffer();
    buffer.writeln('REQUEST: ${request.method} ${request.url}');
    for (var header in request.headers.entries) {
      buffer.writeln('${header.key}: ${header.value}');
    }

    if (request.body is List<int>) {
      buffer.writeln('List<int> of size ${request.body.length}');
    } else {
      buffer.writeln(request.body);
    }

    print(buffer.toString());
  }

  void logResponse(BaseResponse response) {
    if (!minio.enableTrace) return;

    final buffer = StringBuffer();
    buffer.writeln('RESPONSE: ${response.statusCode} ${response.reasonPhrase}');
    for (var header in response.headers.entries) {
      buffer.writeln('${header.key}: ${header.value}');
    }

    if (response is Response) {
      buffer.writeln(response.body);
    } else if (response is StreamedResponse) {
      buffer.writeln('STREAMED BODY');
    }

    print(buffer.toString());
  }
}
