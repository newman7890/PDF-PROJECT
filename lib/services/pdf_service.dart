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
      final bytes = await File(pdfPath).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String nativeText = '';
      try {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        for (int i = 0; i < document.pages.count; i++) {
          final lines = extractor.extractTextLines(
            startPageIndex: i,
            endPageIndex: i,
          );

          lines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

          List<List<TextLine>> clusteredLines = [];
          for (var line in lines) {
            if (clusteredLines.isEmpty) {
              clusteredLines.add([line]);
            } else {
              var lastCluster = clusteredLines.last;
              // A threshold of 5-8 points usually captures the same visual line
              if ((line.bounds.top - lastCluster.first.bounds.top).abs() < 7) {
                lastCluster.add(line);
              } else {
                clusteredLines.add([line]);
              }
            }
          }

          for (var cluster in clusteredLines) {
            cluster.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
            // Joining with multiple spaces to preserve some "column" feel
            nativeText += '${cluster.map((l) => l.text).join('   ')}\n';
          }
          nativeText += '\n[PAGE ${i + 1}]\n\n';
        }
        nativeText = nativeText.trim();
      } finally {
        document.dispose();
      }

      // If native extraction is not meaningful, try OCR
      if (!_isMeaningful(nativeText)) {
        final pdfDocument = await dynamic_pdfx.PdfDocument.openFile(pdfPath);
        try {
          String ocrText = "";

          for (int i = 1; i <= pdfDocument.pagesCount; i++) {
            final page = await pdfDocument.getPage(i);
            try {
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
                if (text.trim().isNotEmpty) {
                  ocrText += "$text\n\n[PAGE $i]\n\n";
                }

                await tempFile.delete();
              }
            } finally {
              await page.close();
            }
          }
          return ocrText.trim();
        } finally {
          await pdfDocument.close();
        }
      }

      return nativeText;
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

    // Parse the entire text into styled chunks
    final List<StyledChunk> chunks = _parseStyledLine(text);

    double x = margin;
    double maxLineHeight = 18.0;

    for (var chunk in chunks) {
      final font = PdfStandardFont(
        PdfFontFamily.helvetica,
        chunk.fontSize,
        style: chunk.style,
      );

      // Handle horizontal rule chunk specifically
      if (chunk.text == '---') {
        // Force newline if not at start
        if (x > margin) {
          y += maxLineHeight;
          x = margin;
        }
        page.graphics.drawLine(
          PdfPen(PdfColor(200, 200, 200), width: 1),
          Offset(margin, y + 5),
          Offset(pageWidth - margin, y + 5),
        );
        y += 15.0;
        if (y > pageHeight - margin) {
          page = document.pages.add();
          y = margin;
        }
        continue;
      }

      // Split chunk by newlines to respect manual line breaks
      final List<String> linesInChunk = chunk.text.split('\n');

      for (int lineIdx = 0; lineIdx < linesInChunk.length; lineIdx++) {
        final lineText = linesInChunk[lineIdx];

        // If this is a subsequent line in the same chunk, reset x and move y
        if (lineIdx > 0) {
          y += maxLineHeight;
          x = margin;
          // Reset maxLineHeight for the new line
          maxLineHeight = 18.0;
          if (y > pageHeight - margin) {
            page = document.pages.add();
            y = margin;
          }
        }

        if (lineText.isEmpty) {
          // If we have an empty line (multiple \n), still increment y
          if (lineIdx > 0) y += 5.0;
          continue;
        }

        // Update maxLineHeight based on this chunk's requirements for the current line
        if (chunk.fontSize * 1.4 > maxLineHeight) {
          maxLineHeight = chunk.fontSize * 1.4;
        }

        final words = lineText.split(' ');
        String currentStr = '';

        for (int i = 0; i < words.length; i++) {
          final String word = words[i];
          final bool hasSpace = i < words.length - 1;
          final String piece = word + (hasSpace ? ' ' : '');

          final String testStr = currentStr + piece;
          final Size testSize = font.measureString(testStr);

          if (x + testSize.width > pageWidth - margin &&
              currentStr.isNotEmpty) {
            // Draw current line buffer
            final Size cSize = font.measureString(currentStr);
            page.graphics.drawString(
              currentStr,
              font,
              brush: PdfSolidBrush(chunk.color),
              bounds: Rect.fromLTWH(x, y, cSize.width + 2, maxLineHeight + 10),
            );

            // Underline/Strike handling
            if (chunk.isUnderline) {
              page.graphics.drawLine(
                PdfPen(chunk.color, width: 0.8),
                Offset(x, y + chunk.fontSize * 0.95),
                Offset(
                  x + font.measureString(currentStr.trimRight()).width,
                  y + chunk.fontSize * 0.95,
                ),
              );
            }
            if (chunk.isStrike) {
              page.graphics.drawLine(
                PdfPen(chunk.color, width: 0.8),
                Offset(x, y + chunk.fontSize * 0.5),
                Offset(
                  x + font.measureString(currentStr.trimRight()).width,
                  y + chunk.fontSize * 0.5,
                ),
              );
            }

            y += maxLineHeight;
            x = margin;
            if (y > pageHeight - margin) {
              page = document.pages.add();
              y = margin;
            }
            currentStr = piece;
          } else {
            currentStr = testStr;
          }
        }

        if (currentStr.isNotEmpty) {
          final Size cSize = font.measureString(currentStr);
          page.graphics.drawString(
            currentStr,
            font,
            brush: PdfSolidBrush(chunk.color),
            bounds: Rect.fromLTWH(x, y, cSize.width + 2, maxLineHeight + 10),
          );

          if (chunk.isUnderline) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(x, y + chunk.fontSize * 0.95),
              Offset(
                x + font.measureString(currentStr.trimRight()).width,
                y + chunk.fontSize * 0.95,
              ),
            );
          }
          if (chunk.isStrike) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(x, y + chunk.fontSize * 0.5),
              Offset(
                x + font.measureString(currentStr.trimRight()).width,
                y + chunk.fontSize * 0.5,
              ),
            );
          }
          x += cSize.width;
        }
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

    final List<int> bytes = await document.save();
    document.dispose();

    final File file = File(outputPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  List<StyledChunk> _parseStyledLine(String text) {
    return _parseRecursive(
      text,
      PdfFontStyle.regular,
      12.0,
      PdfColor(0, 0, 0),
      false,
      false,
    );
  }

  List<StyledChunk> _parseRecursive(
    String text,
    PdfFontStyle currentStyle,
    double currentFontSize,
    PdfColor currentColor,
    bool currentUnderline,
    bool currentStrike,
  ) {
    if (text.isEmpty) return [];
    final List<StyledChunk> chunks = [];

    // Prioritize headers and expanded markdown in the regex
    final regExp = RegExp(
      r'(\*\*\*[\s\S]*?\*\*\*)|' // Bold+Italic
      r'(\[(?:H1|h1)\][\s\S]*?\[/(?:H1|h1)\]|^\s*#\s+.*?$)|' // H1
      r'(\[(?:H2|h2)\][\s\S]*?\[/(?:H2|h2)\]|^\s*##\s+.*?$)|' // H2
      r'(\[(?:H3|h3)\][\s\S]*?\[/(?:H3|h3)\]|^\s*###\s+.*?$)|' // H3
      r'(\*\*[\s\S]*?\*\*)|' // Bold
      r'(\*[\s\S]*?\*)|' // Italic
      r'(__[\s\S]*?__)|' // Underline
      r'(~~[\s\S]*?~~)|' // Strike
      r'(^- .*?$|^- .*?\n)|' // Bullet
      r'(^\d+\. .*?$|^\d+\. .*?\n)|' // Numbered
      r'(^---+$|^---+\n)|' // HR
      r'(\[/?(?:H1|h1|H2|h2|H3|h3)\]|\*\*\*|\*\*|\*|__|~~|---+|#+|\[:[\s\S]*?:\])', // Catch-all for stray markers
      multiLine: true,
    );

    int lastMatchEnd = 0;

    const double h1Size = 22.0;
    const double h2Size = 18.0;
    const double h3Size = 14.0;

    for (var match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        chunks.add(
          StyledChunk(
            text: text.substring(lastMatchEnd, match.start),
            style: currentStyle,
            fontSize: currentFontSize,
            color: currentColor,
            isUnderline: currentUnderline,
            isStrike: currentStrike,
          ),
        );
      }

      final mText = match.group(0)!;

      if (match.group(12) != null) {
        // Color / Meta
        if (mText.startsWith('[:color:') && mText.endsWith(':]')) {
          final hex = mText.substring(8, mText.length - 2);
          try {
            final r = int.parse(hex.substring(1, 3), radix: 16);
            final g = int.parse(hex.substring(3, 5), radix: 16);
            final b = int.parse(hex.substring(5, 7), radix: 16);
            currentColor = PdfColor(r, g, b);
          } catch (_) {}
        }
      } else if (match.group(1) != null) {
        // *** Bold + Italic ***
        chunks.addAll(
          _parseRecursive(
            mText.substring(3, mText.length - 3),
            PdfFontStyle
                .bold, // We'll use bold as fallback if boldItalic is missing
            currentFontSize,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(2) != null) {
        // H1
        String content;
        if (mText.toLowerCase().startsWith('[h1]')) {
          content = mText.substring(4, mText.length - 5);
        } else {
          final hashMatch = RegExp(r'^\s*#\s+').firstMatch(mText)!;
          content = mText.substring(hashMatch.group(0)!.length);
        }
        chunks.addAll(
          _parseRecursive(
            content,
            PdfFontStyle.bold,
            h1Size,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(3) != null) {
        // H2
        String content;
        if (mText.toLowerCase().startsWith('[h2]')) {
          content = mText.substring(4, mText.length - 5);
        } else {
          final hashMatch = RegExp(r'^\s*##\s+').firstMatch(mText)!;
          content = mText.substring(hashMatch.group(0)!.length);
        }
        chunks.addAll(
          _parseRecursive(
            content,
            PdfFontStyle.bold,
            h2Size,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(4) != null) {
        // H3
        String content;
        if (mText.toLowerCase().startsWith('[h3]')) {
          content = mText.substring(4, mText.length - 5);
        } else {
          final hashMatch = RegExp(r'^\s*###\s+').firstMatch(mText)!;
          content = mText.substring(hashMatch.group(0)!.length);
        }
        chunks.addAll(
          _parseRecursive(
            content,
            PdfFontStyle.bold,
            h3Size,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(5) != null) {
        // Bold **
        chunks.addAll(
          _parseRecursive(
            mText.substring(2, mText.length - 2),
            PdfFontStyle.bold,
            currentFontSize,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(6) != null) {
        // Italic *
        chunks.addAll(
          _parseRecursive(
            mText.substring(1, mText.length - 1),
            PdfFontStyle.italic,
            currentFontSize,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(7) != null) {
        // Underline __
        chunks.addAll(
          _parseRecursive(
            mText.substring(2, mText.length - 2),
            currentStyle,
            currentFontSize,
            currentColor,
            true,
            currentStrike,
          ),
        );
      } else if (match.group(8) != null) {
        // Strike ~~
        chunks.addAll(
          _parseRecursive(
            mText.substring(2, mText.length - 2),
            currentStyle,
            currentFontSize,
            currentColor,
            currentUnderline,
            true,
          ),
        );
      } else if (match.group(9) != null) {
        // Bullet
        chunks.add(
          StyledChunk(
            text: '• ',
            style: PdfFontStyle.bold,
            fontSize: currentFontSize,
            color: currentColor,
          ),
        );
        chunks.addAll(
          _parseRecursive(
            mText.substring(2).trim(),
            currentStyle,
            currentFontSize,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(10) != null) {
        // Numbered list
        final dotIndex = mText.indexOf('. ');
        chunks.add(
          StyledChunk(
            text: mText.substring(0, dotIndex + 2),
            style: PdfFontStyle.bold,
            fontSize: currentFontSize,
            color: currentColor,
          ),
        );
        chunks.addAll(
          _parseRecursive(
            mText.substring(dotIndex + 2).trim(),
            currentStyle,
            currentFontSize,
            currentColor,
            currentUnderline,
            currentStrike,
          ),
        );
      } else if (match.group(11) != null) {
        // HR
        chunks.add(
          StyledChunk(
            text: '─' * 50 + '\n',
            color: PdfColor(150, 150, 150),
            fontSize: 10,
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      chunks.add(
        StyledChunk(
          text: text.substring(lastMatchEnd),
          style: currentStyle,
          fontSize: currentFontSize,
          color: currentColor,
          isUnderline: currentUnderline,
          isStrike: currentStrike,
        ),
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
        .replaceAll(RegExp(r'\[:[\s\S]*?:\]'), '')
        .trim();
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

  bool _isMeaningful(String text) {
    if (text.isEmpty) return false;

    // Remove page markers [PAGE X] before checking content
    final cleanText = text.replaceAll(RegExp(r'\[PAGE \d+\]'), '').trim();
    if (cleanText.length < 10) return false;

    // Check alphanumeric ratio on non-metadata text
    int alpha = 0;
    int totalNonSpace = 0;

    for (int i = 0; i < cleanText.length; i++) {
      final char = cleanText[i];
      if (char.trim().isEmpty) continue;

      totalNonSpace++;
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        alpha++;
      }
    }

    if (totalNonSpace == 0) return false;
    // Ratio of alphanumeric to total non-space chars
    final ratio = alpha / totalNonSpace;

    // Scanned PDFs often return gibberish native text (very low ratio)
    return ratio > 0.35 && alpha > 10;
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

  StyledChunk copyWith({
    String? text,
    PdfFontStyle? style,
    double? fontSize,
    PdfColor? color,
    bool? isUnderline,
    bool? isStrike,
  }) {
    return StyledChunk(
      text: text ?? this.text,
      style: style ?? this.style,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrike: isStrike ?? this.isStrike,
    );
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
