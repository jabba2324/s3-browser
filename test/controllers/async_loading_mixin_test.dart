import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/controllers/async_loading_mixin.dart';

class _TestController extends ChangeNotifier with AsyncLoadingMixin {
  Future<void> succeed() => runLoading(() async {});

  Future<void> fail() => runLoading(() async => throw Exception('boom'));

  Future<void> failWithPrefix() =>
      runLoading(() async => throw Exception('boom'), errorPrefix: 'Failed to load things');

  Future<void> softErrorWithoutThrowing() => runLoading(() async {
    error = 'nothing found';
  });
}

void main() {
  late _TestController controller;

  setUp(() => controller = _TestController());

  test('starts with loading false and no error', () {
    expect(controller.isLoading, isFalse);
    expect(controller.error, isNull);
  });

  test('success clears any previous error and ends with loading false', () async {
    controller.error = 'stale error';

    await controller.succeed();

    expect(controller.isLoading, isFalse);
    expect(controller.error, isNull);
  });

  test('a thrown exception sets error to its message', () async {
    await controller.fail();

    expect(controller.isLoading, isFalse);
    expect(controller.error, contains('boom'));
  });

  test('a thrown exception is prefixed with errorPrefix when given', () async {
    await controller.failWithPrefix();

    expect(controller.error, 'Failed to load things: Exception: boom');
  });

  test('a body that sets error itself without throwing is not clobbered afterward', () async {
    // Regression guard: runLoading used to unconditionally clear `error`
    // after a successful (non-throwing) body call, which wiped out a
    // soft/non-fatal error the body had just set (e.g. "no connections found").
    await controller.softErrorWithoutThrowing();

    expect(controller.isLoading, isFalse);
    expect(controller.error, 'nothing found');
  });

  test('notifies listeners at least at the start and end of the run', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.succeed();

    expect(notifications, greaterThanOrEqualTo(2));
  });
}
