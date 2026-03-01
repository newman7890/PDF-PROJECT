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
      final blocks = await extractTextBlocksFromPdf(pdfPath);
      final nativeText = blocks.map((b) => b.text).join('\n').trim();

      // Fallback to OCR if native text is mostly garbage/non-alphanumeric
      bool isMeaningful = false;
      if (nativeText.isNotEmpty) {
        final alphaCount = nativeText
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .length;
        if (alphaCount > 15 ||
            (nativeText.length < 30 && alphaCount > nativeText.length * 0.4)) {
          isMeaningful = true;
        }
      }

      if (isMeaningful) return nativeText;
      final pdfDocument = await dynamic_pdfx.PdfDocument.openFile(pdfPath);
      String ocrText = "";

      for (int i = 1; i <= pdfDocument.pagesCount; i++) {
        final page = await pdfDocument.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
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

  /// Checks if the PDF is primarily image-based.
  Future<bool> isImageBasedPdf(String pdfPath) async {
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText().trim();
      document.dispose();

      if (text.isEmpty) return true;
      final alphaCount = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length;
      return alphaCount <= 15 && alphaCount <= text.length * 0.4;
    } catch (e) {
      return true;
    }
  }

  /// Creates a new PDF with mixed styling support.
  Future<File> saveTextAsPdf(
    String text,
    String outputPath, {
    String title = 'Edited Document',
    List<Offset>? signaturePoints,
  }) async {
    final PdfDocument document = PdfDocument();

    const double margin = 40.0;

    PdfPage page = document.pages.add();
    double y = margin;
    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;
    final double usableWidth = pageWidth - margin * 2;

    final List<String> rawLines = text.split('\n');

    for (final rawLine in rawLines) {
      if (rawLine.isEmpty) {
        y += 10.0;
        continue;
      }

      // Handle Horizontal Rule
      if (rawLine.trim() == '---') {
        page.graphics.drawLine(
          PdfPen(PdfColor(200, 200, 200), width: 1),
          Offset(margin, y + 5),
          Offset(pageWidth - margin, y + 5),
        );
        y += 15.0;
        continue;
      }

      // Parse line into styled chunks
      final chunks = _parseStyledLine(rawLine);

      // We need to wrap these chunks if they exceed usableWidth
      // This is a simplified wrap: we draw line by line
      double x = margin;
      double maxLineHeight = 18.0;

      for (var chunk in chunks) {
        final font = PdfStandardFont(
          PdfFontFamily.helvetica,
          chunk.fontSize,
          style: chunk.style,
        );

        // Split chunk text if it's too wide for the REMAINING width
        final wrapped = _wrapLine(chunk.text, font, usableWidth - (x - margin));

        for (int i = 0; i < wrapped.length; i++) {
          final wText = wrapped[i];
          final size = font.measureString(wText);

          if (x + size.width > pageWidth - margin && i == 0) {
            // New line if first part doesn't fit
            y += maxLineHeight;
            x = margin;
            if (y > pageHeight - margin) {
              page = document.pages.add();
              y = margin;
            }
          }

          page.graphics.drawString(
            wText,
            font,
            brush: PdfSolidBrush(chunk.color),
            bounds: Rect.fromLTWH(x, y, size.width + 2, 30),
          );

          if (chunk.isUnderline) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(x, y + chunk.fontSize * 0.95),
              Offset(x + size.width, y + chunk.fontSize * 0.95),
            );
          }
          if (chunk.isStrike) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(x, y + chunk.fontSize * 0.5),
              Offset(x + size.width, y + chunk.fontSize * 0.5),
            );
          }

          if (i < wrapped.length - 1) {
            // Chunk was wrapped, move to next line
            y += maxLineHeight;
            x = margin;
            if (y > pageHeight - margin) {
              page = document.pages.add();
              y = margin;
            }
          } else {
            x += size.width;
          }
        }
        if (chunk.fontSize > maxLineHeight) {
          maxLineHeight = chunk.fontSize * 1.4;
        }
      }
      y += maxLineHeight;

      if (y > pageHeight - margin) {
        page = document.pages.add();
        y = margin;
      }
    }

    // Render signature at the bottom of the last page if provided
    if (signaturePoints != null && signaturePoints.isNotEmpty) {
      const double sigBoxWidth = 180.0;
      const double sigBoxHeight = 60.0;
      final double sigX = margin;
      double sigY = y + 20;

      // Add a new page if signature won't fit
      if (sigY + sigBoxHeight + 30 > pageHeight - margin) {
        page = document.pages.add();
        sigY = margin;
      }

      // Label
      final sigLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      page.graphics.drawString(
        'Signature:',
        sigLabelFont,
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
        bounds: Rect.fromLTWH(sigX, sigY, 100, 14),
      );
      sigY += 16;

      // Signature border box
      page.graphics.drawRectangle(
        pen: PdfPen(PdfColor(200, 200, 200)),
        bounds: Rect.fromLTWH(sigX, sigY, sigBoxWidth, sigBoxHeight),
      );

      // Normalise and draw signature strokes inside the box
      double minX = signaturePoints[0].dx;
      double minY = signaturePoints[0].dy;
      double maxX = signaturePoints[0].dx;
      double maxY = signaturePoints[0].dy;
      for (final p in signaturePoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      final double srcW = (maxX - minX) == 0 ? 1 : (maxX - minX);
      final double srcH = (maxY - minY) == 0 ? 1 : (maxY - minY);

      final sigPen = PdfPen(PdfColor(0, 0, 0), width: 2.5);
      sigPen.lineCap = PdfLineCap.round;
      const double pad = 6.0;

      Offset normSig(Offset raw) => Offset(
        sigX + pad + (raw.dx - minX) / srcW * (sigBoxWidth - pad * 2),
        sigY + pad + (raw.dy - minY) / srcH * (sigBoxHeight - pad * 2),
      );

      for (int i = 0; i < signaturePoints.length - 1; i++) {
        page.graphics.drawLine(
          sigPen,
          normSig(signaturePoints[i]),
          normSig(signaturePoints[i + 1]),
        );
      }

      // Underline
      page.graphics.drawLine(
        PdfPen(PdfColor(150, 150, 150)),
        Offset(sigX, sigY + sigBoxHeight + 4),
        Offset(sigX + sigBoxWidth, sigY + sigBoxHeight + 4),
      );
    }

    // Render signature at the bottom of the last page if provided
    if (signaturePoints != null && signaturePoints.isNotEmpty) {
      const double sigBoxWidth = 180.0;
      const double sigBoxHeight = 60.0;
      final double sigX = margin;
      double sigY = y + 20;

      // Add a new page if signature won't fit
      if (sigY + sigBoxHeight + 30 > pageHeight - margin) {
        page = document.pages.add();
        sigY = margin;
      }

      // Label
      final sigLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      page.graphics.drawString(
        'Signature:',
        sigLabelFont,
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
        bounds: Rect.fromLTWH(sigX, sigY, 100, 14),
      );
      sigY += 16;

      // Signature border box
      page.graphics.drawRectangle(
        pen: PdfPen(PdfColor(200, 200, 200)),
        bounds: Rect.fromLTWH(sigX, sigY, sigBoxWidth, sigBoxHeight),
      );

      // Normalise and draw signature strokes inside the box
      double minX = signaturePoints[0].dx;
      double minY = signaturePoints[0].dy;
      double maxX = signaturePoints[0].dx;
      double maxY = signaturePoints[0].dy;
      for (final p in signaturePoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      final double srcW = (maxX - minX) == 0 ? 1 : (maxX - minX);
      final double srcH = (maxY - minY) == 0 ? 1 : (maxY - minY);

      final sigPen = PdfPen(PdfColor(0, 0, 0), width: 2.5);
      sigPen.lineCap = PdfLineCap.round;
      const double pad = 6.0;

      Offset normSig(Offset raw) => Offset(
        sigX + pad + (raw.dx - minX) / srcW * (sigBoxWidth - pad * 2),
        sigY + pad + (raw.dy - minY) / srcH * (sigBoxHeight - pad * 2),
      );

      for (int i = 0; i < signaturePoints.length - 1; i++) {
        page.graphics.drawLine(
          sigPen,
          normSig(signaturePoints[i]),
          normSig(signaturePoints[i + 1]),
        );
      }

      // Underline
      page.graphics.drawLine(
        PdfPen(PdfColor(150, 150, 150)),
        Offset(sigX, sigY + sigBoxHeight + 4),
        Offset(sigX + sigBoxWidth, sigY + sigBoxHeight + 4),
      );
    }

    final List<int> bytes = await document.save();
    document.dispose();

    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  List<StyledChunk> _parseStyledLine(String line) {
    final List<StyledChunk> chunks = [];
    final regExp = RegExp(
      r'(\*\*.*?\*\*)|(\*.*?\*)|(__.*?__)|(~~.*?~~)|(\[H1\].*?\[/H1\])|(\[H2\].*?\[/H2\])|(\[H3\].*?\[/H3\])|(^- .*?$|^- .*?\n)|(^\d+\. .*?$|^\d+\. .*?\n)|(\[:color:#[0-9a-fA-F]{6}:\])',
    );

    int lastMatchEnd = 0;
    PdfColor currentColor = PdfColor(0, 0, 0);

    for (var match in regExp.allMatches(line)) {
      // Add plain text before match
      if (match.start > lastMatchEnd) {
        chunks.add(
          StyledChunk(
            text: line.substring(lastMatchEnd, match.start),
            color: currentColor,
          ),
        );
      }

      final mText = match.group(0)!;
      if (mText.startsWith('[:color:')) {
        final hex = mText.substring(8, 15);
        try {
          final r = int.parse(hex.substring(1, 3), radix: 16);
          final g = int.parse(hex.substring(3, 5), radix: 16);
          final b = int.parse(hex.substring(5, 7), radix: 16);
          currentColor = PdfColor(r, g, b);
        } catch (_) {}
      } else if (mText.startsWith('**')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(2, mText.length - 2),
            style: PdfFontStyle.bold,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('*')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(1, mText.length - 1),
            style: PdfFontStyle.italic,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('__')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(2, mText.length - 2),
            isUnderline: true,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('~~')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(2, mText.length - 2),
            isStrike: true,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('[H1]')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(4, mText.length - 5),
            style: PdfFontStyle.bold,
            fontSize: 22,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('- ') || RegExp(r'^\d+\. ').hasMatch(mText)) {
        // Auto-bold lists
        chunks.add(
          StyledChunk(
            text: mText.trim(),
            style: PdfFontStyle.bold,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('[H2]')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(4, mText.length - 5),
            style: PdfFontStyle.bold,
            fontSize: 18,
            color: currentColor,
          ),
        );
      } else if (mText.startsWith('[H3]')) {
        chunks.add(
          StyledChunk(
            text: mText.substring(4, mText.length - 5),
            style: PdfFontStyle.bold,
            fontSize: 14,
            color: currentColor,
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    // Add remaining plain text
    if (lastMatchEnd < line.length) {
      chunks.add(
        StyledChunk(text: line.substring(lastMatchEnd), color: currentColor),
      );
    }

    return chunks;
  }

  String _cleanFormatting(String text) {
    if (text.isEmpty) return "";
    return text
        .replaceAllMapped(
          RegExp(r'\[H\d\].*?\[/H\d\]'),
          (m) => m.group(0)!.substring(4, m.group(0)!.length - 5),
        )
        .replaceAll('***', '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('___', '')
        .replaceAll('__', '')
        .replaceAll('_', '')
        .replaceAll('~~~', '')
        .replaceAll('~~', '')
        .replaceAll('~', '')
        .replaceAll(RegExp(r'\[/H\d\]'), '')
        .replaceAll(RegExp(r'\[H\d\]'), '')
        .replaceAll(RegExp(r'\[:.*?:\]'), '')
        .trim();
  }

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
      final int pdfPageIndex = entry.key - 1;

      if (pdfPageIndex >= 0 && pdfPageIndex < document.pages.count) {
        final PdfPage page = document.pages[pdfPageIndex];
        final PdfGraphics graphics = page.graphics;

        for (final edit in entry.value) {
          if (edit is TextEditItem) {
            final String cleanText = _cleanFormatting(edit.text);

            PdfFontStyle fontStyle = PdfFontStyle.regular;
            if (edit.isBold || edit.isH1 || edit.isH2) {
              fontStyle = PdfFontStyle.bold;
            }
            if (edit.isItalic && fontStyle != PdfFontStyle.bold) {
              fontStyle = PdfFontStyle.italic;
            }

            double pdfFontSize = edit.fontSize * 1.5;
            if (edit.isH1) {
              pdfFontSize *= 1.8;
            } else if (edit.isH2) {
              pdfFontSize *= 1.4;
            }

            final PdfFont font = PdfStandardFont(
              PdfFontFamily.helvetica,
              pdfFontSize,
              style: fontStyle,
            );

            final PdfColor color = PdfColor(
              (edit.color.r * 255).round().clamp(0, 255),
              (edit.color.g * 255).round().clamp(0, 255),
              (edit.color.b * 255).round().clamp(0, 255),
              (edit.color.a * 255).round().clamp(0, 255),
            );

            final double px = edit.position.dx * page.getClientSize().width;
            final double py = edit.position.dy * page.getClientSize().height;

            graphics.drawString(
              cleanText,
              font,
              brush: PdfSolidBrush(color),
              bounds: Rect.fromLTWH(
                px,
                py,
                1000,
                1000,
              ), // Large bounds for simplicity
            );

            if (edit.isUnderline) {
              graphics.drawLine(
                PdfPen(color, width: 0.8),
                Offset(px, py + pdfFontSize * 0.95),
                Offset(
                  px + font.measureString(cleanText).width,
                  py + pdfFontSize * 0.95,
                ),
              );
            }
            if (edit.isStrikethrough) {
              graphics.drawLine(
                PdfPen(color, width: 0.8),
                Offset(px, py + pdfFontSize * 0.5),
                Offset(
                  px + font.measureString(cleanText).width,
                  py + pdfFontSize * 0.5,
                ),
              );
            }
          } else if (edit is DrawingEditItem && edit.points.isNotEmpty) {
            final PdfPen pen = PdfPen(
              PdfColor(
                (edit.color.r * 255).round().clamp(0, 255),
                (edit.color.g * 255).round().clamp(0, 255),
                (edit.color.b * 255).round().clamp(0, 255),
                (edit.color.a * 255).round().clamp(0, 255),
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

class StyledChunk {
  final String text;
  final PdfFontStyle style;
  final double fontSize;
  final PdfColor color;
  final bool isUnderline;
  final bool isStrike;

  StyledChunk({
    required this.text,
    this.style = PdfFontStyle.regular,
    this.fontSize = 12.0,
    required this.color,
    this.isUnderline = false,
    this.isStrike = false,
  });
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
