import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/utils/s3_endpoint.dart';

void main() {
  group('S3Endpoint.parse', () {
    test('defaults to AWS S3 when endpoint is null or empty', () {
      for (final endpoint in [null, '']) {
        final parsed = S3Endpoint.parse(endpoint);
        expect(parsed.host, 's3.amazonaws.com');
        expect(parsed.port, isNull);
        expect(parsed.useSSL, isTrue);
        expect(parsed.region, isNull);
      }
    });

    test('parses a bare host with no scheme or port', () {
      final parsed = S3Endpoint.parse('minio.example.com');
      expect(parsed.host, 'minio.example.com');
      expect(parsed.port, isNull);
      expect(parsed.useSSL, isTrue);
    });

    test('strips https:// and infers SSL', () {
      final parsed = S3Endpoint.parse('https://minio.example.com');
      expect(parsed.host, 'minio.example.com');
      expect(parsed.useSSL, isTrue);
    });

    test('strips http:// and infers no SSL', () {
      final parsed = S3Endpoint.parse('http://minio.example.com');
      expect(parsed.host, 'minio.example.com');
      expect(parsed.useSSL, isFalse);
    });

    test('splits an explicit port out of the host', () {
      final parsed = S3Endpoint.parse('127.0.0.1:9000');
      expect(parsed.host, '127.0.0.1');
      expect(parsed.port, 9000);
    });

    test('splits a port from a scheme-prefixed endpoint', () {
      final parsed = S3Endpoint.parse('http://192.168.1.10:9000');
      expect(parsed.host, '192.168.1.10');
      expect(parsed.port, 9000);
      expect(parsed.useSSL, isFalse);
    });

    test('handles a bracketed IPv6 host with a port', () {
      final parsed = S3Endpoint.parse('[::1]:9000');
      expect(parsed.host, '::1');
      expect(parsed.port, 9000);
    });

    test('extracts the region from an AWS regional endpoint', () {
      final parsed = S3Endpoint.parse('s3.eu-west-2.amazonaws.com');
      expect(parsed.host, 's3.eu-west-2.amazonaws.com');
      expect(parsed.region, 'eu-west-2');
    });

    test('leaves region null for non-AWS endpoints', () {
      final parsed = S3Endpoint.parse('minio.example.com');
      expect(parsed.region, isNull);
    });
  });
}
