import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../domain/document_model/block.dart';
import '../domain/document_model/document.dart';
import '../domain/document_model/footnote.dart';
import '../domain/document_model/inline_span.dart';
import '../domain/document_model/metadata.dart';

abstract class DocumentImporter {
  bool supports(String extension);
  Future<Document> importFile(File file, {required String docId});
}

class ImportManager {
  ImportManager({List<DocumentImporter>? importers})
      : _importers = importers ??
            [
              TxtImporter(),
              EpubImporter(),
              DocxImporter(),
              PdfUnsupportedImporter(),
              MobiUnsupportedImporter(),
            ];

  final List<DocumentImporter> _importers;

  Future<Document> importFile(File file, {required String docId}) async {
    final ext = file.path.split('.').last.toLowerCase();
    final importer = _importers.firstWhere(
      (i) => i.supports(ext),
      orElse: () => throw UnsupportedError('Unsupported extension: $ext'),
    );
    return importer.importFile(file, docId: docId);
  }
}

class TxtImporter implements DocumentImporter {
  @override
  bool supports(String extension) => extension == 'txt';

  @override
  Future<Document> importFile(File file, {required String docId}) async {
    final raw = await file.readAsString();
    final paras = raw
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll('\r', ''))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final blocks = <Block>[];
    for (var i = 0; i < paras.length; i++) {
      blocks.add(
        ParagraphBlock(
          id: 'p$i',
          text: paras[i],
          spans: [
            StyleSpan(start: 0, end: paras[i].length, attrs: const TextStyleAttrs()),
          ],
          meta: const BlockMeta(),
        ),
      );
    }
    return Document(
      docId: docId,
      title: file.uri.pathSegments.last,
      author: 'Unknown',
      blocks: blocks,
      footnotes: const {},
      meta: DocumentMeta(
        source: DocumentSourceFormat.txt,
        originalPath: file.path,
        originalFileName: file.uri.pathSegments.last,
        importedAt: DateTime.now(),
      ),
    );
  }
}

class EpubImporter implements DocumentImporter {
  @override
  bool supports(String extension) => extension == 'epub';

  @override
  Future<Document> importFile(File file, {required String docId}) async {
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final title = book.Title?.trim().isNotEmpty == true
        ? book.Title!
        : 'Untitled Book';
    final author = book.Author?.trim().isNotEmpty == true
        ? book.Author!
        : (book.Schema?.Package?.Metadata?.Creators?.firstOrNull?.Creator ??
            'Unknown');

    final blocks = <Block>[];
    final footnotes = <String, Footnote>{};

    void extractFromHtml(String html) {
      final document = html_parser.parse(html);
      final body = document.body;
      if (body == null) return;
      // Build map of potential footnote targets by id.
      final footnoteTargets = <String, String>{};
      for (final el in document.querySelectorAll('[id]')) {
        final id = el.id;
        if (id.isNotEmpty) {
          footnoteTargets[id] = el.text.trim();
        }
      }
      for (final element in body.children) {
        final local = element.localName ?? '';
        final headingLevel = _headingLevel(local);
        final text = element.text;
        if (text.trim().isEmpty) continue;
        final spans = <InlineSpanModel>[];
        int cursor = 0;
        for (final node in element.nodes) {
          final nodeText = node.text ?? '';
          if (nodeText.isEmpty) continue;
          final start = cursor;
          final end = cursor + nodeText.length;
          final href = node.attributes['href'];
          if (href != null && href.startsWith('#')) {
            final id = href.substring(1);
            final label = nodeText.trim().isEmpty ? id : nodeText.trim();
            spans.add(FootnoteRefSpan(
              start: start,
              end: end,
              footnoteId: id,
              label: label,
            ));
            final content = footnoteTargets[id];
            if (content != null && !footnotes.containsKey(id)) {
              footnotes[id] = Footnote(
                id: id,
                label: label,
                blocks: [
                  ParagraphBlock(
                    id: 'fn_$id',
                    text: content,
                    spans: [
                      StyleSpan(
                        start: 0,
                        end: content.length,
                        attrs: const TextStyleAttrs(),
                      )
                    ],
                    meta: const BlockMeta(),
                  )
                ],
                meta: FootnoteMeta(sourceBlockId: element.id),
              );
            }
          } else {
            spans.add(
              StyleSpan(
                start: start,
                end: end,
                attrs: TextStyleAttrs(
                  bold: _isBold(node.parent?.localName),
                  italic: _isItalic(node.parent?.localName),
                  underline: _isUnderline(node.parent?.localName),
                ),
              ),
            );
          }
          cursor = end;
        }
        final blockId = 'ep_${blocks.length}';
        if (headingLevel != null) {
          blocks.add(
            HeadingBlock(
              id: blockId,
              text: text,
              spans: spans,
              level: headingLevel,
              meta: BlockMeta(headingLevel: headingLevel),
            ),
          );
        } else {
          blocks.add(
            ParagraphBlock(
              id: blockId,
              text: text,
              spans: spans,
              meta: const BlockMeta(),
            ),
          );
        }
      }
    }

    for (final spineItem in book.Chapters ?? []) {
      if (spineItem.HtmlContent != null) {
        extractFromHtml(spineItem.HtmlContent!);
      }
      for (final sub in spineItem.SubChapters ?? []) {
        if (sub.HtmlContent != null) {
          extractFromHtml(sub.HtmlContent!);
        }
      }
    }

    return Document(
      docId: docId,
      title: title,
      author: author,
      blocks: blocks,
      footnotes: footnotes,
      meta: DocumentMeta(
        source: DocumentSourceFormat.epub,
        originalPath: file.path,
        originalFileName: file.uri.pathSegments.last,
        importedAt: DateTime.now(),
      ),
    );
  }

