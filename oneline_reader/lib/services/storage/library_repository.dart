import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../models/book.dart';
import '../../models/content_unit.dart';
import '../../models/reading_state.dart';
import '../../domain/document_model/document.dart';
import 'document_storage.dart';
import 'local_storage.dart';

class LibraryRepository {
  static const _booksFile = 'books.json';
  static const _statesFile = 'reading_states.json';
  static const _contentDir = 'content';
  static final _uuid = const Uuid();

  final LocalStorage _storage = LocalStorage.instance;
  final DocumentStorage _documentStorage = DocumentStorage();

  Future<List<Book>> loadBooks() async {
    final raw = await _storage.readJsonList(_booksFile);
    return raw.map((e) => Book.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveBooks(List<Book> books) async {
    await _storage.writeJson(_booksFile, books.map((b) => b.toJson()).toList());
  }

  Future<List<ReadingState>> loadStates() async {
    final raw = await _storage.readJsonList(_statesFile);
    return raw
        .map((e) => ReadingState.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveStates(List<ReadingState> states) async {
    await _storage
        .writeJson(_statesFile, states.map((s) => s.toJson()).toList());
  }

  Future<void> deleteBook(String bookId) async {
    final books = await loadBooks();
    final updatedBooks = books.where((b) => b.id != bookId).toList();
    await saveBooks(updatedBooks);

    final states = await loadStates();
    final updatedStates = states.where((s) => s.bookId != bookId).toList();
    await saveStates(updatedStates);

    // Delete content file
    final content = await _contentFile(bookId);
    if (await content.exists()) {
      await content.delete();
    }

    // Delete stored book file if present
    final removed = books.firstWhereOrNull((b) => b.id == bookId);
    if (removed != null) {
      final file = File(removed.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> saveContentUnits(String bookId, List<ContentUnit> units) async {
    final contentFile = await _contentFile(bookId);
    await contentFile.writeAsString(
      // store as line-delimited json to avoid single huge string load
      units.map((u) => jsonEncode(u.toJson())).join('\n'),
    );
  }

  Future<List<ContentUnit>> loadContentUnits(String bookId) async {
    final file = await _contentFile(bookId);
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) =>
            ContentUnit.fromJson(Map<String, dynamic>.from(_parseLine(line))))
        .toList();
  }

  Map<String, dynamic> _parseLine(String line) {
    return line.startsWith('{') ? _parseJson(line) : {};
  }

  Map<String, dynamic> _parseJson(String content) {
    try {
      return Map<String, dynamic>.from(jsonDecode(content));
    } catch (_) {
      return {};
    }
  }

  Future<File> _contentFile(String bookId) async {
    final dir = await _storage.getAppDir();
    final folder = Directory('${dir.path}/$_contentDir');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File('${folder.path}/$bookId.jsonl');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Store canonical document JSON for the given book.
  Future<void> saveDocument(String bookId, Document document) async {
    await _documentStorage.saveDocument(bookId, document);
  }

  /// Load canonical document if present.
  Future<Document?> loadDocument(String bookId) async {
    return _documentStorage.loadDocument(bookId);
  }

  Book createBook({
    String? id,
    required String filePath,
    required String originalFileName,
    required String title,
    required String author,
    required int totalUnits,
  }) {
    final now = DateTime.now();
    return Book(
      id: id ?? _uuid.v4(),
      filePath: filePath,
      originalFileName: originalFileName,
      title: title,
      author: author,
      createdAt: now,
      updatedAt: now,
      totalUnits: totalUnits,
    );
  }

  ReadingState createInitialState(String bookId) {
    return ReadingState(
      bookId: bookId,
      currentUnitIndex: 0,
      theme: AppThemeMode.system,
      fontScale: 1.0,
      lastOpenedAt: DateTime.now(),
    );
  }

  Future<void> upsertState(ReadingState state) async {
    final states = await loadStates();
    final idx = states.indexWhere((s) => s.bookId == state.bookId);
    if (idx >= 0) {
      states[idx] = state.copyWith(lastOpenedAt: DateTime.now());
    } else {
      states.add(state.copyWith(lastOpenedAt: DateTime.now()));
    }
    await saveStates(states);
  }

  Future<ReadingState?> getState(String bookId) async {
    final states = await loadStates();
    return states.firstWhereOrNull((s) => s.bookId == bookId);
  }
}
