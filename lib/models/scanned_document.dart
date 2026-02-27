import 'dart:io';

/// Model representing a scanned document or an imported PDF.
class ScannedDocument {
  final String id;
  final String title;
  final String filePath;
  final DateTime dateCreated;
  final bool isPdf;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.filePath,
    required this.dateCreated,
    this.isPdf = true,
  });

  /// Factory constructor to create a ScannedDocument from a Map (useful for local storage).
  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    return ScannedDocument(
      id: map['id'],
      title: map['title'],
      filePath: map['filePath'],
      dateCreated: DateTime.parse(map['dateCreated']),
      isPdf: map['isPdf'] ?? true,
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
    };
  }

  /// Returns the file size in a readable format.
  String getFileSize() {
    final file = File(filePath);
    if (!file.existsSync()) return "Unknown size";
    final bytes = file.lengthSync();
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}
