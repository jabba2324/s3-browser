import 'package:flutter/material.dart';

/// A dialog that displays a list of labeled information items
class InfoDialog extends StatelessWidget {
  final String title;
  final List<InfoItem> items;
  final String closeLabel;

  const InfoDialog({
    super.key,
    required this.title,
    required this.items,
    this.closeLabel = 'Close',
  });

  /// Shows the dialog
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<InfoItem> items,
    String closeLabel = 'Close',
  }) {
    return showDialog(
      context: context,
      builder: (context) => InfoDialog(
        title: title,
        items: items,
        closeLabel: closeLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text('${items[i].label}: ${items[i].value}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(closeLabel),
        ),
      ],
    );
  }
}

/// A labeled piece of information for display in InfoDialog
class InfoItem {
  final String label;
  final String value;

  const InfoItem(this.label, this.value);
}
