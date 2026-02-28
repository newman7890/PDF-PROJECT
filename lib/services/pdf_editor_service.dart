import 'package:flutter/material.dart';
import '../models/pdf_edit_overlay.dart';
import 'package:uuid/uuid.dart';

class PdfEditorService extends ChangeNotifier {
  final Map<int, List<PdfEditItem>> _edits = {};
  int _currentPageIndex = 1; // 1-based to match pdfx page numbering
  EditType? _activeTool; // null means selection mode

  // Tool settings
  Color _currentColor = Colors.red;
  final double _currentStrokeWidth = 2.0;
  final double _currentFontSize = 14.0;

  final _uuid = const Uuid();

  Map<int, List<PdfEditItem>> get edits => _edits;
  int get currentPageIndex => _currentPageIndex;
  EditType? get activeTool => _activeTool;
  Color get currentColor => _currentColor;

  void setCurrentPage(int index) {
    if (_currentPageIndex != index) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  void setActiveTool(EditType? tool) {
    _activeTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  List<PdfEditItem> getEditsForPage(int pageIndex) {
    return _edits[pageIndex] ?? [];
  }

  void addTextEdit(
    Offset localPosition, {
    String initialText = "Double tap to edit",
  }) {
    final newItem = TextEditItem(
      id: _uuid.v4(),
      pageIndex: _currentPageIndex,
      position: localPosition,
      text: initialText,
      color: _currentColor,
      fontSize: _currentFontSize,
    );
    _addItem(newItem);
  }

  void addDrawing(List<Offset> points) {
    if (points.isEmpty) return;
    final newItem = DrawingEditItem(
      id: _uuid.v4(),
      pageIndex: _currentPageIndex,
      points: points,
      color: _currentColor,
      strokeWidth: _currentStrokeWidth,
    );
    _addItem(newItem);
  }

  void updateTextItem(String id, {String? newText, Offset? newPosition}) {
    final items = _edits[_currentPageIndex];
    if (items != null) {
      final index = items.indexWhere((item) => item.id == id);
      if (index != -1 && items[index] is TextEditItem) {
        final item = items[index] as TextEditItem;
        if (newText != null) item.text = newText;
        if (newPosition != null) item.position = newPosition;
        notifyListeners();
      }
    }
  }

  void updateItemPosition(String id, Offset newPosition) {
    final items = _edits[_currentPageIndex];
    if (items != null) {
      final index = items.indexWhere((item) => item.id == id);
      if (index != -1) {
        items[index].position = newPosition;
        notifyListeners();
      }
    }
  }

  void deleteItem(String id) {
    final items = _edits[_currentPageIndex];
    if (items != null) {
      items.removeWhere((item) => item.id == id);
      notifyListeners();
    }
  }

  void undo() {
    final items = _edits[_currentPageIndex];
    if (items != null && items.isNotEmpty) {
      items.removeLast();
      notifyListeners();
    }
  }

  void _addItem(PdfEditItem item) {
    _edits.putIfAbsent(item.pageIndex, () => []);
    _edits[item.pageIndex]!.add(item);
    notifyListeners();
  }

  void clearAll() {
    _edits.clear();
    notifyListeners();
  }
}
