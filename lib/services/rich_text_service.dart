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
    final List<TextSpan> children = [];

    // Improved regex: removes the forced trailing newline for headings
    // so they highlight as soon as the user types '# '
    text.splitMapJoin(
      RegExp(
        r'(\*\*.*?\*\*)|(\*.*?\*)|(__.*?__)|(~~.*?~~)|(^# .*?$|^# .*?\n)|(^## .*?$|^## .*?\n)|(\[:.*?:\])|(\[.*?\]\(.*?\))',
        multiLine: true,
      ),
      onMatch: (m) {
        final match = m.group(0)!;
        if (match.startsWith('**')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          );
        } else if (match.startsWith('*')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.teal,
              ),
            ),
          );
        } else if (match.startsWith('__')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.blue,
              ),
            ),
          );
        } else if (match.startsWith('~~')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: Colors.redAccent,
              ),
            ),
          );
        } else if (match.startsWith('##')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.indigoAccent,
              ),
            ),
          );
        } else if (match.startsWith('#')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.deepPurple,
              ),
            ),
          );
        } else if (match.startsWith('[:')) {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                color: Colors.grey,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
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

  @override
  void dispose() {
    removeListener(_handleTextChange);
    super.dispose();
  }
}
