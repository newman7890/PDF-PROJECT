import 'package:flutter/material.dart';

enum EditType { text, drawing }

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
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  bool isH1;
  bool isH2;
  TextAlign textAlign;

  TextEditItem({
    required super.id,
    required super.pageIndex,
    required super.position,
    required this.text,
    this.fontSize = 14.0,
    this.color = Colors.black,
    this.width = 150.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isH1 = false,
    this.isH2 = false,
    this.textAlign = TextAlign.left,
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
