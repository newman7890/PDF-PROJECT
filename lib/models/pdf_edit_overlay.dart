import 'package:flutter/material.dart';

enum EditType { text, drawing, redact }

abstract class PdfEditItem {
  final String id;
  final int pageIndex;
  final EditType type;
  Offset position; // Position relative to PDF page

  PdfEditItem({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.position,
  });
}

class TextEditItem extends PdfEditItem {
  String text;
  double fontSize;
  Color color;
  double width;

  TextEditItem({
    required super.id,
    required super.pageIndex,
    required super.position,
    required this.text,
    this.fontSize = 14.0,
    this.color = Colors.black,
    this.width = 150.0,
  }) : super(type: EditType.text);
}

class DrawingEditItem extends PdfEditItem {
  List<Offset> points;
  Color color;
  double strokeWidth;

  DrawingEditItem({
    required super.id,
    required super.pageIndex,
    required this.points,
    this.color = Colors.red,
    this.strokeWidth = 2.0,
  }) : super(
         type: EditType.drawing,
         position: points.isNotEmpty ? points.first : Offset.zero,
       );
}
