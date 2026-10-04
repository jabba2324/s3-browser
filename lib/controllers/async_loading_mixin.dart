import 'package:flutter/foundation.dart';

/// Shares the isLoading/error bookkeeping around an async operation that
/// several ChangeNotifier controllers otherwise hand-roll identically.
mixin AsyncLoadingMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  set isLoading(bool value) => _isLoading = value;
  set error(String? value) => _error = value;

  /// Runs [body], setting [isLoading] around it and notifying listeners
  /// before and after. [error] is cleared before running so a stale error
  /// doesn't linger; on exception it's set to the exception's message,
  /// prefixed with [errorPrefix] if given. A [body] that completes without
  /// throwing may still set [error] itself (e.g. a non-fatal "nothing found"
  /// case) - that's left untouched here rather than being cleared again.
  Future<void> runLoading(Future<void> Function() body, {String? errorPrefix}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await body();
    } catch (e) {
      _error = errorPrefix != null ? '$errorPrefix: $e' : e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
