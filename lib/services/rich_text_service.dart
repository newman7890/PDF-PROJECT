import 'package:flutter/material.dart';

/// A simple data model for a styled block of text.
class RichTextBlock {
  String text;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  double fontSize;
  Color color;
  TextAlign alignment;

  RichTextBlock({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize = 14.0,
    this.color = Colors.black,
    this.alignment = TextAlign.left,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isBold': isBold,
    'isItalic': isItalic,
    'isUnderline': isUnderline,
    'fontSize': fontSize,
    'color': color.toARGB32(),
    'alignment': alignment.index,
  };
}

/// A custom controller that handles basic real-time formatting visualization.
class StyledTextController extends TextEditingController {
  bool isBold = false;
  bool isItalic = false;
  Color currentColor = Colors.black;
  double currentFontSize = 16.0;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // For a truly professional editor, we'd manage a list of spans.
    // As a lightweight alternative for this MVP, we'll use simple Regex
    // to highlight basic Markdown-style syntax in the editor for feedback.

    final List<TextSpan> children = [];

    // Simple parsing logic (Expanded MVP version)
    text.splitMapJoin(
      RegExp(
        r'(\*\*.*?\*\*)|(\*.*?\*)|(__.*?__)|(~~.*?~~)|(# .*?\n)|(## .*?\n)|(\[:.*?:\])|(\[.*?\]\(.*?\))',
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
}
