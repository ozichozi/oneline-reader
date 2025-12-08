import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../models/styled_text.dart';
import 'sentence_tokenizer.dart';

class ParsedBook {
  final String title;
  final String author;
  final List<ParagraphInput> paragraphs;

  ParsedBook({
    required this.title,
    required this.author,
    required this.paragraphs,
  });
}

class BookParser {
  final SentenceTokenizer tokenizer;

  BookParser({SentenceTokenizer? tokenizer})
      : tokenizer = tokenizer ?? SentenceTokenizer();

  Future<ParsedBook> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'txt') {
      return _parseTxt(await file.readAsString());
    }
    if (extension == 'epub') {
      return _parseEpub(await file.readAsBytes());
    }
    if (extension == 'docx') {
      return _parseDocx(await file.readAsBytes());
    }
    throw UnsupportedError('Unsupported file type: $extension');
  }

  ParsedBook _parseTxt(String raw) {
    final paras = raw
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll('\r', ''))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final paragraphInputs = <ParagraphInput>[];
    for (var i = 0; i < paras.length; i++) {
      paragraphInputs.add(
        ParagraphInput(
          id: 'p$i',
          text: paras[i],
          segments: [StyledSegment(text: paras[i])],
        ),
      );
    }
    final title = _deriveTitleFromText(paras);
    return ParsedBook(
      title: title,
      author: 'Unknown',
      paragraphs: paragraphInputs,
    );
  }

  Future<ParsedBook> _parseEpub(List<int> bytes) async {
    final book = await EpubReader.readBook(bytes);
    final title = book.Title?.trim().isNotEmpty == true
        ? book.Title!
        : 'Untitled Book';
    final author = book.Author?.trim().isNotEmpty == true
        ? book.Author!
        : (book.Schema?.Package?.Metadata?.Creators?.firstOrNull?.Creator ??
            'Unknown');

    final paragraphs = <ParagraphInput>[];
    int pIndex = 0;

    void extractFromHtml(String html) {
      final document = html_parser.parse(html);
      final body = document.body;
      if (body == null) return;
      for (final element in body.children) {
        final text = element.text;
        if (text.isEmpty) continue;
        final headingLevel = _headingLevel(element.localName);
        final segments = <StyledSegment>[];
        for (final node in element.nodes) {
          final content = (node.text ?? '');
          if (content.isEmpty) continue;
          segments.add(
            StyledSegment(
              text: content,
              bold: _isBold(node.parent?.localName),
              italic: _isItalic(node.parent?.localName),
              underline: _isUnderline(node.parent?.localName),
              headingLevel: headingLevel,
            ),
          );
        }
        paragraphs.add(
          ParagraphInput(
            id: 'ep$pIndex',
            text: text,
            segments: segments.isNotEmpty
                ? segments
                : [StyledSegment(text: text, headingLevel: headingLevel)],
          ),
        );
        pIndex++;
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

    return ParsedBook(title: title, author: author, paragraphs: paragraphs);
  }

  ParsedBook _parseDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final xmlFile = archive.files
        .firstWhereOrNull((f) => f.name == 'word/document.xml');
    if (xmlFile == null) {
      return ParsedBook(
        title: 'Untitled Document',
        author: 'Unknown',
        paragraphs: [],
      );
    }
    final xmlContent = utf8.decode(xmlFile.content as List<int>);
    final doc = XmlDocument.parse(xmlContent);
    final paragraphNodes = doc.findAllElements('w:p');
    final paragraphs = <ParagraphInput>[];
    int idx = 0;
    for (final p in paragraphNodes) {
      final styleNode = p.findElements('w:pPr').firstOrNull;
      final styleVal = styleNode
          ?.findElements('w:pStyle')
          .firstOrNull
          ?.getAttribute('w:val');
      final headingLevel = _headingFromStyle(styleVal);
      final runs = p.findAllElements('w:r');
      final segments = <StyledSegment>[];
      final buffer = StringBuffer();
      for (final r in runs) {
        final textNode =
            r.findElements('w:t').firstOrNull?.innerText ?? '';
        if (textNode.isEmpty) continue;
        final rPr = r.findElements('w:rPr').firstOrNull;
        final bold = rPr?.findElements('w:b').isNotEmpty ?? false;
        final italic = rPr?.findElements('w:i').isNotEmpty ?? false;
        final underline = rPr?.findElements('w:u').isNotEmpty ?? false;
        segments.add(
          StyledSegment(
            text: textNode,
            bold: bold,
            italic: italic,
            underline: underline,
            headingLevel: headingLevel,
          ),
        );
        buffer.write(textNode);
      }
      final text = buffer.toString();
      if (text.trim().isEmpty) continue;
      paragraphs.add(
        ParagraphInput(
          id: 'doc$idx',
          text: text,
          segments: segments.isNotEmpty
              ? segments
              : [StyledSegment(text: text, headingLevel: headingLevel)],
        ),
      );
      idx++;
    }
    final title = _deriveTitleFromText(
        paragraphs.map((p) => p.text).take(3).toList(growable: false));
    return ParsedBook(title: title, author: 'Unknown', paragraphs: paragraphs);
  }

  String _deriveTitleFromText(List<String> paras) {
    if (paras.isEmpty) return 'Untitled Book';
    final first = paras.first.trim();
    if (first.length > 60) {
      return '${first.substring(0, 57)}...';
    }
    return first.isEmpty ? 'Untitled Book' : first;
  }

  int? _headingLevel(String? tag) {
    if (tag == null) return null;
    if (RegExp(r'h[1-6]').hasMatch(tag)) {
      return int.tryParse(tag.substring(1));
    }
    return null;
  }

  int? _headingFromStyle(String? style) {
    if (style == null) return null;
    final match = RegExp(r'Heading(\d)').firstMatch(style);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  bool _isBold(String? tag) => tag == 'b' || tag == 'strong';
  bool _isItalic(String? tag) => tag == 'i' || tag == 'em';
  bool _isUnderline(String? tag) => tag == 'u';
}
