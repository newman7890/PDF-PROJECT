import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/ocr_service.dart';
import '../services/rich_text_service.dart';
import 'signature_pad_screen.dart';

/// A screen that extracts the text from a PDF and lets the user edit it,
/// then saves the result as a new PDF.
class TextEditorScreen extends StatefulWidget {
  final ScannedDocument document;

  const TextEditorScreen({super.key, required this.document});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final StyledTextController _controller = StyledTextController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _statusMessage = 'Extracting text from PDF...';
  List<Offset>? _signaturePoints; // Captured signature points

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
        signaturePoints: _signaturePoints,
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share as PDF',
            onPressed: () {
              // Share functionality
              Share.shareXFiles([XFile(widget.document.filePath)]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: 'Download',
            onPressed: _saveAsPdf, // In this context, save is like download
          ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-extract text',
              onPressed: _extractText,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, _) =>
                        CircularProgressIndicator(value: value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Text editor container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildFormattingToolbar(),
                        const Divider(height: 1),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              fontFamily: 'Roboto',
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'Start typing or editing your document...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              contentPadding: const EdgeInsets.all(20),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom UI
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_controller.text.length} characters',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveAsPdf,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(_isSaving ? 'Saving...' : 'SAVE CHANGES'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.undo,
              onPressed: _controller.undo,
              tooltip: 'Undo',
            ),
            _ToolbarButton(
              icon: Icons.redo,
              onPressed: _controller.redo,
              tooltip: 'Redo',
            ),
            const VerticalDivider(width: 16),
            _ToolbarButton(
              icon: Icons.format_bold,
              onPressed: _controller.toggleBold,
              tooltip: 'Bold',
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              onPressed: _controller.toggleItalic,
              tooltip: 'Italic',
            ),
            _ToolbarButton(
              icon: Icons.format_underlined,
              onPressed: _controller.toggleUnderline,
              tooltip: 'Underline',
            ),
            _ToolbarButton(
              icon: Icons.format_strikethrough,
              onPressed: _controller.toggleStrikethrough,
              tooltip: 'Strikethrough',
            ),
            const VerticalDivider(width: 16),
            _ToolbarButton(
              icon: Icons.format_align_left,
              onPressed: () => _controller.setAlignment('left'),
              tooltip: 'Align Left',
            ),
            _ToolbarButton(
              icon: Icons.format_align_center,
              onPressed: () => _controller.setAlignment('center'),
              tooltip: 'Align Center',
            ),
            _ToolbarButton(
              icon: Icons.format_align_right,
              onPressed: () => _controller.setAlignment('right'),
              tooltip: 'Align Right',
            ),
            const VerticalDivider(width: 16),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              onPressed: _controller.toggleBulletList,
              tooltip: 'Bullet List',
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered,
              onPressed: _controller.toggleNumberedList,
              tooltip: 'Numbered List',
            ),
            _ToolbarButton(
              icon: Icons.horizontal_rule,
              onPressed: _controller.insertHorizontalRule,
              tooltip: 'Horizontal Rule',
            ),

            const VerticalDivider(width: 16),
            _ToolbarButton(
              text: 'H1',
              onPressed: _controller.toggleH1,
              tooltip: 'Heading 1',
            ),
            _ToolbarButton(
              text: 'H2',
              onPressed: _controller.toggleH2,
              tooltip: 'Heading 2',
            ),
            const VerticalDivider(width: 16),
            _ToolbarButton(
              icon: Icons.gesture,
              onPressed: () async {
                final points = await Navigator.push<List<Offset>>(
                  context,
                  MaterialPageRoute(builder: (c) => const SignaturePadScreen()),
                );
                if (points != null && points.isNotEmpty && mounted) {
                  setState(() => _signaturePoints = points);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '✅ Signature captured! Tap "SAVE CHANGES" to embed it in the PDF.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              tooltip: 'Add Signature',
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onPressed;
  final String tooltip;

  const _ToolbarButton({
    this.icon,
    this.text,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon != null
          ? Icon(icon, size: 20)
          : Text(
              text!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: Colors.indigo,
    );
  }
}
