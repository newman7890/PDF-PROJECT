import 'package:flutter/material.dart';

/// A simple data model for a selection and text state.
class TextState {
  final String text;
  final TextSelection selection;

  TextState(this.text, this.selection);
}

/// A custom controller that handles basic real-time formatting visualization
/// and a robust Undo/Redo history stack.
class StyledTextController extends TextEditingController {
  final List<TextState> _undoStack = [];
  final List<TextState> _redoStack = [];
  bool _isHandlingUndoRedo = false;

  StyledTextController() {
    // Initial state
    _undoStack.add(TextState('', const TextSelection.collapsed(offset: 0)));
    addListener(_handleTextChange);
  }

  void _handleTextChange() {
    if (_isHandlingUndoRedo) return;

    final newState = TextState(text, selection);
    if (_undoStack.isEmpty || _undoStack.last.text != newState.text) {
      _undoStack.add(newState);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
    }
  }

  void undo() {
    if (_undoStack.length < 2) return;
    _isHandlingUndoRedo = true;
    _redoStack.add(_undoStack.removeLast());
    final prevState = _undoStack.last;
    value = TextEditingValue(
      text: prevState.text,
      selection: prevState.selection,
    );
    _isHandlingUndoRedo = false;
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _isHandlingUndoRedo = true;
    final nextState = _redoStack.removeLast();
    _undoStack.add(nextState);
    value = TextEditingValue(
      text: nextState.text,
      selection: nextState.selection,
    );
    _isHandlingUndoRedo = false;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return _buildSpanRecursive(text, style);
  }

