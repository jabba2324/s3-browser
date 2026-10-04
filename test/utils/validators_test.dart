import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/utils/validators.dart';

void main() {
  group('Validators.objectName', () {
    test('rejects null', () {
      expect(Validators.objectName(null), isNotNull);
    });

    test('rejects an empty string', () {
      expect(Validators.objectName(''), isNotNull);
    });

    test('rejects a whitespace-only string', () {
      expect(Validators.objectName('   '), isNotNull);
    });

    test('rejects a name containing a slash', () {
      expect(Validators.objectName('archive/report.pdf'), isNotNull);
    });

    test('accepts a valid name', () {
      expect(Validators.objectName('report.pdf'), isNull);
    });
  });
}
