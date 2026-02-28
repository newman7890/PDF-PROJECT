import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/ocr_service.dart';
import 'package:provider/provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final ScannedDocument document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _copyAllText() async {
    setState(() => _isExtracting = true);
    try {
      final pdfService = context.read<PDFService>();
      final ocrService = context.read<OCRService>();
      final text = await pdfService.extractTextFromPdf(
        widget.document.filePath,
        ocrService: ocrService,
      );
      if (text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No text found.')));
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _export() async {
    try {
      await Share.shareXFiles([
        XFile(widget.document.filePath),
      ], text: widget.document.title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
          widget.document.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isExtracting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.copy_all_rounded),
            onPressed: _isExtracting ? null : _copyAllText,
            tooltip: 'Copy all text',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _export,
            tooltip: 'Share document',
          ),
        ],
      ),
      body: SfPdfViewer.file(
        File(widget.document.filePath),
        controller: _pdfViewerController,
        enableTextSelection: true,
      ),
    );
  }
}
