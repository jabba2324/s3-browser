import 'package:flutter/material.dart';
import '../controllers/s3_browser_controller.dart';
import '../services/auth_s3_service.dart';
import '../services/auth_storage_service.dart';
import '../services/file_operations_service.dart';
import '../services/s3_browser_service.dart';
import '../utils/file_type_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/dialogs/dialogs.dart';
import '../widgets/sheets/sheets.dart';
import '../widgets/states/states.dart';
import '../widgets/tiles/tiles.dart';
import 'photo_viewer_screen.dart';
import 'video_viewer_screen.dart';

class S3BrowserScreen extends StatefulWidget {
  final AuthS3Service s3Service;

  const S3BrowserScreen({
    super.key,
    required this.s3Service,
  });

  @override
  State<S3BrowserScreen> createState() => _S3BrowserScreenState();
}

class _S3BrowserScreenState extends State<S3BrowserScreen> {
  final _authStorage = AuthStorageService();
  late final S3BrowserController _controller;

  @override
  void initState() {
    super.initState();
    final browserService = S3BrowserService(
      client: widget.s3Service.client!,
      bucketName: widget.s3Service.bucketName!,
    );
    _controller = S3BrowserController(
      browserService: browserService,
      fileOps: FileOperationsService(browserService: browserService),
      bucketName: widget.s3Service.bucketName ?? 'Bucket',
    );
    _controller.loadObjects();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showResultSnackBar(FileOperationResult result) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_controller.currentFolderName),
      backgroundColor: Colors.white,
      leading: _controller.canNavigateUp
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _controller.navigateUp,
            )
          : null,
      actions: [
        IconButton(
          icon: Icon(_controller.isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: _controller.toggleGridView,
          tooltip: _controller.isGridView ? 'List view' : 'Grid view',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _controller.loadObjects,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'upload',
              child: Row(
                children: [
                  Icon(Icons.upload_file),
                  SizedBox(width: 8),
                  Text('Upload'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'upload') {
      final result = await _controller.uploadFile();
      if (result != null) {
        _showResultSnackBar(result);
      }
    } else if (value == 'logout') {
      await _authStorage.clearCredentials();
      widget.s3Service.disconnect();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const LoadingState();
    }

    if (_controller.error != null) {
      return ErrorState(
        title: 'Error loading contents',
        message: _controller.error!,
        onRetry: _controller.loadObjects,
      );
    }

    if (_controller.objects.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'Empty folder',
        subtitle: 'No files or folders found',
      );
    }

    if (_controller.isGridView) {
      return _buildGridView();
    }

    return _buildListView();
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth < 1200) {
          crossAxisCount = 5;
        } else {
          crossAxisCount = 6;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: _controller.objects.length,
          itemBuilder: (context, index) {
            final object = _controller.objects[index];
            return ObjectGridTile(
              object: object,
              onTap: () => _handleObjectTap(object),
              onLongPress: object.isFolder ? null : () => _showFileOptions(object),
              onOptionsPressed: () => _showFileOptions(object),
            );
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _controller.objects.length,
      itemBuilder: (context, index) {
        final object = _controller.objects[index];
        return ObjectListTile(
          object: object,
          onTap: () => _handleObjectTap(object),
          onOptionsPressed: () => _showFileOptions(object),
        );
      },
    );
  }

  void _handleObjectTap(S3Object object) {
    if (object.isFolder) {
      _controller.navigateToFolder(object.key);
    } else if (FileTypeUtils.isImage(object.name)) {
      _openPhotoViewer(object);
    } else if (FileTypeUtils.isVideo(object.name)) {
      _openVideoViewer(object);
    } else {
      _downloadFile(object);
    }
  }

  void _openPhotoViewer(S3Object imageObject) {
    final initialIndex = _controller.getImageIndex(imageObject);
    if (initialIndex == -1) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          browserService: _controller.browserService,
          images: _controller.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openVideoViewer(S3Object videoObject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoViewerScreen(
          browserService: _controller.browserService,
          videoObject: videoObject,
        ),
      ),
    );
  }

  Future<void> _downloadFile(S3Object object) async {
    final result = await _controller.downloadFile(object);
    if (!result.success) {
      _showResultSnackBar(result);
    }
  }

  Future<void> _shareObject(S3Object object) async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? Rect.fromLTWH(0, 0, box.size.width, box.size.height / 2)
        : null;

    final result = await _controller.shareFile(object, sharePositionOrigin: sharePositionOrigin);
    _showResultSnackBar(result);
  }

  void _showFileOptions(S3Object object) {
    FileOptionsSheet.show(
      context: context,
      object: object,
      onViewPhoto: () => _openPhotoViewer(object),
      onPlayVideo: () => _openVideoViewer(object),
      onDownload: () => _downloadFile(object),
      onShare: () => _shareObject(object),
      onRename: () => _showRenameDialog(object),
      onDetails: () => _showFileDetails(object),
      onDelete: () => _confirmDelete(object),
    );
  }

  void _confirmDelete(S3Object object) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete File',
      message: 'Are you sure you want to delete "${object.name}"?\n\nThis action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirmed) {
      final result = await _controller.deleteFile(object);
      _showResultSnackBar(result);
    }
  }

  void _showRenameDialog(S3Object object) async {
    final newName = await TextInputDialog.show(
      context: context,
      title: 'Rename',
      initialValue: object.name,
      labelText: 'New name',
      confirmLabel: 'Rename',
    );
    if (newName != null && newName != object.name) {
      final result = await _controller.renameFile(object, newName);
      _showResultSnackBar(result);
    }
  }

  void _showFileDetails(S3Object object) {
    InfoDialog.show(
      context: context,
      title: 'File Details',
      items: [
        InfoItem('Name', object.name),
        InfoItem('Size', FormatUtils.fileSize(object.size)),
        InfoItem('Modified', FormatUtils.dateTime(object.lastModified)),
        InfoItem('Path', object.key),
      ],
    );
  }
}
