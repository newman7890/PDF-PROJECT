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
    return buildRichTextSpan(text, style);
  }

  /// Reusable rich text parser that handles bold, italic, underline, strikethrough,
  /// headers, lists, and color markers.
  static TextSpan buildRichTextSpan(String text, TextStyle? style) {
    if (text.isEmpty) return TextSpan(style: style);
    return _buildSpanRecursive(text, style);
  }

  static TextSpan _buildSpanRecursive(String text, TextStyle? style) {
    if (text.isEmpty) return TextSpan(style: style);

    final List<InlineSpan> children = [];
    final markerStyle = (style ?? const TextStyle()).copyWith(
      color: Colors.transparent,
      fontSize: 0.1, // Near-zero size to collapse space
      height: 0,
      letterSpacing: -1,
    );

    text.splitMapJoin(
      RegExp(
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
      ),
      onMatch: (m) {
        final match = m.group(0)!;

        if (m.group(1) != null) {
          // *** Bold + Italic ***
          final content = match.substring(3, match.length - 3);
          children.add(TextSpan(text: '***', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.black,
              ),
            ),
          );
          children.add(TextSpan(text: '***', style: markerStyle));
        } else if (m.group(2) != null) {
          // H1
          String content;
          String startMarker;
          String endMarker = '';
          if (match.toLowerCase().startsWith('[h1]')) {
            content = match.substring(4, match.length - 5);
            startMarker = match.substring(0, 4);
            endMarker = match.substring(match.length - 5);
          } else {
            final hashMatch = RegExp(r'^\s*#\s+').firstMatch(match)!;
            startMarker = hashMatch.group(0)!;
            content = match.substring(startMarker.length);
          }
          children.add(TextSpan(text: startMarker, style: markerStyle));
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
          if (endMarker.isNotEmpty) {
            children.add(TextSpan(text: endMarker, style: markerStyle));
          }
        } else if (m.group(3) != null) {
          // H2
          String content;
          String startMarker;
          String endMarker = '';
          if (match.toLowerCase().startsWith('[h2]')) {
            content = match.substring(4, match.length - 5);
            startMarker = match.substring(0, 4);
            endMarker = match.substring(match.length - 5);
          } else {
            final hashMatch = RegExp(r'^\s*##\s+').firstMatch(match)!;
            startMarker = hashMatch.group(0)!;
            content = match.substring(startMarker.length);
          }
          children.add(TextSpan(text: startMarker, style: markerStyle));
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
          if (endMarker.isNotEmpty) {
            children.add(TextSpan(text: endMarker, style: markerStyle));
          }
        } else if (m.group(4) != null) {
          // H3
          String content;
          String startMarker;
          String endMarker = '';
          if (match.toLowerCase().startsWith('[h3]')) {
            content = match.substring(4, match.length - 5);
            startMarker = match.substring(0, 4);
            endMarker = match.substring(match.length - 5);
          } else {
            final hashMatch = RegExp(r'^\s*###\s+').firstMatch(match)!;
            startMarker = hashMatch.group(0)!;
            content = match.substring(startMarker.length);
          }
          children.add(TextSpan(text: startMarker, style: markerStyle));
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
          if (endMarker.isNotEmpty) {
            children.add(TextSpan(text: endMarker, style: markerStyle));
          }
        } else if (m.group(5) != null) {
          // ** Bold **
          final content = match.substring(2, match.length - 2);
          children.add(TextSpan(text: '**', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          );
          children.add(TextSpan(text: '**', style: markerStyle));
        } else if (m.group(6) != null) {
          // * Italic *
          final content = match.substring(1, match.length - 1);
          children.add(TextSpan(text: '*', style: markerStyle));
          children.add(
            _buildSpanRecursive(
              content,
              style?.copyWith(fontStyle: FontStyle.italic, color: Colors.black),
            ),
          );
          children.add(TextSpan(text: '*', style: markerStyle));
        } else if (m.group(7) != null) {
          // __ Underline __
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
        } else if (m.group(8) != null) {
          // ~~ Strike ~~
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
        } else if (m.group(9) != null) {
          // Bullet
          children.add(
            TextSpan(
              text: '• ',
              style: (style ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          );
          children.add(
            _buildSpanRecursive(
              match.substring(2),
              style?.copyWith(color: Colors.black),
            ),
          );
        } else if (m.group(10) != null) {
          // Numbered
          final dotIndex = match.indexOf('. ');
          children.add(
            TextSpan(
              text: match.substring(0, dotIndex + 2),
              style: (style ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          );
          children.add(
            _buildSpanRecursive(
              match.substring(dotIndex + 2),
              style?.copyWith(color: Colors.black),
            ),
          );
        } else if (m.group(11) != null) {
          // HR
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
        } else if (m.group(12) != null) {
          // Color / Meta
          if (match.startsWith('[:color:') && match.endsWith(':]')) {
            try {
              // Extract dynamically based on length, preventing out of bounds on short strings
              final hexColor = match.substring(8, match.length - 2);
              final color = Color(
                int.parse(hexColor.replaceFirst('#', '0xFF')),
              );
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
          } else if (match.startsWith('[:left:]') ||
              match.startsWith('[:center:]') ||
              match.startsWith('[:right:]')) {
            children.add(TextSpan(text: match, style: markerStyle));
          } else {
            children.add(TextSpan(text: match, style: markerStyle));
          }
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
    final curSelection = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
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
    final curSelection = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
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

    if (selectedText.length >= prefix.length + suffix.length &&
        selectedText.startsWith(prefix) &&
        selectedText.endsWith(suffix)) {
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
    final curSelection = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
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
