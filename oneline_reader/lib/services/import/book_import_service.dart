import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/book.dart';
import '../../models/content_unit.dart';
import '../../domain/document_model/block.dart';
import '../../domain/document_model/document.dart';
import '../../domain/document_model/footnote.dart';
import '../../domain/document_model/inline_span.dart';
import '../../domain/document_model/metadata.dart';
import '../parser/book_parser.dart';
import '../parser/sentence_tokenizer.dart';
import '../storage/library_repository.dart';
import '../storage/local_storage.dart';

class BookImportService {
  BookImportService({
    LibraryRepository? libraryRepository,
    BookParser? parser,
  }) : _repo = libraryRepository ?? LibraryRepository();

  final LibraryRepository _repo;
  final LocalStorage _storage = LocalStorage.instance;
  final _uuid = const Uuid();

  Future<Book> importFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'docx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }
    final picked = result.files.first;
    final filePath = picked.path;
    if (filePath == null) {
      throw Exception('Unable to read selected file');
    }
    final tempFile = File(filePath);
    final bookId = _uuid.v4();

    print('[Import] Starting import for ${picked.name} (${picked.path})');
    // Parse content off the main isolate
    final parsedResult = await compute<_ParseArgs, _ParsedResult>(
      _parseInIsolate,
      _ParseArgs(tempFile.path, bookId),
    );

    // Copy file into app storage
    final storedFile =
        await _storage.copyIntoApp(tempFile, 'books/${picked.name}');

    final parsed = parsedResult.parsedBook;
    final units = parsedResult.units;
    print('[Import] Parsed ${parsed.paragraphs.length} paragraphs, ${units.length} units');

    // Build canonical document model (docId == bookId for now).
    final document = _buildDocumentFromParsed(
      parsed,
      bookId,
      storedFile.path,
      picked.name,
    );
    await _repo.saveDocument(bookId, document);
    print('[Import] Saved canonical document for $bookId');

    final book = _repo.createBook(
      id: bookId,
      filePath: storedFile.path,
      originalFileName: picked.name,
      title: parsed.title,
      author: parsed.author,
      totalUnits: units.length,
    );

    await _repo.saveContentUnits(bookId, units);
    final books = await _repo.loadBooks();
    books.add(book);
    await _repo.saveBooks(books);

    // Create initial state
    final state = _repo.createInitialState(book.id);
    final states = await _repo.loadStates();
    states.add(state);
    await _repo.saveStates(states);

    return book;
  }

  Document _buildDocumentFromParsed(
    ParsedBook parsed,
    String bookId,
    String originalPath,
    String originalFileName,
  ) {
    final blocks = parsed.paragraphs.map(_paragraphToBlock).toList();
    return Document(
      docId: bookId,
      title: parsed.title,
      author: parsed.author,
      blocks: blocks,
      footnotes: const <String, Footnote>{}, // TODO: attach real footnotes.
      meta: DocumentMeta(
        source: _mapSource(originalFileName),
        originalPath: originalPath,
        originalFileName: originalFileName,
        importedAt: DateTime.now(),
      ),
    );
  }

  Block _paragraphToBlock(ParagraphInput input) {
    final spans = <InlineSpanModel>[];
    int offset = 0;
    int? headingLevel;
    for (final seg in input.segments) {
      final start = offset;
      final end = offset + seg.text.length;
      spans.add(
        StyleSpan(
          start: start,
          end: end,
          attrs: TextStyleAttrs(
            bold: seg.bold,
            italic: seg.italic,
            underline: seg.underline,
          ),
        ),
      );
      headingLevel ??= seg.headingLevel;
      offset = end;
    }
    if (headingLevel != null) {
      return HeadingBlock(
        id: input.id,
        text: input.text,
        spans: spans,
        level: headingLevel!,
        meta: BlockMeta(headingLevel: headingLevel),
      );
    }
    return ParagraphBlock(
      id: input.id,
      text: input.text,
      spans: spans,
      meta: const BlockMeta(),
    );
  }

  DocumentSourceFormat _mapSource(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
        return DocumentSourceFormat.txt;
      case 'epub':
        return DocumentSourceFormat.epub;
      case 'docx':
        return DocumentSourceFormat.docx;
      case 'pdf':
        return DocumentSourceFormat.pdf;
      case 'mobi':
      case 'azw':
      case 'azw3':
        return DocumentSourceFormat.mobi;
      default:
        return DocumentSourceFormat.unknown;
    }
  }
}

class _ParseArgs {
  _ParseArgs(this.path, this.bookId);
  final String path;
  final String bookId;
}

class _ParsedResult {
  _ParsedResult(this.parsedBook, this.units);
  final ParsedBook parsedBook;
  final List<ContentUnit> units;
}

Future<_ParsedResult> _parseInIsolate(_ParseArgs args) async {
  final parser = BookParser();
  final file = File(args.path);
  final parsed = await parser.parseFile(file);
  final tokenizer = SentenceTokenizer();
  final units =
      tokenizer.buildUnits(bookId: args.bookId, paragraphs: parsed.paragraphs);
  return _ParsedResult(parsed, units);
}
