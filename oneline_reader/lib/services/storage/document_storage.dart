import 'dart:convert';
import 'dart:io';

import '../../domain/document_model/document.dart';
import 'local_storage.dart';

class DocumentStorage {
  DocumentStorage({LocalStorage? localStorage})
      : _local = localStorage ?? LocalStorage.instance;

  final LocalStorage _local;

  Future<void> saveDocument(String bookId, Document document) async {
    final file = await _local.getFile('documents/$bookId.json');
    final payload = jsonEncode(document.toJson());
    await file.writeAsString(payload);
  }

  Future<Document?> loadDocument(String bookId) async {
    final file = await _local.getFile('documents/$bookId.json');
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    if (content.trim().isEmpty) return null;
    return Document.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
