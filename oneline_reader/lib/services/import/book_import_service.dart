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
import '../../import/import_manager.dart';
import '../parser/sentence_tokenizer.dart';
import '../storage/library_repository.dart';
import '../storage/local_storage.dart';
import '../../reader/pagination/page_ref.dart';
import '../../reader/pagination/sentence_segmenter.dart';
import '../../models/styled_text.dart';

class BookImportService {
  BookImportService({
    LibraryRepository? libraryRepository,
    ImportManager? importManager,
  })  : _repo = libraryRepository ?? LibraryRepository(),
        _importManager = importManager ?? ImportManager();

  final LibraryRepository _repo;
  final LocalStorage _storage = LocalStorage.instance;
  final _uuid = const Uuid();
  final ImportManager _importManager;

  Future<Book> importFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'docx', 'pdf', 'mobi', 'azw', 'azw3'],
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

    print('[Import] Starting import for ${picked.name} (${picked.path})');
    // Parse content off the main isolate
    final parsedResult = await compute<_ParseArgs, _ParsedResult>(
      _parseInIsolate,
      _ParseArgs(tempFile.path, bookId),
    );

    // Copy file into app storage
    final storedFile =
        await _storage.copyIntoApp(tempFile, 'books/${picked.name}');

    final document = parsedResult.document;
    final units = parsedResult.units;
    print(
        '[Import] Parsed document blocks=${document.blocks.length} footnotes=${document.footnotes.length} units=${units.length}');

    await _repo.saveDocument(bookId, document);
    print('[Import] Saved canonical document for $bookId');

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
      final headingLevel =
          block is HeadingBlock ? block.level : block.meta.headingLevel;
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
            segments: [
              StyledSegment(
                text: text,
                headingLevel: headingLevel,
              ),
            ],
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
