import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:flutter_quill/quill_delta.dart';
import 'package:path_provider/path_provider.dart';

/// Service to handle PDF generation, OCR, and editing.
class PDFService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Converts a list of image paths into a single PDF file.
  Future<File> imagesToPdf(List<String> imagePaths, String outputPath) async {
    // Create a new PDF document.
    final PdfDocument document = PdfDocument();

    for (final imagePath in imagePaths) {
      // Add a page to the document.
      final PdfPage page = document.pages.add();

      final Uint8List imageData = File(imagePath).readAsBytesSync();
      final PdfBitmap bitmap = PdfBitmap(imageData);

      // Draw the image onto the PDF page.
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
      );
    }

    // Save the document.
    final List<int> bytes = await document.save();
    document.dispose();

    // Write to the output path.
    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Extracts text from an image file using OCR.
  Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    String text = "";
    for (TextBlock block in recognizedText.blocks) {
      text += "${block.text}\n";
    }

    return text.trim();
  }

  /// Extracts text from each page of a PDF by converting pages to images (logic placeholder).
  /// Note: Syncfusion can extract text directly from PDFs that have text layers.
  Future<String> extractTextFromPdf(String pdfPath) async {
    // For simplicity in this beginner app, we'll assume direct text extraction if possible,
    // or suggest OCR on individual pages if it's a scanned PDF.
    try {
      final PdfDocument document = PdfDocument(
        inputBytes: File(pdfPath).readAsBytesSync(),
      );
      String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      return extractedText;
    } catch (e) {
      return "Could not extract text from this PDF.";
    }
  }

  /// Basic PDF editing: Add a text note to the first page.
  Future<void> addTextToPdf(
    String pdfPath,
    String text,
    double x,
    double y,
  ) async {
    final PdfDocument document = PdfDocument(
      inputBytes: File(pdfPath).readAsBytesSync(),
    );
    final PdfPage page = document.pages[0];

    page.graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(x, y, 200, 50),
    );

    final List<int> bytes = await document.save();
    document.dispose();
    await File(pdfPath).writeAsBytes(bytes);
  }

  /// Extracts text with layout information using OCR.
  Future<Delta> extractTextWithLayout(String pdfPath) async {
    final delta = Delta();

    // 1. Open PDF document
    final document = await pdfx.PdfDocument.openFile(pdfPath);
    final int pageCount = document.pagesCount;

    // 2. Process pages in parallel
    final List<Future<String>> pageTasks = [];
    for (int i = 0; i < pageCount; i++) {
      pageTasks.add(_processSinglePage(document, i));
    }

    final List<String> pageResults = await Future.wait(pageTasks);

    // 3. Assemble results into Quill Delta
    for (var text in pageResults) {
      if (text.isNotEmpty) {
        delta.insert(text);
      }
    }

    await document.close();
    return delta;
  }

  /// Helper method to process a single page for parallel OCR
  Future<String> _processSinglePage(
    pdfx.PdfDocument document,
    int pageIndex,
  ) async {
    String extractedText = "";
    pdfx.PdfPage? page;
    try {
      page = await document.getPage(pageIndex + 1);
      final pageImage = await page.render(
        width: page.width * 1.5, // Optimized resolution for speed
        height: page.height * 1.5,
        format: pdfx.PdfPageImageFormat.jpeg,
      );

      if (pageImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}_$pageIndex.jpg';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(pageImage.bytes);

        final inputImage = InputImage.fromFilePath(tempPath);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        final StringBuffer sb = StringBuffer();
        for (var block in recognizedText.blocks) {
          sb.writeln(block.text);
        }
        extractedText = sb.toString();

        // Cleanup temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint("Error processing page $pageIndex: $e");
    } finally {
      if (page != null) {
        await page.close();
      }
    }
    return extractedText;
  }

  /// Extracts text directly from a digital PDF using Syncfusion's text extractor.
  Future<Delta> extractTextDirectlyToDelta(String pdfPath) async {
    final delta = Delta();
    try {
      final PdfDocument document = PdfDocument(
        inputBytes: File(pdfPath).readAsBytesSync(),
      );

      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (extractedText.isNotEmpty) {
        delta.insert(extractedText);
      } else {
        delta.insert("No text found in this document layer.\n");
      }
    } catch (e) {
      delta.insert("Error extracting text: $e\n");
    }
    return delta;
  }

  /// Generates a PDF from Quill Delta.
  Future<File> generatePdfFromDelta(Delta delta, String outputPath) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();

    // Basic text drawing from delta
    // In a real app, this would iterate over delta attributes (bold, size, etc.)
    final String plainText = delta.toList().map((e) => e.data).join();

    page.graphics.drawString(
      plainText,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(
        40,
        40,
        page.getClientSize().width - 80,
        page.getClientSize().height - 80,
      ),
    );

    final List<int> bytes = await document.save();
    document.dispose();
    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Close resources.
  void dispose() {
    _textRecognizer.close();
  }
}
