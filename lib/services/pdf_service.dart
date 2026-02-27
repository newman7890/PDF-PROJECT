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

      final Uint8List imageData = await File(imagePath).readAsBytes();
      final PdfBitmap bitmap = PdfBitmap(imageData);

      // Disable compression for maximum clarity if needed,
      // but Syncfusion handles this well by default.

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

    // 2. Process pages in batches (Throttled for performance/memory)
    const int batchSize = 2;
    final List<String> pageResults = List.filled(pageCount, "");

    for (int i = 0; i < pageCount; i += batchSize) {
      final int end = (i + batchSize < pageCount) ? i + batchSize : pageCount;
      final List<Future<String>> batchTasks = [];
      for (int j = i; j < end; j++) {
        batchTasks.add(_processSinglePage(document, j));
      }
      final results = await Future.wait(batchTasks);
      for (int j = 0; j < results.length; j++) {
        pageResults[i + j] = results[j];
      }
    }

    // 3. Assemble results into Quill Delta
    for (int i = 0; i < pageResults.length; i++) {
      final text = pageResults[i];
      // Always insert page marker so user sees the page exists
      delta.insert("--- Page ${i + 1} ---\n", {"bold": true});
      if (text.isNotEmpty) {
        delta.insert(text);
        delta.insert("\n");
      } else {
        delta.insert("(No text detected on this page)\n");
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
        width: page.width * 1.2, // Further reduced for stability/speed
        height: page.height * 1.2,
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
      extractedText = "[Error on page ${pageIndex + 1}: $e]";
    } finally {
      if (page != null) {
        await page.close();
      }
    }
    return extractedText;
  }

  /// Generates a PDF from Quill Delta.
  Future<File> generatePdfFromDelta(Delta delta, String outputPath) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();

    // Basic plain text extraction for demo
    // Syncfusion PdfTextElement handles automatic pagination
    final String plainText = delta.toList().map((e) => e.data).join();

    final PdfTextElement textElement = PdfTextElement(
      text: plainText,
      font: PdfStandardFont(PdfFontFamily.helvetica, 12),
      brush: PdfBrushes.black,
    );

    final PdfLayoutFormat layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(
        40,
        40,
        page.getClientSize().width - 80,
        page.getClientSize().height - 80,
      ),
      format: layoutFormat,
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
