import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/main.dart';
import 'package:s3_browser/screens/shared_upload_screen.dart';

// Regression guard for a bug introduced while fixing the iOS share-extension
// flow: once MyApp started re-checking for pending shared files on every
// app resume (not just on cold start), nothing stopped it from pushing a
// second SharedUploadScreen on top of one that was already open if the app
// was backgrounded and resumed again before the user finished/closed it.
//
// We never let fake time reach the 500ms startup poll in
// _initSharedFilesHandler here (only zero-duration tester.pump() calls are
// used) so these tests isolate the resume-triggered path specifically.
void main() {
  const channel = MethodChannel('com.s3browser/shared_files');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'getPendingSharedFiles') {
          return ['/tmp/shared_photo.jpg'];
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('a single resume pushes exactly one SharedUploadScreen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SharedUploadScreen), findsOneWidget);

    // Drain the 500ms startup poll's pending timer so it doesn't trip the
    // test framework's "no pending timers after teardown" check; it's a
    // no-op here since the guard blocks it while the screen is still open.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a second resume while the screen is still open does not push a duplicate', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SharedUploadScreen), findsOneWidget);

    // Simulate the app being backgrounded and resumed again without the
    // user having closed or completed the upload screen.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SharedUploadScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('once the screen is closed, a later resume can open a new one', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SharedUploadScreen), findsOneWidget);

    navigatorKey.currentState!.pop();
    // A fixed, sub-500ms pump (not pumpAndSettle) so the pop transition
    // finishes without also crossing into the startup poll's timer - firing
    // that here would push its own screen and confuse this test's flow.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SharedUploadScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SharedUploadScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });
}
