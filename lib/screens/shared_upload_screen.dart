import 'package:flutter/material.dart';
import '../controllers/shared_upload_controller.dart';
import '../services/shared_files_service.dart';
import '../widgets/upload/upload.dart';

class SharedUploadScreen extends StatefulWidget {
  final List<String> filePaths;

  const SharedUploadScreen({super.key, required this.filePaths});

  @override
  State<SharedUploadScreen> createState() => _SharedUploadScreenState();
}

class _SharedUploadScreenState extends State<SharedUploadScreen> {
  late final SharedUploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SharedUploadController(filePaths: widget.filePaths);
    _controller.loadConnections();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    final success = await _controller.uploadFiles();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully uploaded ${widget.filePaths.length} file(s)'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleClose() async {
    await SharedFilesService.clearSharedFiles();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Upload Shared Files'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleClose,
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isUploading) {
            return UploadProgressView(
              uploadedCount: _controller.uploadedCount,
              totalCount: widget.filePaths.length,
              progress: _controller.uploadProgress,
            );
          }
          return _buildMainView();
        },
      ),
    );
  }

  Widget _buildMainView() {
    if (_controller.isLoading && _controller.connections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null && _controller.connections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_controller.error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        FileCountBanner(fileCount: widget.filePaths.length),
        if (_controller.connections.isNotEmpty)
          BucketDropdown(
            connections: _controller.connections,
            selectedConnection: _controller.selectedConnection,
            onChanged: _controller.selectConnection,
          ),
        PathBreadcrumb(
          path: _controller.currentPrefix.isEmpty
              ? '/ (root)'
              : '/${_controller.currentPrefix}',
        ),
        const Divider(),
        Expanded(
          child: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildFolderList(),
        ),
        if (_controller.error != null && _controller.connections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _controller.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _controller.selectedConnection != null ? _handleUpload : null,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload Here'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderList() {
    final items = <Widget>[];

    if (_controller.currentPrefix.isNotEmpty) {
      items.add(
        ListTile(
          leading: const Icon(Icons.arrow_upward),
          title: const Text('.. (Go back)'),
          onTap: _controller.navigateUp,
        ),
      );
    }

    for (final folder in _controller.folders) {
      items.add(
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text(folder.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _controller.navigateToFolder(folder.key),
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('No folders in this location'),
      );
    }

    return ListView(children: items);
  }
}
