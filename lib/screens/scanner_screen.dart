import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:provider/provider.dart';

import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import '../services/image_processing_service.dart';
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
      // We FORCE jpeg mode and high-res scanning for our manual whitening filter
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 20,
      );

      _documentScanner = DocumentScanner(options: options);

      final result = await _documentScanner!.scanDocument();

      if (result.images.isNotEmpty) {
        // All images MUST go through the whitening filter
        await _convertImagesToPdf(result.images);
      } else {
        // User exited without scanning.
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancel') || errorStr.contains('cancelled')) {
        // User just backed out, not a real error. Silent exit.
        if (mounted) Navigator.pop(context);
        return;
      }

      debugPrint("Scan error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scanning failed: $e')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Takes separate images from the scanner and merges them into one PDF.
  /// Every page is passed through our "Maximum Bleach" whitening filter.
  Future<void> _convertImagesToPdf(List<String> images) async {
    final pdfService = context.read<PDFService>();
    final storage = context.read<StorageService>();
    final imageProcessor = context.read<ImageProcessingService>();

    setState(() {
      _isScanning = true;
    });

    try {
      final List<String> enhancedImagePaths = [];

      for (int i = 0; i < images.length; i++) {
        final File enhancedFile = await imageProcessor.autoEnhance(
          File(images[i]),
        );
        enhancedImagePaths.add(enhancedFile.path);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = await storage.getNewFilePath("Scan_$timestamp");

      await pdfService.imagesToPdf(enhancedImagePaths, outputPath);

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
    } catch (e) {
      debugPrint("Conversion error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process scan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
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
                  Text('Processing Clear Scan...'),
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
