import 'dart:io';

/// Model representing a scanned document or an imported PDF.
class ScannedDocument {
  final String id;
  final String title;
  final String filePath;
  final DateTime dateCreated;
  final bool isPdf;

  final bool? isScanned;
  final String? fileSize;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.filePath,
    required this.dateCreated,
    this.isPdf = true,
    this.isScanned,
    this.fileSize,
  });

  /// Factory constructor to create a ScannedDocument from a Map (useful for local storage).
  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    return ScannedDocument(
      id: map['id'],
      title: map['title'],
      filePath: map['filePath'],
      dateCreated: DateTime.parse(map['dateCreated']),
      isPdf: map['isPdf'] ?? true,
      isScanned: map['isScanned'],
      fileSize: map['fileSize'],
    );
  }

  ScannedDocument copyWith({
    String? title,
    String? filePath,
    bool? isPdf,
    bool? isScanned,
    String? fileSize,
  }) {
    return ScannedDocument(
      id: id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      dateCreated: dateCreated,
      isPdf: isPdf ?? this.isPdf,
      isScanned: isScanned ?? this.isScanned,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  /// Converts the ScannedDocument into a Map for local storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'dateCreated': dateCreated.toIso8601String(),
      'isPdf': isPdf,
      'isScanned': isScanned,
      'fileSize': fileSize,
    };
  }

  /// Returns the file size in a readable format.
  String getFileSize() {
    if (fileSize != null) return fileSize!;

    final file = File(filePath);
    if (!file.existsSync()) return "Unknown size";
    final bytes = file.lengthSync();
    return formatBytes(bytes);
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}
