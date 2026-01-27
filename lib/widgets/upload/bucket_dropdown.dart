import 'package:flutter/material.dart';
import '../../services/auth_storage_service.dart';

/// Dropdown for selecting a saved S3 bucket connection
class BucketDropdown extends StatelessWidget {
  final List<SavedConnection> connections;
  final SavedConnection? selectedConnection;
  final ValueChanged<SavedConnection?>? onChanged;

  const BucketDropdown({
    super.key,
    required this.connections,
    this.selectedConnection,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<SavedConnection>(
        value: selectedConnection,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Select Bucket',
          border: OutlineInputBorder(),
        ),
        items: connections.map((conn) {
          return DropdownMenuItem(
            value: conn,
            child: Text(
              conn.bucketPath,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
