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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initSharedFilesHandler();
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

  Future<void> _handleSharedFiles() async {
    final files = await SharedFilesService.getPendingSharedFiles();
    if (files.isNotEmpty && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => SharedUploadScreen(filePaths: files),
        ),
      );
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
