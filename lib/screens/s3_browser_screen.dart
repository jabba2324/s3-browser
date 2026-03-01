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
  bool _isSearching = false;
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    _controller.setFilter('');
  }

  String _buildItemSummary() {
    final filtered = _controller.filteredObjects;
    final total = _controller.objects.length;
    final count = filtered.length;
    final totalBytes = filtered.fold<int>(0, (sum, o) => sum + (o.size ?? 0));
    final countStr = count != total
        ? '$count of $total items'
        : '$count ${count == 1 ? 'item' : 'items'}';
    return totalBytes > 0 ? '$countStr · ${FormatUtils.fileSize(totalBytes)}' : countStr;
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
        bottomNavigationBar: _buildSelectionBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_controller.isSelecting) {
      return AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _controller.clearSelection,
          tooltip: 'Cancel',
        ),
        title: Text('${_controller.selectedObjects.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _controller.selectAll,
            tooltip: 'Select all',
          ),
        ],
      );
    }

    return AppBar(
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Filter by name…',
                border: InputBorder.none,
              ),
              onChanged: _controller.setFilter,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_controller.currentFolderName),
                if (!_controller.isLoading && _controller.objects.isNotEmpty)
                  Text(
                    _buildItemSummary(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
      backgroundColor: Colors.white,
      leading: _isSearching
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          : _controller.canNavigateUp
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _controller.navigateUp,
                )
              : null,
      actions: _isSearching ? [] : [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _startSearch,
          tooltip: 'Filter',
        ),
        PopupMenuButton<SortOption>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: _controller.setSortOption,
          itemBuilder: (context) => SortOption.values.map((option) {
            return PopupMenuItem(
              value: option,
              child: Row(
                children: [
                  Icon(
                    _controller.sortOption == option
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(option.label),
                ],
              ),
            );
          }).toList(),
        ),
        IconButton(
          icon: Icon(_controller.isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: _controller.toggleGridView,
          tooltip: _controller.isGridView ? 'List view' : 'Grid view',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.checklist),
                  SizedBox(width: 8),
                  Text('Select'),
                ],
              ),
            ),
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
              value: 'create_folder',
              child: Row(
                children: [
                  Icon(Icons.create_new_folder),
                  SizedBox(width: 8),
                  Text('Create Folder'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Refresh'),
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

  Widget? _buildSelectionBar() {
    if (!_controller.isSelecting || _controller.selectedFiles.isEmpty) return null;
    final count = _controller.selectedFiles.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: Text('Share $count file${count == 1 ? '' : 's'}'),
          onPressed: _shareSelected,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'select') {
      _controller.enterSelectionMode();
    } else if (value == 'upload') {
      final result = await _controller.uploadFile();
      if (result != null) {
        _showResultSnackBar(result);
      }
    } else if (value == 'create_folder') {
      _showCreateFolderDialog();
    } else if (value == 'refresh') {
      _controller.loadObjects();
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

    if (_controller.filteredObjects.isEmpty) {
      final isFiltering = _controller.filterQuery.isNotEmpty;
      return EmptyState(
        icon: isFiltering ? Icons.search_off : Icons.folder_open,
        title: isFiltering ? 'No matches' : 'Empty folder',
        subtitle: isFiltering
            ? 'No items match "${_controller.filterQuery}"'
            : 'No files or folders found',
        actionLabel: isFiltering ? null : 'Upload Files',
        onAction: isFiltering ? null : () async {
          final result = await _controller.uploadFile();
          if (result != null) _showResultSnackBar(result);
        },
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

        return RefreshIndicator(
          onRefresh: _controller.loadObjects,
          child: GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: _controller.filteredObjects.length,
          itemBuilder: (context, index) {
            final object = _controller.filteredObjects[index];
            return ObjectGridTile(
              object: object,
              isSelecting: _controller.isSelecting,
              isSelected: _controller.isSelected(object.key),
              onTap: () => _controller.isSelecting
                  ? _controller.toggleSelection(object.key)
                  : _handleObjectTap(object),
              onLongPress: () => _controller.toggleSelection(object.key),
              onOptionsPressed: _controller.isSelecting ? null : () => _showFileOptions(object),
            );
          },
        ),
        );
      },
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _controller.loadObjects,
      child: ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _controller.filteredObjects.length,
      itemBuilder: (context, index) {
        final object = _controller.filteredObjects[index];
        return ObjectListTile(
          object: object,
          isSelecting: _controller.isSelecting,
          isSelected: _controller.isSelected(object.key),
          onTap: () => _controller.isSelecting
              ? _controller.toggleSelection(object.key)
              : _handleObjectTap(object),
          onLongPress: () => _controller.toggleSelection(object.key),
          onOptionsPressed: _controller.isSelecting ? null : () => _showFileOptions(object),
        );
      },
    ),
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

  Future<void> _shareSelected() async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? Rect.fromLTWH(0, 0, box.size.width, box.size.height / 2)
        : null;

    final result = await _controller.shareSelectedFiles(sharePositionOrigin: sharePositionOrigin);
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

  void _showCreateFolderDialog() async {
    final folderName = await TextInputDialog.show(
      context: context,
      title: 'Create Folder',
      labelText: 'Folder name',
      hintText: 'e.g. photos',
      confirmLabel: 'Create',
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
        if (value.contains('/')) return 'Name cannot contain /';
        return null;
      },
    );
    if (folderName != null) {
      final result = await _controller.createFolder(folderName.trim());
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
