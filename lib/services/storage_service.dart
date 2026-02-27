import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/scanned_document.dart';

/// Service to handle local file storage for documents.
/// This service saves metadata about scanned documents in a JSON file.
class StorageService {
  static const String _metadataFile = 'documents_metadata.json';

  /// Gets the local directory for app documents.
  Future<Directory> get _localDirectory async {
    return await getApplicationDocumentsDirectory();
  }

  /// Saves a document's metadata and ensures the file is in the app's directory.
  Future<void> saveDocument(ScannedDocument doc) async {
    final docs = await loadDocuments();

    // Check if the document already exists in metadata
    final index = docs.indexWhere((item) => item.id == doc.id);
    if (index != -1) {
      docs[index] = doc;
    } else {
      docs.add(doc);
    }

    await _saveMetadata(docs);
  }

  /// Loads all saved documents from local storage.
  Future<List<ScannedDocument>> loadDocuments() async {
    try {
      final directory = await _localDirectory;
      final file = File(path.join(directory.path, _metadataFile));

      if (!file.existsSync()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => ScannedDocument.fromMap(e)).toList()
        ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    } catch (e) {
      debugPrint("Error loading documents: $e");
      return [];
    }
  }

  /// Deletes a document and its associated file.
  Future<void> deleteDocument(ScannedDocument doc) async {
    final docs = await loadDocuments();
    docs.removeWhere((item) => item.id == doc.id);
    await _saveMetadata(docs);

    // Also delete the physical file
    final file = File(doc.filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Helper to save the document list to JSON.
  Future<void> _saveMetadata(List<ScannedDocument> docs) async {
    final directory = await _localDirectory;
    final file = File(path.join(directory.path, _metadataFile));
    final jsonContent = json.encode(docs.map((e) => e.toMap()).toList());
    await file.writeAsString(jsonContent);
  }

  /// Returns a path for a new PDF file.
  Future<String> getNewFilePath(String fileName) async {
    final directory = await _localDirectory;
    String name = fileName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    return path.join(directory.path, "$name.pdf");
  }
}
