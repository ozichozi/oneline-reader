import 'block.dart';
import 'footnote.dart';
import 'metadata.dart';

/// Canonical reflowable document representation used across import/render/pagination.
class Document {
  final String docId;
  final String title;
  final String? author;
  final List<Block> blocks;
  final Map<String, Footnote> footnotes;
  final DocumentMeta meta;

  const Document({
    required this.docId,
    required this.title,
    required this.blocks,
    required this.meta,
    this.author,
    this.footnotes = const {},
  });

  Document copyWith({
    String? title,
    String? author,
    List<Block>? blocks,
    Map<String, Footnote>? footnotes,
    DocumentMeta? meta,
  }) {
    return Document(
      docId: docId,
      title: title ?? this.title,
      author: author ?? this.author,
      blocks: blocks ?? this.blocks,
      footnotes: footnotes ?? this.footnotes,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toJson() => {
        'docId': docId,
        'title': title,
        'author': author,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'footnotes':
            footnotes.map((key, value) => MapEntry(key, value.toJson())),
        'meta': meta.toJson(),
      };

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      docId: json['docId'] as String,
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .map((b) => Block.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      footnotes: (json['footnotes'] as Map<String, dynamic>? ?? {})
          .map((key, value) =>
              MapEntry(key, Footnote.fromJson(Map<String, dynamic>.from(value)))),
      meta: DocumentMeta.fromJson(
          Map<String, dynamic>.from(json['meta'] as Map? ?? {})),
    );
  }
}
