import 'package:flutter/material.dart';

/// A dialog with a text input field for entering or editing text
class TextInputDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function(String?)? validator;

  const TextInputDialog({
    super.key,
    required this.title,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.confirmLabel = 'OK',
    this.cancelLabel = 'Cancel',
    this.validator,
  });

  /// Shows the dialog and returns the entered text, or null if cancelled
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? initialValue,
    String? labelText,
    String? hintText,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    String? Function(String?)? validator,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => TextInputDialog(
        title: title,
        initialValue: initialValue,
        labelText: labelText,
        hintText: hintText,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        validator: validator,
      ),
    );
  }

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    if (widget.validator != null && widget.validator!(value) != null) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
