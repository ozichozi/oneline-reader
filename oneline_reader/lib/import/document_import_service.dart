import 'dart:io';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../domain/document_model/block.dart';
import '../domain/document_model/document.dart';
import '../domain/document_model/footnote.dart';
import '../domain/document_model/inline_span.dart';
import '../domain/document_model/metadata.dart';
import '../services/parser/book_parser.dart';
import '../services/parser/sentence_tokenizer.dart';

class DocumentImportService {
  DocumentImportService({
    BookParser? bookParser,
  }) : _bookParser = bookParser ?? BookParser();

  final BookParser _bookParser;
  final _uuid = const Uuid();

  /// Import a file and normalize into the canonical Document model.
  Future<Document> importFile(File file, {String? docId}) async {
    final ext = file.path.split('.').last.toLowerCase();
    final source = _mapSource(ext);
    // Logging for debugging import path decisions.
    // Using print for now; replace with structured logger if added later.
    print('[Import] Starting import for ${file.path} as $source');
    if (source == DocumentSourceFormat.mobi) {
      throw UnsupportedError(
          'DRM-protected or MOBI/AZW formats are not supported offline. Please provide a DRM-free file.');
    }
    if (source == DocumentSourceFormat.pdf) {
      // Placeholder: add best-effort PDF extraction when available.
       print('[Import] PDF source detected; native extraction not implemented, failing early.');
      throw UnsupportedError(
          'PDF extraction not implemented yet. Use native viewer fallback.');
    }

    // Reuse existing parser for txt/epub/docx while the new pipeline is wired.
    print('[Import] Parsing with existing parser for $ext');
    final parsed = await _bookParser.parseFile(file);
    print('[Import] Parsed title="${parsed.title}" paragraphs=${parsed.paragraphs.length}');
    final blocks = parsed.paragraphs.map(_paragraphToBlock).toList();

    // TODO: detect and attach real footnotes for EPUB/DOCX.
    final footnotes = <String, Footnote>{};

    return Document(
      docId: docId ?? _uuid.v4(),
      title: parsed.title,
      author: parsed.author,
      blocks: blocks,
      footnotes: footnotes,
      meta: DocumentMeta(
        source: source,
        originalPath: file.path,
        originalFileName: file.uri.pathSegments.lastOrNull,
        importedAt: DateTime.now(),
      ),
    );
  }

  ParagraphBlock _paragraphToBlock(ParagraphInput input) {
    final spans = <InlineSpanModel>[];
    int offset = 0;
    int? headingLevel;
    for (final seg in input.segments) {
      final start = offset;
      final end = offset + seg.text.length;
      headingLevel ??= seg.headingLevel;
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
      offset = end;
    }
    final meta = headingLevel != null
        ? BlockMeta(headingLevel: headingLevel)
        : const BlockMeta();
    if (headingLevel != null) {
      return HeadingBlock(
        id: input.id,
        text: input.text,
        spans: spans,
        level: headingLevel!,
        meta: meta,
      );
    }
    return ParagraphBlock(
      id: input.id,
      text: input.text,
      spans: spans,
      meta: meta,
    );
  }

  DocumentSourceFormat _mapSource(String ext) {
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
