import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/book.dart';
import '../parser/book_parser.dart';
import '../parser/sentence_tokenizer.dart';
import '../storage/library_repository.dart';
import '../storage/local_storage.dart';

class BookImportService {
  BookImportService({
    LibraryRepository? libraryRepository,
    BookParser? parser,
  })  : _repo = libraryRepository ?? LibraryRepository(),
        _parser = parser ?? BookParser();

  final LibraryRepository _repo;
  final BookParser _parser;
  final LocalStorage _storage = LocalStorage.instance;
  final _uuid = const Uuid();

  Future<Book> importFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }
    final picked = result.files.first;
    final bytes = picked.bytes;
    final filePath = picked.path;
    if (bytes == null && filePath == null) {
      throw Exception('Unable to read selected file');
    }
    final tempFile = bytes != null
        ? await _writeTempFile(picked.name, bytes)
        : File(filePath!);

    // Parse content
    final parsed = await _parser.parseFile(tempFile);
    final bookId = _uuid.v4();

    // Copy file into app storage
    final storedFile =
        await _storage.copyIntoApp(tempFile, 'books/${picked.name}');

    final tokenizer = SentenceTokenizer();
    final units = tokenizer.buildUnits(
      bookId: bookId,
      paragraphs: parsed.paragraphs,
    );

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

  Future<File> _writeTempFile(String name, List<int> bytes) async {
    final dir = await _storage.getAppDir();
    final file = File('${dir.path}/tmp_$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
