import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart' as dynamic_pdfx;
import '../models/scanned_document.dart';
import '../models/pdf_edit_overlay.dart';
import '../services/pdf_editor_service.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/rich_text_service.dart';

class EditorScreen extends StatefulWidget {
  final ScannedDocument document;

  const EditorScreen({super.key, required this.document});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  dynamic_pdfx.PdfDocument? _pdfDocument;
  dynamic_pdfx.PdfPageImage? _currentPageImage;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;

  List<Offset> _currentDrawingPath = [];

  @override
  void initState() {
    super.initState();
    // Reset tool selection and clear previous session edits
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PdfEditorService>().setActiveTool(null);
    });
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      _pdfDocument = await dynamic_pdfx.PdfDocument.openFile(
        widget.document.filePath,
      );
      _totalPages = _pdfDocument!.pagesCount;
      await _renderPage(_currentPage);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
      }
    }
  }

  Future<void> _renderPage(int pageNumber) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final page = await _pdfDocument!.getPage(pageNumber);
    final image = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: dynamic_pdfx.PdfPageImageFormat.jpeg,
    );
    await page.close();

    if (mounted) {
      context.read<PdfEditorService>().setCurrentPage(pageNumber);
      setState(() {
        _currentPageImage = image;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _currentPage++;
      _currentDrawingPath = [];
      _renderPage(_currentPage);
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      _currentDrawingPath = [];
      _renderPage(_currentPage);
    }
  }

  void _editTextItem(
    BuildContext context,
    PdfEditorService editor,
    TextEditItem item,
  ) {
    final controller = StyledTextController()..text = item.text;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          style: TextStyle(
            fontSize: item.isH1
                ? 32
                : item.isH2
                ? 26
                : item.fontSize,
            fontWeight: (item.isBold || item.isH1 || item.isH2)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine([
              if (item.isUnderline) TextDecoration.underline,
              if (item.isStrikethrough) TextDecoration.lineThrough,
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              editor.deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              editor.updateTextItem(item.id, newText: controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PdfEditorService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit PDF'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last edit',
            onPressed: () => context.read<PdfEditorService>().undo(),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save edited PDF',
            onPressed: () async {
              setState(() => _isLoading = true);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                final editorSession = context.read<PdfEditorService>();
                final pdfService = context.read<PDFService>();
                final storageService = context.read<StorageService>();

                final newPath = await storageService.getNewFilePath(
                  'Edited_${widget.document.title}',
                );

                await pdfService.flattenEditsToPdf(
                  widget.document.filePath,
                  editorSession.edits,
                  newPath,
                );

                final newDoc = ScannedDocument(
                  id: DateTime.now().toIso8601String(),
                  title: 'Edited_${widget.document.title}',
                  filePath: newPath,
                  dateCreated: DateTime.now(),
                  isPdf: true,
                );

                await storageService.saveDocument(newDoc);
                editorSession.clearAll();

                if (!mounted) return;
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Failed to save: $e')),
                );
                setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SafeArea(
                    child: InteractiveViewer(
                      panEnabled:
                          editor.activeTool == null &&
                          editor.selectedItemId == null,
                      scaleEnabled:
                          editor.activeTool == null &&
                          editor.selectedItemId == null,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: _currentPageImage == null
                            ? const CircularProgressIndicator()
                            : AspectRatio(
                                aspectRatio:
                                    (_currentPageImage!.width?.toDouble() ??
                                        1.0) /
                                    (_currentPageImage!.height?.toDouble() ??
                                        1.0),
                                child: LayoutBuilder(
                                  builder: (_, constraints) {
                                    final W = constraints.maxWidth;
                                    final H = constraints.maxHeight;
                                    return Stack(
                                      children: [
                                        // Layer 1: PDF page image
                                        Positioned.fill(
                                          child: Image.memory(
                                            _currentPageImage!.bytes,
                                            fit: BoxFit.fill,
                                          ),
                                        ),

                                        // Layer 2: Drawing strokes overlay
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _OverlayPainter(
                                              edits: editor.getEditsForPage(
                                                _currentPage,
                                              ),
                                              currentDrawing:
                                                  _currentDrawingPath,
                                              drawingColor: editor.currentColor,
                                              activeToolType: editor.activeTool,
                                            ),
                                          ),
                                        ),

                                        // Layer 3: Text item widgets
                                        ...editor
                                            .getEditsForPage(_currentPage)
                                            .whereType<TextEditItem>()
                                            .map(
                                              (item) => Positioned(
                                                left: item.position.dx * W,
                                                top: item.position.dy * H,
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: () => editor
                                                      .selectItem(item.id),
                                                  onPanUpdate:
                                                      editor.activeTool == null
                                                      ? (d) {
                                                          editor.updateItemPosition(
                                                            item.id,
                                                            Offset(
                                                              item.position.dx +
                                                                  d.delta.dx /
                                                                      W,
                                                              item.position.dy +
                                                                  d.delta.dy /
                                                                      H,
                                                            ),
                                                          );
                                                        }
                                                      : null,
                                                  onDoubleTap: () =>
                                                      _editTextItem(
                                                        context,
                                                        editor,
                                                        item,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical:
                                                              12, // Larger vertical target for mobile
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.01,
                                                          ), // Ensure hit detection
                                                      border: Border.all(
                                                        color:
                                                            editor.selectedItemId ==
                                                                item.id
                                                            ? Colors.blue
                                                            : Colors.blueAccent
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  ),
                                                        width:
                                                            editor.selectedItemId ==
                                                                item.id
                                                            ? 2
                                                            : 1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text.rich(
                                                      StyledTextController.buildRichTextSpan(
                                                        item.text,
                                                        TextStyle(
                                                          color: item.color,
                                                          fontSize: item.isH1
                                                              ? 32
                                                              : item.isH2
                                                              ? 26
                                                              : item.fontSize,
                                                          fontWeight:
                                                              (item.isBold ||
                                                                  item.isH1 ||
                                                                  item.isH2)
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                          fontStyle:
                                                              item.isItalic
                                                              ? FontStyle.italic
                                                              : FontStyle
                                                                    .normal,
                                                          decoration: TextDecoration.combine([
                                                            if (item
                                                                .isUnderline)
                                                              TextDecoration
                                                                  .underline,
                                                            if (item
                                                                .isStrikethrough)
                                                              TextDecoration
                                                                  .lineThrough,
                                                          ]),
                                                        ),
                                                      ),
                                                      textAlign: item.textAlign,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                        // Layer 4: Gesture capture — only when an edit tool is active
                                        if (editor.activeTool != null)
                                          Positioned.fill(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanStart: (d) {
                                                if (editor.activeTool ==
                                                    EditType.drawing) {
                                                  setState(() {
                                                    _currentDrawingPath = [
                                                      Offset(
                                                        d.localPosition.dx / W,
                                                        d.localPosition.dy / H,
                                                      ),
                                                    ];
                                                  });
                                                }
                                              },
                                              onPanUpdate: (d) {
                                                if (editor.activeTool ==
                                                    EditType.drawing) {
                                                  setState(() {
                                                    _currentDrawingPath.add(
                                                      Offset(
                                                        d.localPosition.dx / W,
                                                        d.localPosition.dy / H,
                                                      ),
                                                    );
                                                  });
                                                }
                                              },
                                              onPanEnd: (_) {
                                                if (_currentDrawingPath
                                                    .isNotEmpty) {
                                                  editor.addDrawing(
                                                    List.from(
                                                      _currentDrawingPath,
                                                    ),
                                                  );
                                                  setState(
                                                    () => _currentDrawingPath =
                                                        [],
                                                  );
                                                }
                                              },
                                              onTapUp: (d) {
                                                if (editor.activeTool ==
                                                    EditType.text) {
                                                  editor.addTextEdit(
                                                    Offset(
                                                      d.localPosition.dx / W,
                                                      d.localPosition.dy / H,
                                                    ),
                                                  );
                                                  editor.setActiveTool(null);
                                                }
                                              },
                                            ),
                                          )
                                        else
                                          // Background tap to clear selection
                                          Positioned.fill(
                                            child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: () =>
                                                  editor.selectItem(null),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                _buildToolbar(editor),
              ],
            ),
    );
  }

  Widget _buildToolbar(PdfEditorService editor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection/Formatting sub-toolbar
            if (editor.selectedItemId != null || editor.activeTool != null)
              _buildFormattingOptions(editor),

            const Divider(height: 1),

            // Main tool buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.pan_tool_outlined,
                      label: 'Move',
                      isActive:
                          editor.activeTool == null &&
                          editor.selectedItemId == null,
                      onTap: () {
                        editor.setActiveTool(null);
                        editor.selectItem(null);
                      },
                    ),
                  ),
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.text_fields,
                      label: 'Text',
                      isActive: editor.activeTool == EditType.text,
                      onTap: () => editor.setActiveTool(EditType.text),
                    ),
                  ),
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.edit,
                      label: 'Draw',
                      isActive: editor.activeTool == EditType.drawing,
                      onTap: () => editor.setActiveTool(EditType.drawing),
                    ),
                  ),
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      isActive: false,
                      onTap: () {
                        if (editor.selectedItemId != null) {
                          editor.deleteItem(editor.selectedItemId!);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Page navigation
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousPage,
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattingOptions(PdfEditorService editor) {
    final bool isText =
        editor.activeTool == EditType.text ||
        editor.selectedItem is TextEditItem;
    final bool isDraw =
        editor.activeTool == EditType.drawing ||
        editor.selectedItem is DrawingEditItem;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Colors
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                              Colors.black,
                              Colors.red,
                              Colors.blue,
                              Colors.green,
                              Colors.orange,
                              Colors.purple,
                            ]
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => editor.setColor(c),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: editor.currentColor == c
                                            ? Colors.indigo
                                            : Colors.grey[300]!,
                                        width: editor.currentColor == c ? 2 : 1,
                                      ),
                                    ),
                                    child: editor.currentColor == c
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: c.computeLuminance() > 0.5
                                                ? Colors.black
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),

              if (isText) ...[
                IconButton(
                  icon: Icon(
                    Icons.format_bold,
                    color: editor.isBold ? Colors.indigo : Colors.grey,
                  ),
                  onPressed: editor.toggleBold,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_italic,
                    color: editor.isItalic ? Colors.indigo : Colors.grey,
                  ),
                  onPressed: editor.toggleItalic,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_underlined,
                    color: editor.isUnderline ? Colors.indigo : Colors.grey,
                  ),
                  onPressed: editor.toggleUnderline,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_strikethrough,
                    color: editor.isStrikethrough ? Colors.indigo : Colors.grey,
                  ),
                  onPressed: editor.toggleStrikethrough,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Text(
                    'H1',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: editor.isH1 ? Colors.indigo : Colors.grey,
                    ),
                  ),
                  onPressed: editor.toggleH1,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Text(
                    'H2',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: editor.isH2 ? Colors.indigo : Colors.grey,
                    ),
                  ),
                  onPressed: editor.toggleH2,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isText) ...[
                const SizedBox(width: 8),
                const Text('Size:'),
                Expanded(
                  child: Slider(
                    value: editor.currentFontSize,
                    min: 8,
                    max: 48,
                    onChanged: editor.setFontSize,
                  ),
                ),
              ],
              if (isDraw) ...[
                const Icon(Icons.line_weight, size: 20),
                const SizedBox(width: 8),
                const Text('Width:'),
                Expanded(
                  child: Slider(
                    value: editor.currentStrokeWidth,
                    min: 1,
                    max: 20,
                    onChanged: editor.setStrokeWidth,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.indigo.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.indigo : Colors.grey[700]),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? Colors.indigo : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final List<PdfEditItem> edits;
  final List<Offset> currentDrawing;
  final Color drawingColor;
  final EditType? activeToolType;

  _OverlayPainter({
    required this.edits,
    required this.currentDrawing,
    required this.drawingColor,
    required this.activeToolType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw committed strokes
    for (final edit in edits) {
      if (edit is DrawingEditItem && edit.points.length > 1) {
        final paint = Paint()
          ..color = edit.color
          ..strokeWidth = edit.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < edit.points.length - 1; i++) {
          canvas.drawLine(
            Offset(
              edit.points[i].dx * size.width,
              edit.points[i].dy * size.height,
            ),
            Offset(
              edit.points[i + 1].dx * size.width,
              edit.points[i + 1].dy * size.height,
            ),
            paint,
          );
        }
      }
    }

    // Draw the in-progress stroke
    if (currentDrawing.length > 1) {
      final paint = Paint()
        ..color = drawingColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < currentDrawing.length - 1; i++) {
        canvas.drawLine(
          Offset(
            currentDrawing[i].dx * size.width,
            currentDrawing[i].dy * size.height,
          ),
          Offset(
            currentDrawing[i + 1].dx * size.width,
            currentDrawing[i + 1].dy * size.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => true;
}

class SignaturePainterHelper extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  SignaturePainterHelper(this.points, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Find bounds to normalize
    double minX = points[0].dx;
    double minY = points[0].dy;
    double maxX = points[0].dx;
    double maxY = points[0].dy;

    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    double sigWidth = maxX - minX;
    double sigHeight = maxY - minY;
    if (sigWidth == 0) sigWidth = 1;
    if (sigHeight == 0) sigHeight = 1;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final List<Offset> normalized = points.map((p) {
      return Offset(
        (p.dx - minX) / sigWidth * size.width,
        (p.dy - minY) / sigHeight * size.height,
      );
    }).toList();

    for (int i = 0; i < normalized.length - 1; i++) {
      // Check if this is a break in the signature (if we had nulls, but here we only have List<Offset>)
      // In SignaturePadScreen we add null on PanEnd, but PdfEditorService.addSignature filters them.
      // For now we assume a continuous line or handle distance jumps if needed.
      canvas.drawLine(normalized[i], normalized[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainterHelper oldDelegate) => true;
}