  TextSpan _buildSpanRecursive(String text, TextStyle? style) {
    if (text.isEmpty) return TextSpan(style: style);

    final List<InlineSpan> children = [];
    final markerStyle = style?.copyWith(
      color: Colors.transparent,
      fontSize: 0,
      letterSpacing: -1, // Collapse spacing for invisible markers
    );

    text.splitMapJoin(
      RegExp(
        r'(\*\*.*?\*\*)|(\*.*?\*)|(__.*?__)|(~~.*?~~)|(\[H1\].*?\[/H1\])|(\[H2\].*?\[/H2\])|(\[H3\].*?\[/H3\])|(^- .*?$|^- .*?\n)|(^\d+\. .*?$|^\d+\. .*?\n)|(^---$|^---\n)|(\[:.*?:\])',
        multiLine: true,
      ),
      onMatch: (m) {
        final match = m.group(0)!;

        if (match.startsWith('**')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '**', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          );
          children.add(TextSpan(text: '**', style: markerStyle));
        } else if (match.startsWith('*')) {
          final content = match.substring(1, match.length - 1);
          children.add(TextSpan(text: '*', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(fontStyle: FontStyle.italic, color: Colors.black),
            ),
          );
          children.add(TextSpan(text: '*', style: markerStyle));
        } else if (match.startsWith('__')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '__', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '__', style: markerStyle));
        } else if (match.startsWith('~~')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '~~', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '~~', style: markerStyle));
        } else if (match.startsWith('[H1]')) {
          final content = match.substring(4, match.length - 5);
          children.add(TextSpan(text: '[H1]', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '[/H1]', style: markerStyle));
        } else if (match.startsWith('[H2]')) {
          final content = match.substring(4, match.length - 5);
          children.add(TextSpan(text: '[H2]', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '[/H2]', style: markerStyle));
        } else if (match.startsWith('[H3]')) {
          final content = match.substring(4, match.length - 5);
          children.add(TextSpan(text: '[H3]', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '[/H3]', style: markerStyle));
        } else if (match.startsWith('- ')) {
          children.add(
            TextSpan(
              text: '• ',
              style: style?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          children.add(_buildSpanRecursive(match.substring(2), style));
        } else if (RegExp(r'^\d+\. ').hasMatch(match)) {
          final dotIndex = match.indexOf('. ');
          final number = match.substring(0, dotIndex + 2);
          children.add(
            TextSpan(
              text: number,
              style: style?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          children.add(
            _buildSpanRecursive(match.substring(dotIndex + 2), style),
          );
        } else if (match.startsWith('---')) {
          children.add(
            WidgetSpan(
              child: Container(
                height: 1,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey[400],
              ),
            ),
          );
          children.add(TextSpan(text: match, style: markerStyle));
        } else if (match.startsWith('[:color:')) {
          final hexColor = match.substring(8, 15);
          try {
            final color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
            children.add(TextSpan(text: match, style: markerStyle));
            children.add(
              TextSpan(
                text: ' ● ',
                style: TextStyle(color: color, fontSize: 16),
              ),
            );
          } catch (_) {
            children.add(TextSpan(text: match, style: style));
          }
        } else if (match.startsWith('[:')) {
          children.add(TextSpan(text: match, style: markerStyle));
        } else if (match.startsWith('[')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          );
        }
        return '';
      },
      onNonMatch: (s) {
        children.add(TextSpan(text: s, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }

  void toggleBold() {
    _wrapSelection('**', '**');
  }

  void toggleItalic() {
    _wrapSelection('*', '*');
  }

  void toggleUnderline() {
    _wrapSelection('__', '__');
  }

  void toggleStrikethrough() {
    _wrapSelection('~~', '~~');
  }

  void setAlignment(String alignment) {
    // alignment can be 'left', 'center', 'right'
    final marker = '[:$alignment:]';
    _toggleLineStart(
      marker,
      replaceOthers: ['[:left:]', '[:center:]', '[:right:]'],
    );
  }

  void toggleBulletList() {
    _toggleLineStart('- ');
  }

  void toggleNumberedList() {
    _toggleLineStart('1. ');
  }

  void insertHorizontalRule() {
    final curSelection = selection;
    final curText = text;
    final newText = curText.replaceRange(
      curSelection.start,
      curSelection.end,
      '\n---\n',
    );
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: curSelection.start + 5),
    );
  }

  void setTextColor(Color color) {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    _toggleLineStart('[:color:$hex:]');
  }

  void toggleH1() {
    _wrapSelection('[H1]', '[/H1]');
  }

  void toggleH2() {
    _wrapSelection('[H2]', '[/H2]');
  }

  void toggleH3() {
    _wrapSelection('[H3]', '[/H3]');
  }

  void _wrapSelection(String prefix, String suffix) {
    final curSelection = selection;
    final curText = text;

    if (curSelection.isCollapsed) {
      // Check if we are already inside wrapping
      final start = curSelection.start;
      if (start >= prefix.length &&
          start + suffix.length <= curText.length &&
          curText.substring(start - prefix.length, start) == prefix &&
          curText.substring(start, start + suffix.length) == suffix) {
        // Remove existing empty wrapping
        final newText = curText.replaceRange(
          start - prefix.length,
          start + suffix.length,
          '',
        );
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - prefix.length),
        );
        return;
      }

      final newText = curText.replaceRange(
        curSelection.start,
        curSelection.end,
        '$prefix$suffix',
      );
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: curSelection.start + prefix.length,
        ),
      );
      return;
    }

    final selectedText = curSelection.textInside(curText);
    String newText;
    TextSelection newSelection;

    if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix)) {
      final unwrapped = selectedText.substring(
        prefix.length,
        selectedText.length - suffix.length,
      );
      newText = curText.replaceRange(
        curSelection.start,
        curSelection.end,
        unwrapped,
      );
      newSelection = TextSelection(
        baseOffset: curSelection.start,
        extentOffset: curSelection.start + unwrapped.length,
      );
    } else {
      final wrapped = '$prefix$selectedText$suffix';
      newText = curText.replaceRange(
        curSelection.start,
        curSelection.end,
        wrapped,
      );
      newSelection = TextSelection(
        baseOffset: curSelection.start,
        extentOffset: curSelection.start + wrapped.length,
      );
    }

    value = TextEditingValue(text: newText, selection: newSelection);
  }

  void _toggleLineStart(String marker, {List<String>? replaceOthers}) {
    final curSelection = selection;
    final curText = text;

    // Find start of line
    int lineStart = 0;
    for (int i = curSelection.start - 1; i >= 0; i--) {
      if (curText[i] == '\n') {
        lineStart = i + 1;
        break;
      }
    }

    String lineContent = curText.substring(lineStart);

    // Check if the current marker already exists
    if (lineContent.startsWith(marker)) {
      // Remove existing marker
      final newText = curText.replaceRange(
        lineStart,
        lineStart + marker.length,
        '',
      );
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (curSelection.start - marker.length).clamp(0, newText.length),
        ),
      );
      return;
    }

    // Check if any of the replaceOthers markers exist
    String? foundOther;
    if (replaceOthers != null) {
      for (final other in replaceOthers) {
        if (lineContent.startsWith(other)) {
          foundOther = other;
          break;
        }
      }
    }

    if (foundOther != null) {
      // Replace existing marker with new one
      final removedText = curText.replaceRange(
        lineStart,
        lineStart + foundOther.length,
        '',
      );
      final finalText = removedText.replaceRange(lineStart, lineStart, marker);
      value = TextEditingValue(
        text: finalText,
        selection: TextSelection.collapsed(
          offset: (curSelection.start - foundOther.length + marker.length)
              .clamp(0, finalText.length),
        ),
      );
    } else {
      // Add new marker
      final finalText = curText.replaceRange(lineStart, lineStart, marker);
      value = TextEditingValue(
        text: finalText,
        selection: TextSelection.collapsed(
          offset: (curSelection.start + marker.length).clamp(
            0,
            finalText.length,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    removeListener(_handleTextChange);
    super.dispose();
  }
}