  int? _headingLevel(String? tag) {
    if (tag == null) return null;
    if (RegExp(r'h[1-6]').hasMatch(tag)) {
      return int.tryParse(tag.substring(1));
    }
    return null;
  }

  bool _isBold(String? tag) => tag == 'b' || tag == 'strong';
  bool _isItalic(String? tag) => tag == 'i' || tag == 'em';
  bool _isUnderline(String? tag) => tag == 'u';
}

class DocxImporter implements DocumentImporter {
  @override
  bool supports(String extension) => extension == 'docx';

  @override
  Future<Document> importFile(File file, {required String docId}) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final xmlFile =
        archive.files.firstWhereOrNull((f) => f.name == 'word/document.xml');
    final title = file.uri.pathSegments.last;
    if (xmlFile == null) {
      return _emptyDoc(docId, title, file.path);
    }
    final xmlContent = utf8.decode(xmlFile.content as List<int>);
    final doc = XmlDocument.parse(xmlContent);
    final paragraphNodes = doc.findAllElements('w:p');
    final blocks = <Block>[];
    int idx = 0;
    for (final p in paragraphNodes) {
      final styleNode = p.findElements('w:pPr').firstOrNull;
      final styleVal =
          styleNode?.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
      final headingLevel = _headingFromStyle(styleVal);
      final runs = p.findAllElements('w:r');
      final textBuffer = StringBuffer();
      int offset = 0;
      final spans = <InlineSpanModel>[];
      for (final r in runs) {
        final textNode = r.findElements('w:t').firstOrNull?.innerText ?? '';
        if (textNode.isEmpty) continue;
        final rPr = r.findElements('w:rPr').firstOrNull;
        final bold = rPr?.findElements('w:b').isNotEmpty ?? false;
        final italic = rPr?.findElements('w:i').isNotEmpty ?? false;
        final underline = rPr?.findElements('w:u').isNotEmpty ?? false;
        final start = offset;
        final end = offset + textNode.length;
        spans.add(
          StyleSpan(
            start: start,
            end: end,
            attrs: TextStyleAttrs(
              bold: bold,
              italic: italic,
              underline: underline,
            ),
          ),
        );
        textBuffer.write(textNode);
        offset = end;
      }
      final text = textBuffer.toString();
      if (text.trim().isEmpty) continue;
      final blockId = 'doc_$idx';
      if (headingLevel != null) {
        blocks.add(
          HeadingBlock(
            id: blockId,
            text: text,
            spans: spans,
            level: headingLevel,
            meta: BlockMeta(headingLevel: headingLevel),
          ),
        );
      } else {
        blocks.add(
          ParagraphBlock(
            id: blockId,
            text: text,
            spans: spans,
            meta: const BlockMeta(),
          ),
        );
      }
      idx++;
    }

    return Document(
      docId: docId,
      title: title,
      author: 'Unknown',
      blocks: blocks,
      footnotes: const {},
      meta: DocumentMeta(
        source: DocumentSourceFormat.docx,
        originalPath: file.path,
        originalFileName: file.uri.pathSegments.last,
        importedAt: DateTime.now(),
      ),
    );
  }

  int? _headingFromStyle(String? style) {
    if (style == null) return null;
    final match = RegExp(r'Heading(\d)').firstMatch(style);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Document _emptyDoc(String docId, String title, String path) {
    return Document(
      docId: docId,
      title: title,
      author: 'Unknown',
      blocks: const [],
      footnotes: const {},
      meta: DocumentMeta(
        source: DocumentSourceFormat.docx,
        originalPath: path,
        originalFileName: title,
        importedAt: DateTime.now(),
      ),
    );
  }
}

class PdfUnsupportedImporter implements DocumentImporter {
  @override
  bool supports(String extension) => extension == 'pdf';

  @override
  Future<Document> importFile(File file, {required String docId}) {
    throw UnsupportedError(
        'PDF extraction is not ready yet. Please use native PDF view or provide EPUB/TXT/DOCX.');
  }
}

class MobiUnsupportedImporter implements DocumentImporter {
  @override
  bool supports(String extension) =>
      extension == 'mobi' || extension == 'azw' || extension == 'azw3';

  @override
  Future<Document> importFile(File file, {required String docId}) {
    throw UnsupportedError(
        'MOBI/AZW may be DRM-protected. Please provide a DRM-free EPUB/TXT/DOCX instead.');
  }
}
