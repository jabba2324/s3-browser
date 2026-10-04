import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/utils/format_utils.dart';

void main() {
  group('FormatUtils.fileSize', () {
    test('returns a placeholder for null', () {
      expect(FormatUtils.fileSize(null), '-');
    });

    test('formats bytes below 1 KB', () {
      expect(FormatUtils.fileSize(0), '0 B');
      expect(FormatUtils.fileSize(1023), '1023 B');
    });

    test('formats at and above the KB boundary', () {
      expect(FormatUtils.fileSize(1024), '1.0 KB');
    });

    test('formats at and above the MB boundary', () {
      expect(FormatUtils.fileSize(1024 * 1024), '1.0 MB');
    });

    test('formats at and above the GB boundary', () {
      expect(FormatUtils.fileSize(1024 * 1024 * 1024), '1.0 GB');
    });
  });

  group('FormatUtils.dateTime', () {
    test('returns a placeholder for null', () {
      expect(FormatUtils.dateTime(null), '-');
    });

    test('pads single-digit month/day/hour/minute', () {
      expect(FormatUtils.dateTime(DateTime(2026, 1, 5, 9, 3)), '2026-01-05 09:03');
    });
  });

  group('FormatUtils.date', () {
    test('returns a placeholder for null', () {
      expect(FormatUtils.date(null), '-');
    });

    test('pads single-digit month/day', () {
      expect(FormatUtils.date(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
