import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart' as dynamic_pdfx;
import '../models/scanned_document.dart';
import '../models/pdf_edit_overlay.dart';
import '../services/pdf_editor_service.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';

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
    final controller = TextEditingController(text: item.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(controller: controller, autofocus: true),
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
                  child: InteractiveViewer(
                    panEnabled: editor.activeTool == null,
                    scaleEnabled: editor.activeTool == null,
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
                                            currentDrawing: _currentDrawingPath,
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
                                                onPanUpdate:
                                                    editor.activeTool == null
                                                    ? (d) {
                                                        editor.updateItemPosition(
                                                          item.id,
                                                          Offset(
                                                            item.position.dx +
                                                                d.delta.dx / W,
                                                            item.position.dy +
                                                                d.delta.dy / H,
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
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      editor.activeTool == null
                                                      ? BoxDecoration(
                                                          border: Border.all(
                                                            color: Colors
                                                                .blueAccent,
                                                            width: 1,
                                                          ),
                                                        )
                                                      : null,
                                                  child: Text(
                                                    item.text,
                                                    style: TextStyle(
                                                      color: item.color,
                                                      fontSize: item.fontSize,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
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
                                                      EditType.drawing ||
                                                  editor.activeTool ==
                                                      EditType.redact) {
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
                                                      EditType.drawing ||
                                                  editor.activeTool ==
                                                      EditType.redact) {
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
                                                  () =>
                                                      _currentDrawingPath = [],
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
                                        ),
                                    ],
                                  );
                                },
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
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolButton(
                  icon: Icons.pan_tool_outlined,
                  label: 'Move',
                  isActive: editor.activeTool == null,
                  onTap: () => editor.setActiveTool(null),
                ),
                _ToolButton(
                  icon: Icons.text_fields,
                  label: 'Text',
                  isActive: editor.activeTool == EditType.text,
                  onTap: () => editor.setActiveTool(EditType.text),
                ),
                _ToolButton(
                  icon: Icons.edit,
                  label: 'Draw',
                  isActive: editor.activeTool == EditType.drawing,
                  onTap: () => editor.setActiveTool(EditType.drawing),
                ),
                _ToolButton(
                  icon: Icons.format_color_fill,
                  label: 'Redact',
                  isActive: editor.activeTool == EditType.redact,
                  onTap: () => editor.setActiveTool(EditType.redact),
                ),
              ],
            ),
            if (editor.activeTool != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    [
                          Colors.black,
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.white,
                        ]
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => editor.setColor(c),
                              child: CircleAvatar(
                                backgroundColor: c,
                                radius: 12,
                                child: editor.currentColor == c
                                    ? const Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousPage,
                ),
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextPage,
                ),
              ],
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ..strokeWidth = edit.type == EditType.redact ? 20.0 : edit.strokeWidth
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
        ..strokeWidth = activeToolType == EditType.redact ? 20.0 : 3.0
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
