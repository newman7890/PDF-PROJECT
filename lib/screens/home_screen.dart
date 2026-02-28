import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../models/scanned_document.dart';
import '../widgets/document_card.dart';
import 'scanner_screen.dart';
import 'viewer_screen.dart' show PdfViewerScreen;
import 'editor_screen.dart';
import 'text_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScannedDocument> _allDocuments = []; // Cache for filtering
  List<ScannedDocument> _filteredDocuments = [];
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final storage = context.read<StorageService>();
    final docs = await storage.loadDocuments();
    setState(() {
      _allDocuments = docs;
      _filteredDocuments = docs;
      _isLoading = false;
    });
  }

  void _filterDocuments(String query) {
    setState(() {
      _filteredDocuments = _allDocuments
          .where((doc) => doc.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
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
      MaterialPageRoute(builder: (context) => PdfViewerScreen(document: doc)),
    ).then((_) => _loadDocuments());
  }

  void _openEditor(ScannedDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(document: doc)),
    ).then((_) => _loadDocuments());
  }

  void _openTextEditor(ScannedDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TextEditorScreen(document: doc)),
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

  void _renameDocument(ScannedDocument doc) async {
    final controller = TextEditingController(
      text: doc.title.replaceAll('.pdf', ''),
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null &&
        newTitle.trim().isNotEmpty &&
        newTitle != doc.title) {
      if (!mounted) return;
      final storage = context.read<StorageService>();
      await storage.renameDocument(doc, newTitle.trim());
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: _filterDocuments,
              )
            : const Text(
                'My Documents',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredDocuments = _allDocuments;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDocuments,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDocuments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _filteredDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = _filteredDocuments[index];
                    return DocumentCard(
                      doc: doc,
                      onTap: () => _openDocument(doc),
                      onShare: () => _shareDocument(doc),
                      onEdit: () => _openEditor(doc),
                      onEditAsText: () => _openTextEditor(doc),
                      onRename: () => _renameDocument(doc),
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
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isSearchEmpty =
        _isSearching && _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchEmpty ? Icons.search_off : Icons.description_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchEmpty ? 'No matches found' : 'No documents yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchEmpty
                ? 'Try a different search term.'
                : 'Tap "Add Document" to scan or import.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          if (!isSearchEmpty) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showAddOptions,
              icon: const Icon(Icons.add),
              label: const Text('Add Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo,
                side: const BorderSide(color: Colors.indigo),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
