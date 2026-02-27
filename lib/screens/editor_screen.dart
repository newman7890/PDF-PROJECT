import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class EditorScreen extends StatefulWidget {
  final ScannedDocument document;

  const EditorScreen({super.key, required this.document});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late String _filePath;
  bool _isProcessing = false;
  bool _isEditing = false;
  quill.QuillController? _quillController;

  @override
  void initState() {
    super.initState();
    _filePath = widget.document.filePath;
  }

  void _runOCR() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = "Preparing document...";
    });
    final pdfService = context.read<PDFService>();

    try {
      final delta = await pdfService.extractTextWithLayout(_filePath);

      setState(() {
        _quillController = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _quillController!.readOnly = false;
        _isEditing = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR completed. Document is now editable.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR failed: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _processingMessage = "Processing...";

  void _saveChanges() async {
    if (_quillController == null) return;

    setState(() => _isProcessing = true);
    final pdfService = context.read<PDFService>();

    try {
      final delta = _quillController!.document.toDelta();
      // Regenerate PDF from delta
      await pdfService.generatePdfFromDelta(delta, _filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully.')),
        );
      }

      // Auto-share/export after saving
      _shareDocument();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addNote() async {
    final TextEditingController controller = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter your note here...",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (note != null && note.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isProcessing = true);
      final pdfService = context.read<PDFService>();

      try {
        await pdfService.addTextToPdf(
          _filePath,
          note,
          50,
          50,
        ); // Fixed position for demo
        setState(() {
          // Force reload PDF viewer by updating path (hacky but works for demo)
          _filePath = widget.document.filePath;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Note added to PDF.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add note: $e')));
        }
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _shareDocument() {
    Share.shareXFiles([XFile(_filePath)], text: widget.document.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDocument,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isEditing)
            SfPdfViewer.file(File(_filePath), key: _pdfViewerKey)
          else
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: quill.QuillSimpleToolbar(
                    controller: _quillController!,
                    config: const quill.QuillSimpleToolbarConfig(
                      showFontFamily: false,
                      showFontSize: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showSmallButton: false,
                      showUnderLineButton: true,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showColorButton: true,
                      showBackgroundColorButton: false,
                      showClearFormat: true,
                      showAlignmentButtons: true,
                      showLeftAlignment: true,
                      showCenterAlignment: true,
                      showRightAlignment: true,
                      showJustifyAlignment: false,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: false,
                      showUndo: true,
                      showRedo: true,
                      showDirection: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: quill.QuillEditor.basic(
                      controller: _quillController!,
                    ),
                  ),
                ),
              ],
            ),
          if (_isProcessing)
            Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_processingMessage),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!_isEditing) ...[
              _buildActionButton(
                icon: Icons.text_snippet,
                label: 'OCR Edit',
                onPressed: _runOCR,
              ),
            ] else
              _buildActionButton(
                icon: Icons.save,
                label: 'Save',
                onPressed: _saveChanges,
              ),
            _buildActionButton(
              icon: Icons.edit_note,
              label: 'Add Note',
              onPressed: _addNote,
            ),
            _buildActionButton(
              icon: Icons.draw,
              label: 'Sign',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signature feature coming soon!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.indigo),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ],
        ),
      ),
    );
  }
}
