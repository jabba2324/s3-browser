import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/credentials_screen.dart';
import 'screens/shared_upload_screen.dart';
import 'services/shared_files_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSharedFilesHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The native share extension brings the app back to the foreground via a
    // URL open, but on iOS's UIScene lifecycle that doesn't reach AppDelegate's
    // legacy open-url handler once a scene is already connected (i.e. whenever
    // the app was already running). Re-checking on resume catches that case.
    if (state == AppLifecycleState.resumed) {
      _handleSharedFiles();
    }
  }

  void _initSharedFilesHandler() {
    if (kIsWeb) return;

    // Initialize shared files service
    SharedFilesService.initialize(
      onSharedFilesReceived: _handleSharedFiles,
    );

    // Check for pending shared files on startup (app might have been opened via share extension)
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _handleSharedFiles();
    });
  }

  bool _isShowingSharedUpload = false;

  Future<void> _handleSharedFiles() async {
    if (_isShowingSharedUpload) return;

    final files = await SharedFilesService.getPendingSharedFiles();
    if (files.isNotEmpty && navigatorKey.currentState != null) {
      _isShowingSharedUpload = true;
      await navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => SharedUploadScreen(filePaths: files),
        ),
      );
      _isShowingSharedUpload = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'S3 Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade800,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        useMaterial3: true,
      ),
      home: const CredentialsScreen(),
    );
  }
}
