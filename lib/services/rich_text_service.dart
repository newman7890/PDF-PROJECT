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
    final List<InlineSpan> children = [];

    // Improved regex: removes the forced trailing newline for headings
    // so they highlight as soon as the user types '# '
    text.splitMapJoin(
      RegExp(
        r'(\*\*.*?\*\*)|(\*.*?\*)|(__.*?__)|(~~.*?~~)|(^# .*?$|^# .*?\n)|(^## .*?$|^## .*?\n)|(^- .*?$|^- .*?\n)|(^\d+\. .*?$|^\d+\. .*?\n)|(^---$|^---\n)|(\[:color:#[0-9a-fA-F]{6}:\])|(\[:.*?:\])|(\[.*?\]\(.*?\))',
        multiLine: true,
      ),
      onMatch: (m) {
        final match = m.group(0)!;
        final markerStyle = style?.copyWith(
          color: Colors.transparent,
          fontSize: 0.1,
        );

        if (match.startsWith('**')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '**', style: markerStyle));
          children.add(
            TextSpan(
              text: content,
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          );
          children.add(TextSpan(text: '**', style: markerStyle));
        } else if (match.startsWith('*')) {
          final content = match.substring(1, match.length - 1);
          children.add(TextSpan(text: '*', style: markerStyle));
          children.add(
            TextSpan(
              text: content,
              style: style?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.teal,
              ),
            ),
          );
          children.add(TextSpan(text: '*', style: markerStyle));
        } else if (match.startsWith('__')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '__', style: markerStyle));
          children.add(
            TextSpan(
              text: content,
              style: style?.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.blue,
              ),
            ),
          );
          children.add(TextSpan(text: '__', style: markerStyle));
        } else if (match.startsWith('~~')) {
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '~~', style: markerStyle));
          children.add(
            TextSpan(
              text: content,
              style: style?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: Colors.redAccent,
              ),
            ),
          );
          children.add(TextSpan(text: '~~', style: markerStyle));
        } else if (match.startsWith('- ')) {
          children.add(
            TextSpan(
              text: '• ',
              style: style?.copyWith(
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          children.add(TextSpan(text: match.substring(2), style: style));
        } else if (RegExp(r'^\d+\. ').hasMatch(match)) {
          final dotIndex = match.indexOf('. ');
          final number = match.substring(0, dotIndex + 1);
          children.add(
            TextSpan(
              text: number,
              style: style?.copyWith(
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          children.add(
            TextSpan(text: match.substring(dotIndex + 1), style: style),
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
          // [:color:#RRGGBB:]
          final hexColor = match.substring(8, 15);
          try {
            final color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
            // Find the rest of the line to apply the color to
            // Note: Inline colors apply to the immediate next segment in this simple model
            children.add(TextSpan(text: match, style: markerStyle));
            // We'll return and let splitMapJoin handle the next segment or manually handle it if needed
            // For now, this marker just stores the state for the PDF service
            // and we style it slightly in the editor as a hint
            children.add(
              TextSpan(
                text: ' ● ',
                style: TextStyle(color: color, fontSize: 16),
              ),
            );
          } catch (_) {
            children.add(TextSpan(text: match, style: style));
          }
        } else if (match.startsWith('##')) {
          children.add(TextSpan(text: '## ', style: markerStyle));
          children.add(
            TextSpan(
              text: match.substring(3).trim(),
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.indigoAccent,
              ),
            ),
          );
        } else if (match.startsWith('#')) {
          children.add(TextSpan(text: '# ', style: markerStyle));
          children.add(
            TextSpan(
              text: match.substring(2).trim(),
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.deepPurple,
              ),
            ),
          );
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
    _toggleLineStart('# ', replaceOthers: ['## ']);
  }

  void toggleH2() {
    _toggleLineStart('## ', replaceOthers: ['# ']);
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
      text = curText.replaceRange(lineStart, lineStart + marker.length, '');
      selection = TextSelection.collapsed(
        offset: (curSelection.start - marker.length).clamp(0, text.length),
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
      text = removedText.replaceRange(lineStart, lineStart, marker);
      selection = TextSelection.collapsed(
        offset: (curSelection.start - foundOther.length + marker.length).clamp(
          0,
          text.length,
        ),
      );
    } else {
      // Add new marker
      text = curText.replaceRange(lineStart, lineStart, marker);
      selection = TextSelection.collapsed(
        offset: (curSelection.start + marker.length).clamp(0, text.length),
      );
    }
  }

  @override
  void dispose() {
    removeListener(_handleTextChange);
    super.dispose();
  }
}
