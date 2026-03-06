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
  /// Falls back to OCR if no native text is found.
  Future<List<PdfTextBlock>> extractTextBlocksFromPdf(
    String pdfPath, {
    required dynamic ocrService,
  }) async {
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
          // Heuristic based on line height (points)
          // Standard text is ~10-12pt with height ~12-14pt
          bool isH1 = line.bounds.height > 18;
          bool isAllCaps =
              line.text.length >= 4 &&
              line.text == line.text.toUpperCase() &&
              RegExp(r'[A-Z]').hasMatch(line.text);
          bool isH2 = (line.bounds.height > 14 || isAllCaps) && !isH1;

          blocks.add(
            PdfTextBlock(
              text: line.text,
              bounds: line.bounds,
              pageIndex: i,
              isH1: isH1,
              isH2: isH2,
            ),
          );
        }
      }

      // FALLBACK: If no blocks identified, try OCR
      if (blocks.isEmpty) {
        final dynamic_pdfx.PdfDocument pdfxDoc =
            await dynamic_pdfx.PdfDocument.openFile(pdfPath);
        try {
          for (int i = 0; i < pdfxDoc.pagesCount; i++) {
            final page = await pdfxDoc.getPage(i + 1);
            final pageImage = await page.render(
              width: page.width * 2,
              height: page.height * 2,
              format: dynamic_pdfx.PdfPageImageFormat.jpeg,
              quality: 100,
            );

            if (pageImage != null) {
              final tempFile = File('${Directory.systemTemp.path}/page_$i.jpg');
              await tempFile.writeAsBytes(pageImage.bytes);

              final ocrBlocks = await ocrService.extractBlocksFromImage(
                tempFile,
              );

              // Calculate median height for heuristic
              double totalHeight = 0;
              int count = 0;
              for (var b in ocrBlocks) {
                totalHeight += b.boundingBox.height;
                count++;
              }
              final medianHeight = count > 0 ? (totalHeight / count) : 12.0;

              for (var b in ocrBlocks) {
                final text = b.text.trim();
                final avgLineHeight =
                    b.boundingBox.height /
                    (b.lines.isNotEmpty ? b.lines.length : 1);
                bool isAllCaps =
                    text.length >= 4 &&
                    text == text.toUpperCase() &&
                    RegExp(r'[A-Z]').hasMatch(text);

                blocks.add(
                  PdfTextBlock(
                    text: text,
                    bounds: b.boundingBox,
                    pageIndex: i,
                    isH1: avgLineHeight > medianHeight * 1.5,
                    isH2: avgLineHeight > medianHeight * 1.2 || isAllCaps,
                  ),
                );
              }
              await tempFile.delete();
            }
            await page.close();
          }
        } finally {
          await pdfxDoc.close();
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
          final List<TextLine> lines = extractor.extractTextLines(
            startPageIndex: i,
            endPageIndex: i,
          );

          if (lines.isEmpty) continue;

          // Apply True Recursive XY-cut
          final sortedLines = _recursiveXYCut(lines);

          // Build text from sorted lines with smart proximity joining
          for (int k = 0; k < sortedLines.length; k++) {
            final current = sortedLines[k];
            var text = current.text.trim();

            // Header detection heuristic based on line height
            bool isAllCaps =
                text.length >= 4 &&
                text == text.toUpperCase() &&
                RegExp(r'[A-Z]').hasMatch(text);
            if (current.bounds.height > 18) {
              text = "[H1] $text";
            } else if (current.bounds.height > 14 || isAllCaps) {
              text = "[H2] $text";
            }

            nativeText += text;

            if (k < sortedLines.length - 1) {
              final next = sortedLines[k + 1];

              // Vertical proximity
              double verticalGap = next.bounds.top - current.bounds.bottom;
              // Same visual line check
              bool sameLine =
                  (next.bounds.top - current.bounds.top).abs() <
                  (current.bounds.height * 0.4);

              // Join with a space if it's on the same line OR if the line doesn't end in terminal punctuation
              bool endsInStop = RegExp(r'[.!?:]$').hasMatch(text);

              if (sameLine ||
                  (!endsInStop && verticalGap < current.bounds.height * 1.5)) {
                nativeText += " ";
              } else if (verticalGap < current.bounds.height * 1.5) {
                nativeText += "\n";
              } else {
                nativeText += "\n\n";
              }
            }
          }
          nativeText += "\n\n";
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

                // Filter out border noise: limit OCR to central 90% of page
                final text = await ocrService.extractTextFromImage(tempFile);
                final cleanText = _cleanNoiseAndHallucinations(text);
                if (cleanText.trim().isNotEmpty) {
                  ocrText += "$cleanText\n\n";
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
    bool ignoreNextNewline = false;

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
        ignoreNextNewline = true;
        if (y > pageHeight - margin) {
          page = document.pages.add();
          y = margin;
        }
        continue;
      }

      // Split chunk by newlines to respect manual line breaks
      List<String> linesInChunk = chunk.text.split('\n');

      if (ignoreNextNewline &&
          linesInChunk.isNotEmpty &&
          linesInChunk.first.isEmpty) {
        linesInChunk.removeAt(0);
      }
      ignoreNextNewline = false;

      if (linesInChunk.isEmpty) continue;

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
            double drawX = x;
            if (chunk.isCentered) {
              drawX = (pageWidth - cSize.width) / 2;
            }

            page.graphics.drawString(
              currentStr,
              font,
              brush: PdfSolidBrush(chunk.color),
              bounds: Rect.fromLTWH(
                drawX,
                y,
                cSize.width + 2,
                maxLineHeight + 10,
              ),
            );

            // Underline/Strike handling
            if (chunk.isUnderline) {
              page.graphics.drawLine(
                PdfPen(chunk.color, width: 0.8),
                Offset(drawX, y + chunk.fontSize * 0.95),
                Offset(
                  drawX + font.measureString(currentStr.trimRight()).width,
                  y + chunk.fontSize * 0.95,
                ),
              );
            }
            if (chunk.isStrike) {
              page.graphics.drawLine(
                PdfPen(chunk.color, width: 0.8),
                Offset(drawX, y + chunk.fontSize * 0.5),
                Offset(
                  drawX + font.measureString(currentStr.trimRight()).width,
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

          // If centered and not at start of line, force a newline first
          if (chunk.isCentered && x > margin) {
            y += maxLineHeight;
            x = margin;
            if (y > pageHeight - margin) {
              page = document.pages.add();
              y = margin;
            }
          }

          double drawX = x;
          if (chunk.isCentered) {
            drawX = (pageWidth - cSize.width) / 2;
          }

          page.graphics.drawString(
            currentStr,
            font,
            brush: PdfSolidBrush(chunk.color),
            bounds: Rect.fromLTWH(
              drawX,
              y,
              cSize.width + 2,
              maxLineHeight + 10,
            ),
          );

          if (chunk.isUnderline) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(drawX, y + chunk.fontSize * 0.95),
              Offset(
                drawX + font.measureString(currentStr.trimRight()).width,
                y + chunk.fontSize * 0.95,
              ),
            );
          }
          if (chunk.isStrike) {
            page.graphics.drawLine(
              PdfPen(chunk.color, width: 0.8),
              Offset(drawX, y + chunk.fontSize * 0.5),
              Offset(
                drawX + font.measureString(currentStr.trimRight()).width,
                y + chunk.fontSize * 0.5,
              ),
            );
          }

          if (chunk.isCentered) {
            y += maxLineHeight;
            x = margin;
            if (lineIdx == linesInChunk.length - 1) {
              ignoreNextNewline = true;
            }
          } else {
            x += cSize.width;
          }
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
    bool currentStrike, {
    bool isCentered = false,
  }) {
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
            isCentered: isCentered,
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
            isCentered: true,
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
            isCentered: true,
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
            isCentered: true,
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
          isCentered: isCentered,
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
    final cleanText = _cleanNoiseAndHallucinations(text).trim();
    if (cleanText.length < 5) return false;

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
    return ratio > 0.4 && alpha > 10;
  }

  /// Strips out known OCR hallucinations and nonsensical short strings.
  String _cleanNoiseAndHallucinations(String text) {
    if (text.isEmpty) return "";

    // 1. Remove common "phantom" words (case-insensitive)
    final wordsToFilter = RegExp(
      r'\b(aah|ae|avoe|aa|ii|oo|uu|aeo|aei|aot)\b',
      caseSensitive: false,
    );

    // 2. Remove very short nonsensical blocks (e.g. "at" by itself on its own line)
    // and lines that are purely symbols
    return text
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            return true;
          }

          // Strip known hallucinated exact lines
          final lower = trimmed.toLowerCase();
          if (lower == 'at' || lower == '@') {
            return false;
          }

          // If the line consists only of one or two noise words, skip it
          final cleanLine = trimmed.replaceAll(wordsToFilter, '').trim();
          if (cleanLine.isEmpty && trimmed.length <= 5) {
            return false;
          }

          // Skip lines that are purely non-alphanumeric noise
          if (trimmed.length < 3 && !RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
            return false;
          }

          return true;
        })
        .join('\n')
        .replaceAll(wordsToFilter, '')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  /// True Recursive XY-Cut for PDF TextLines.
  List<TextLine> _recursiveXYCut(List<TextLine> lines) {
    if (lines.length <= 1) return lines;

    // --- Try Horizontal Splits First ---
    final sortedByTop = List<TextLine>.from(lines);
    sortedByTop.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    for (int i = 0; i < sortedByTop.length - 1; i++) {
      double splitY =
          (sortedByTop[i].bounds.bottom + sortedByTop[i + 1].bounds.top) / 2;

      bool isClearCut = true;
      for (var l in lines) {
        if (l.bounds.top < splitY && l.bounds.bottom > splitY) {
          isClearCut = false;
          break;
        }
      }

      double gap = sortedByTop[i + 1].bounds.top - sortedByTop[i].bounds.bottom;
      if (isClearCut && gap > 0.5) {
        final top = lines.where((l) => l.bounds.bottom <= splitY).toList();
        final bottom = lines.where((l) => l.bounds.top >= splitY).toList();
        if (top.isNotEmpty && bottom.isNotEmpty) {
          return [..._recursiveXYCut(top), ..._recursiveXYCut(bottom)];
        }
      }
    }

    // --- Try Vertical Splits Next ---
    final sortedByLeft = List<TextLine>.from(lines);
    sortedByLeft.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    for (int i = 0; i < sortedByLeft.length - 1; i++) {
      double splitX =
          (sortedByLeft[i].bounds.right + sortedByLeft[i + 1].bounds.left) / 2;

      bool isClearCut = true;
      for (var l in lines) {
        if (l.bounds.left < splitX && l.bounds.right > splitX) {
          isClearCut = false;
          break;
        }
      }

      double gap =
          sortedByLeft[i + 1].bounds.left - sortedByLeft[i].bounds.right;
      if (isClearCut && gap > 15) {
        // Threshold for gutter
        final left = lines.where((l) => l.bounds.right <= splitX).toList();
        final right = lines.where((l) => l.bounds.left >= splitX).toList();
        if (left.isNotEmpty && right.isNotEmpty) {
          return [..._recursiveXYCut(left), ..._recursiveXYCut(right)];
        }
      }
    }

    // Fallback: Reading order
    lines.sort((a, b) {
      int cmp = a.bounds.top.compareTo(b.bounds.top);
      if (cmp != 0) return cmp;
      return a.bounds.left.compareTo(b.bounds.left);
    });

    return lines;
  }
}

class StyledChunk {
  final String text;
  final PdfFontStyle style;
  final double fontSize;
  final PdfColor color;
  final bool isUnderline;
  final bool isStrike;
  final bool isCentered;

  StyledChunk({
    required this.text,
    this.style = PdfFontStyle.regular,
    this.fontSize = 12.0,
    required this.color,
    this.isUnderline = false,
    this.isStrike = false,
    this.isCentered = false,
  });

  StyledChunk copyWith({
    String? text,
    PdfFontStyle? style,
    double? fontSize,
    PdfColor? color,
    bool? isUnderline,
    bool? isStrike,
    bool? isCentered,
  }) {
    return StyledChunk(
      text: text ?? this.text,
      style: style ?? this.style,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrike: isStrike ?? this.isStrike,
      isCentered: isCentered ?? this.isCentered,
    );
  }
}

class PdfTextBlock {
  final String text;
  final Rect bounds;
  final int pageIndex;
  final bool isH1;
  final bool isH2;

  PdfTextBlock({
    required this.text,
    required this.bounds,
    required this.pageIndex,
    this.isH1 = false,
    this.isH2 = false,
  });
}
