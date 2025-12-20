import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/book.dart';
import '../../models/content_unit.dart';
import '../../domain/document_model/block.dart';
import '../../domain/document_model/document.dart';
import '../../import/import_manager.dart';
import '../storage/library_repository.dart';
import '../storage/local_storage.dart';
import '../../reader/pagination/page_ref.dart';
import '../../reader/pagination/sentence_segmenter.dart';
import '../../models/styled_text.dart';
import '../../utils/app_logger.dart';

class BookImportService {
  BookImportService({LibraryRepository? libraryRepository})
    : _repo = libraryRepository ?? LibraryRepository();

  final LibraryRepository _repo;
  final LocalStorage _storage = LocalStorage.instance;
  final _uuid = const Uuid();
  final AppLogger _log = const AppLogger('BookImportService');

  Future<Book> importFromDevice({ValueChanged<ImportPreview>? onPreview}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'epub',
        'docx',
        'pdf',
        'mobi',
        'azw',
        'azw3',
      ],
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
    final ext = picked.extension?.toLowerCase() ?? '';
    final bookId = _uuid.v4();
    final initialPreview = ImportPreview(
      title: _stripExtension(picked.name),
      author: 'Unknown',
    );
    onPreview?.call(initialPreview);

    _log.info('Starting import', context: {'file': picked.name, 'ext': ext});
    // Parse content off the main isolate
    final parsedResult = await compute<_ParseArgs, _ParsedResult>(
      _parseInIsolate,
      _ParseArgs(tempFile.path, bookId),
    );
    onPreview?.call(
      ImportPreview(
        title: parsedResult.document.title,
        author: parsedResult.document.author ?? 'Unknown',
      ),
    );

    // Copy file into app storage
    final storedFile = await _storage.copyIntoApp(
      tempFile,
      'books/${picked.name}',
    );

    final document = parsedResult.document;
    final units = parsedResult.units;
    _log.info(
      'Parsed document',
      context: {
        'blocks': document.blocks.length,
        'footnotes': document.footnotes.length,
        'units': units.length,
      },
    );

    await _repo.saveDocument(bookId, document);
    _log.info('Saved canonical document', context: {'bookId': bookId});

    final pages = paginateDocument(
      document: document,
      segmenter: SentenceSegmenter(),
      mode: PageMode.sentence,
    );

    final book = _repo.createBook(
      id: bookId,
      filePath: storedFile.path,
      originalFileName: picked.name,
      title: document.title,
      author: document.author ?? 'Unknown',
      totalUnits: pages.isNotEmpty ? pages.length : units.length,
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

  /// Re-import an existing stored book file to upgrade to canonical document.
  Future<Book> reimport(Book existing) async {
    final file = File(existing.filePath);
    if (!await file.exists()) {
      throw Exception('Original file missing at ${existing.filePath}');
    }
    _log.info('Reimporting existing book', context: {'bookId': existing.id});
    final parsed = await compute<_ParseArgs, _ParsedResult>(
      _parseInIsolate,
      _ParseArgs(file.path, existing.id),
    );
    final document = parsed.document;
    final units = parsed.units;
    await _repo.saveDocument(existing.id, document);
    await _repo.saveContentUnits(existing.id, units);

    final pages = paginateDocument(
      document: document,
      segmenter: SentenceSegmenter(),
      mode: PageMode.sentence,
    );

    final updatedBook = existing.copyWith(
      title: document.title,
      author: document.author ?? existing.author,
      updatedAt: DateTime.now(),
      totalUnits: pages.isNotEmpty ? pages.length : units.length,
    );
    final books = await _repo.loadBooks();
    final idx = books.indexWhere((b) => b.id == existing.id);
    if (idx >= 0) {
      books[idx] = updatedBook;
    }
    await _repo.saveBooks(books);
    return updatedBook;
  }
}

class _ParseArgs {
  _ParseArgs(this.path, this.bookId);
  final String path;
  final String bookId;
}

class _ParsedResult {
  _ParsedResult(this.document, this.units);
  final Document document;
  final List<ContentUnit> units;
}

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

class ImportPreview {
  final String title;
  final String author;

  const ImportPreview({
    required this.title,
    required this.author,
  });
}

Future<_ParsedResult> _parseInIsolate(_ParseArgs args) async {
  final manager = ImportManager();
  final file = File(args.path);
  final document = await manager.importFile(file, docId: args.bookId);
  final units = _legacyUnitsFromDocument(document, args.bookId);
  return _ParsedResult(document, units);
}

List<ContentUnit> _legacyUnitsFromDocument(Document doc, String bookId) {
  final units = <ContentUnit>[];
  int idx = 0;
  final segmenter = SentenceSegmenter();
  for (final block in doc.blocks) {
    if (block.type == BlockType.paragraph || block.type == BlockType.heading) {
      final ranges = segmenter.split(block.text);
      final headingLevel = block is HeadingBlock
          ? block.level
          : block.meta.headingLevel;
      final slices = ranges.isNotEmpty
          ? ranges
          : [TextRange(0, block.text.length)];
      for (final r in slices) {
        final text = block.text.substring(r.start, r.end);
        units.add(
          ContentUnit(
            id: '${bookId}_$idx',
            bookId: bookId,
            index: idx,
            type: ContentUnitType.sentence,
            segments: [StyledSegment(text: text, headingLevel: headingLevel)],
            paragraphId: block.id,
          ),
        );
        idx++;
      }
      units.add(
        ContentUnit(
          id: '${bookId}_$idx',
          bookId: bookId,
          index: idx,
          type: ContentUnitType.emptyParagraphBreak,
          segments: const [],
          paragraphId: block.id,
        ),
      );
      idx++;
    }
  }
  return units;
}
