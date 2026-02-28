import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as dynamic_pdfx;
import '../models/pdf_edit_overlay.dart';

/// Service to handle PDF generation.
class PDFService {
  /// Converts a list of image paths into a single PDF file.
  Future<File> imagesToPdf(List<String> imagePaths, String outputPath) async {
    final PdfDocument document = PdfDocument();

    for (final imagePath in imagePaths) {
      final PdfPage page = document.pages.add();
      final Uint8List imageData = await File(imagePath).readAsBytes();
      final PdfBitmap bitmap = PdfBitmap(imageData);

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

    final List<int> bytes = await document.save();
    document.dispose();

    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Extracts text blocks with bounding boxes from a native (digital) PDF.
  Future<List<PdfTextBlock>> extractTextBlocksFromPdf(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final List<PdfTextBlock> blocks = [];

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      for (int i = 0; i < document.pages.count; i++) {
        final List<TextLine> lines = extractor.extractTextLines(
          startPageIndex: i,
          endPageIndex: i,
        );
        for (var line in lines) {
          blocks.add(
            PdfTextBlock(text: line.text, bounds: line.bounds, pageIndex: i),
          );
        }
      }
      return blocks;
    } finally {
      document.dispose();
    }
  }

  /// Extracts text from each page of a native PDF, with OCR fallback for scanned docs.
  Future<String> extractTextFromPdf(
    String pdfPath, {
    required dynamic ocrService,
  }) async {
    try {
      // 1. Try native extraction first (Fast & Clean)
      final blocks = await extractTextBlocksFromPdf(pdfPath);
      final nativeText = blocks.map((b) => b.text).join('\n').trim();

      if (nativeText.isNotEmpty) return nativeText;

      // 2. Fallback to OCR if no native text is found (Scanned Docs)
      final pdfDocument = await dynamic_pdfx.PdfDocument.openFile(pdfPath);
      String ocrText = "";

      for (int i = 1; i <= pdfDocument.pagesCount; i++) {
        final page = await pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2, // Higher resolution for better OCR
          height: page.height * 2,
          format: dynamic_pdfx.PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/page_$i.jpg');
          await tempFile.writeAsBytes(pageImage.bytes);

          final text = await ocrService.extractTextFromImage(tempFile);
          ocrText += "$text\n";

          await tempFile.delete();
        }
        await page.close();
      }

      await pdfDocument.close();
      return ocrText.trim();
    } catch (e) {
      debugPrint("Extraction failed: $e");
      return "";
    }
  }

  /// Checks if the PDF is primarily image-based (no native extractable text).
  Future<bool> isImageBasedPdf(String pdfPath) async {
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.trim().isEmpty;
    } catch (e) {
      return true; // Assume image-based on error
    }
  }

  /// Creates a new PDF from plain text content.
  Future<File> saveTextAsPdf(
    String text,
    String outputPath, {
    String title = 'Edited Document',
  }) async {
    final PdfDocument document = PdfDocument();

    // Page setup
    const double margin = 40.0;
    const double lineHeight = 18.0;
    const double fontSize = 12.0;
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
    final PdfBrush blackBrush = PdfSolidBrush(PdfColor(0, 0, 0));

    // Split text into lines
    final List<String> lines = text.split('\n');

    PdfPage page = document.pages.add();
    double y = margin;
    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;
    final double usableWidth = pageWidth - margin * 2;

    for (final rawLine in lines) {
      // Word-wrap each line to fit the page width
      final wrappedLines = _wrapLine(rawLine, font, usableWidth);

      for (final wLine in wrappedLines) {
        // Check if we need a new page
        if (y + lineHeight > pageHeight - margin) {
          page = document.pages.add();
          y = margin;
        }

        page.graphics.drawString(
          wLine,
          font,
          brush: blackBrush,
          bounds: Rect.fromLTWH(margin, y, usableWidth, lineHeight),
        );
        y += lineHeight;
      }
      // Blank line between paragraphs
      if (rawLine.isEmpty) y += lineHeight * 0.4;
    }

    final List<int> bytes = await document.save();
    document.dispose();

    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Simple word-wrap helper — breaks a line into segments that fit [maxWidth].
  List<String> _wrapLine(String line, PdfFont font, double maxWidth) {
    if (line.isEmpty) return [''];
    final words = line.split(' ');
    final List<String> result = [];
    String current = '';

    for (final word in words) {
      final test = current.isEmpty ? word : '$current $word';
      final size = font.measureString(test);
      if (size.width > maxWidth && current.isNotEmpty) {
        result.add(current);
        current = word;
      } else {
        current = test;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  Future<File> flattenEditsToPdf(
    String originalPdfPath,
    Map<int, List<PdfEditItem>> edits,
    String outputPath,
  ) async {
    final bytes = await File(originalPdfPath).readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    for (final entry in edits.entries) {
      // Syncfusion uses 0-based indexing for pages, but our UI usually uses 1-based.
      // Assuming our UI pageIndex is 1-based (like PDFx). Adjust if needed.
      final int pdfPageIndex = entry.key - 1;

      if (pdfPageIndex >= 0 && pdfPageIndex < document.pages.count) {
        final PdfPage page = document.pages[pdfPageIndex];
        final PdfGraphics graphics = page.graphics;

        for (final edit in entry.value) {
          if (edit is TextEditItem) {
            final PdfFont font = PdfStandardFont(
              PdfFontFamily.helvetica,
              edit.fontSize * 1.5, // Scaling factor adjustment
            );
            final PdfBrush brush = PdfSolidBrush(
              PdfColor(
                edit.color.r.toInt(),
                edit.color.g.toInt(),
                edit.color.b.toInt(),
                edit.color.a.toInt(),
              ),
            );

            final double px = edit.position.dx * page.getClientSize().width;
            final double py = edit.position.dy * page.getClientSize().height;

            graphics.drawString(
              edit.text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(
                px,
                py,
                page.getClientSize().width - px,
                page.getClientSize().height - py,
              ),
              format: PdfStringFormat(wordWrap: PdfWordWrapType.word),
            );
          } else if (edit is DrawingEditItem && edit.points.isNotEmpty) {
            final PdfPen pen = PdfPen(
              PdfColor(
                edit.color.r.toInt(),
                edit.color.g.toInt(),
                edit.color.b.toInt(),
                edit.color.a.toInt(),
              ),
              width: edit.strokeWidth,
            );
            pen.lineCap = PdfLineCap.round;

            final double pw = page.getClientSize().width;
            final double ph = page.getClientSize().height;

            for (int i = 0; i < edit.points.length - 1; i++) {
              final p1 = Offset(edit.points[i].dx * pw, edit.points[i].dy * ph);
              final p2 = Offset(
                edit.points[i + 1].dx * pw,
                edit.points[i + 1].dy * ph,
              );
              graphics.drawLine(pen, p1, p2);
            }
          }
        }
      }
    }

    final List<int> newBytes = await document.save();
    document.dispose();

    final File newFile = File(outputPath);
    await newFile.writeAsBytes(newBytes);
    return newFile;
  }
}

class PdfTextBlock {
  final String text;
  final Rect bounds;
  final int pageIndex;

  PdfTextBlock({
    required this.text,
    required this.bounds,
    required this.pageIndex,
  });
}
