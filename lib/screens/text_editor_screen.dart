import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/ocr_service.dart';

/// A screen that extracts the text from a PDF and lets the user edit it,
/// then saves the result as a new PDF.
class TextEditorScreen extends StatefulWidget {
  final ScannedDocument document;

  const TextEditorScreen({super.key, required this.document});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _statusMessage = 'Extracting text from PDF...';

  @override
  void initState() {
    super.initState();
    _extractText();
  }

  Future<void> _extractText() async {
    final pdfService = context.read<PDFService>();
    final ocrService = context.read<OCRService>();

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Extracting text from PDF...';
      });

      final text = await pdfService.extractTextFromPdf(
        widget.document.filePath,
        ocrService: ocrService,
      );

      if (!mounted) return;

      if (text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _controller.text =
              '(No text could be extracted. This may be a scanned image-only PDF. '
              'You can still type your content below and save as a new PDF.)';
        });
      } else {
        setState(() {
          _isLoading = false;
          _controller.text = text;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _controller.text = '(Error extracting text: $e)';
      });
    }
  }

  Future<void> _saveAsPdf() async {
    if (_isSaving) return;

    final pdfService = context.read<PDFService>();
    final storageService = context.read<StorageService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving as new PDF...';
    });

    try {
      final baseName = widget.document.title
          .replaceAll('.pdf', '')
          .replaceAll('.PDF', '');
      final newPath = await storageService.getNewFilePath('Edited_$baseName');

      await pdfService.saveTextAsPdf(
        _controller.text,
        newPath,
        title: 'Edited_$baseName',
      );

      final newDoc = ScannedDocument(
        id: DateTime.now().toIso8601String(),
        title: 'Edited_$baseName.pdf',
        filePath: newPath,
        dateCreated: DateTime.now(),
        isPdf: true,
      );

      await storageService.saveDocument(newDoc);

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Saved! New edited PDF is now in your library.'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-extract text',
              onPressed: _extractText,
            ),
          if (!_isLoading)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save_alt),
                    tooltip: 'Save as new PDF',
                    onPressed: _saveAsPdf,
                  ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  color: Colors.indigo.shade50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.indigo.shade400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit the text below, then tap 💾 to save as a new PDF.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Text editor
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.indigo),
                        ),
                        hintText: 'Your PDF text will appear here...',
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
                // Bottom save button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveAsPdf,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_alt),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save as New PDF',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
