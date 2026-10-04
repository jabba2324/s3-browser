import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/utils/validators.dart';
import 'package:s3_browser/widgets/dialogs/text_input_dialog.dart';

void main() {
  Future<void> pumpDialogOpener(
    WidgetTester tester, {
    required ValueChanged<String?> onResult,
    String? Function(String?)? validator,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await TextInputDialog.show(
              context: context,
              title: 'Rename',
              labelText: 'New name',
              validator: validator,
            );
            onResult(result);
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('blocks confirm when the field is empty', (tester) async {
    String? result = 'unset';
    await pumpDialogOpener(tester, onResult: (r) => result = r);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, 'unset'); // onResult never called - dialog is still open
  });

  testWidgets('blocks confirm when the validator rejects the input, allows it once valid', (tester) async {
    // Regression guard: the rename dialog used to pass no validator at all,
    // letting a name containing "/" silently move the file into a new prefix.
    String? result;
    await pumpDialogOpener(tester, onResult: (r) => result = r, validator: Validators.objectName);

    await tester.enterText(find.byType(TextField), 'archive/report.pdf');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget, reason: 'dialog should stay open on invalid input');
    expect(result, isNull);

    await tester.enterText(find.byType(TextField), 'report.pdf');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, 'report.pdf');
  });

  testWidgets('cancel returns null without validating', (tester) async {
    String? result = 'unset';
    await pumpDialogOpener(tester, onResult: (r) => result = r, validator: Validators.objectName);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isNull);
  });
}
