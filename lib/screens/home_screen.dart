import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../models/scanned_document.dart';
import '../widgets/document_card.dart';
import 'scanner_screen.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScannedDocument> _documents = [];
  bool _isLoading = true;
  bool _isImporting = false;
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadDocuments();

    // For sharing or opening pdf files while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              _handleExternalPdf(value.first.path);
            }
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // For sharing or opening pdf files when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _handleExternalPdf(value.first.path);
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  void _handleExternalPdf(String filePath) {
    if (!filePath.toLowerCase().endsWith('.pdf')) return;

    // Create a temporary ScannedDocument for the external file
    final doc = ScannedDocument(
      id: "external_${DateTime.now().millisecondsSinceEpoch}",
      title: path.basename(filePath),
      filePath: filePath,
      dateCreated: DateTime.now(),
      isPdf: true,
    );

    _openDocument(doc);
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final storage = context.read<StorageService>();
    final docs = await storage.loadDocuments();
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  void _navigateToScanner() async {
    Navigator.pop(context); // close bottom sheet if open
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    _loadDocuments();
  }

  void _openDocument(ScannedDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(document: doc)),
    ).then((_) => _loadDocuments());
  }

  void _shareDocument(ScannedDocument doc) {
    Share.shareXFiles([
      XFile(doc.filePath),
    ], text: 'Check out this document: ${doc.title}');
  }

  void _deleteDocument(ScannedDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final storage = context.read<StorageService>();
      await storage.deleteDocument(doc);
      _loadDocuments();
    }
  }

  /// Shows a bottom sheet with options: Scan, Pick Images, Pick PDF.
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildOption(
                icon: Icons.camera_alt,
                color: Colors.indigo,
                label: 'Scan Document',
                subtitle: 'Use camera to scan a physical document',
                onTap: _navigateToScanner,
              ),
              const Divider(indent: 16, endIndent: 16),
              _buildOption(
                icon: Icons.photo_library,
                color: Colors.green,
                label: 'Import Images',
                subtitle: 'Pick JPG or PNG from your gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _importImages();
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              _buildOption(
                icon: Icons.picture_as_pdf,
                color: Colors.red,
                label: 'Import PDF',
                subtitle: 'Pick an existing PDF document',
                onTap: () {
                  Navigator.pop(ctx);
                  _importPdf();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  /// Picks one or more images from the gallery and converts them to PDF.
  Future<void> _importImages() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;
        final storage = context.read<StorageService>();
        final pdfService = context.read<PDFService>();

        final imagePaths = result.files
            .map((f) => f.path!)
            .where((p) => p.isNotEmpty)
            .toList();

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final baseName = imagePaths.length == 1
            ? path.basenameWithoutExtension(imagePaths.first)
            : 'Images_$timestamp';

        final finalPath = await storage.getNewFilePath(baseName);
        await pdfService.imagesToPdf(imagePaths, finalPath);

        final doc = ScannedDocument(
          id: DateTime.now().toIso8601String(),
          title: '$baseName.pdf',
          filePath: finalPath,
          dateCreated: DateTime.now(),
          isPdf: true,
        );

        await storage.saveDocument(doc);
        _loadDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                imagePaths.length == 1
                    ? 'Image imported and converted to PDF.'
                    : '${imagePaths.length} images combined into PDF.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Picks a PDF file and saves it to app storage.
  Future<void> _importPdf() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        final storage = context.read<StorageService>();
        final sourcePath = result.files.single.path!;
        final baseName = path.basenameWithoutExtension(sourcePath);
        final finalPath = await storage.getNewFilePath(baseName);

        await File(sourcePath).copy(finalPath);

        final doc = ScannedDocument(
          id: DateTime.now().toIso8601String(),
          title: result.files.single.name,
          filePath: finalPath,
          dateCreated: DateTime.now(),
          isPdf: true,
        );

        await storage.saveDocument(doc);
        _loadDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF imported successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Documents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return DocumentCard(
                      doc: doc,
                      onTap: () => _openDocument(doc),
                      onShare: () => _shareDocument(doc),
                      onDelete: () => _deleteDocument(doc),
                    );
                  },
                ),
          // Importing overlay
          if (_isImporting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Importing...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Document" to scan or import.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _showAddOptions,
            icon: const Icon(Icons.add),
            label: const Text('Add Document'),
          ),
        ],
      ),
    );
  }
}
