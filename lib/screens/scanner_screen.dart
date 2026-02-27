import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:provider/provider.dart';

import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import '../models/scanned_document.dart';
import 'editor_screen.dart';

/// Screen that handles the camera-based document scanning logic.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  DocumentScanner? _documentScanner;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// Ensures camera permission is granted before starting the scanner.
  Future<void> _checkPermissions() async {
    final permissions = context.read<PermissionService>();
    bool granted = await permissions.isCameraGranted();
    if (!granted) {
      granted = await permissions.requestCameraPermission();
    }

    if (granted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan documents.'),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  /// Logic to trigger the ML Kit Document Scanner.
  void _startScan() async {
    setState(() => _isScanning = true);

    try {
      // Configuration for the scanner.
      // Note: Options might vary slightly between package versions.
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.pdf,
        mode: ScannerMode.full,
        pageLimit: 20,
        // Removed isGalleryImportAllowed if it causes lints in 0.1.0
      );

      _documentScanner = DocumentScanner(options: options);

      // This opens the native Android/iOS document scanner UI.
      final result = await _documentScanner!.scanDocument();

      if (result.pdf != null) {
        // Result contains a PDF file URI string.
        final pdfPath = result.pdf!.uri;
        await _saveScannedPdf(pdfPath);
      } else if (result.images.isNotEmpty) {
        // Result contains image paths, which we'll convert to PDF.
        await _convertImagesToPdf(result.images);
      } else {
        // User exited without scanning.
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Scan error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scanning failed: $e')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Saves a direct PDF output from the scanner into our app storage.
  Future<void> _saveScannedPdf(String tempPath) async {
    final storage = context.read<StorageService>();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalPath = await storage.getNewFilePath("Scan_$timestamp");

    // Copy the temporary file to our persistent storage.
    final tempFile = File(tempPath);
    await tempFile.copy(finalPath);

    final doc = ScannedDocument(
      id: DateTime.now().toIso8601String(),
      title: "New Scan ${DateTime.now().hour}:${DateTime.now().minute}",
      filePath: finalPath,
      dateCreated: DateTime.now(),
      isPdf: true,
    );

    await storage.saveDocument(doc);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => EditorScreen(document: doc)),
      );
    }
  }

  /// Takes separate images from the scanner and merges them into one PDF.
  Future<void> _convertImagesToPdf(List<String> images) async {
    final pdfService = context.read<PDFService>();
    final storage = context.read<StorageService>();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = await storage.getNewFilePath("Scan_$timestamp");

    await pdfService.imagesToPdf(images, outputPath);

    final doc = ScannedDocument(
      id: DateTime.now().toIso8601String(),
      title: "New Scan ${DateTime.now().hour}:${DateTime.now().minute}",
      filePath: outputPath,
      dateCreated: DateTime.now(),
      isPdf: true,
    );

    await storage.saveDocument(doc);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => EditorScreen(document: doc)),
      );
    }
  }

  @override
  void dispose() {
    _documentScanner?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: Center(
        child: _isScanning
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening Scanner...'),
                ],
              )
            : ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Restart Scanner'),
              ),
      ),
    );
  }
}
