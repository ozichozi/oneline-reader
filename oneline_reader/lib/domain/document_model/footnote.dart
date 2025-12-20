import 'block.dart';

class Footnote {
  final String id;
  final String label;
  final List<ParagraphBlock> blocks;
  final FootnoteMeta meta;

  const Footnote({
    required this.id,
    required this.label,
    required this.blocks,
    required this.meta,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'meta': meta.toJson(),
  };

  factory Footnote.fromJson(Map<String, dynamic> json) {
    return Footnote(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .map((b) => ParagraphBlock.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      meta: FootnoteMeta.fromJson(
        Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
      ),
    );
  }
}

class FootnoteMeta {
  final String? sourceBlockId;
  final Map<String, dynamic>? extra;

  const FootnoteMeta({this.sourceBlockId, this.extra});

  Map<String, dynamic> toJson() => {
    'sourceBlockId': sourceBlockId,
    'extra': extra,
  };

  factory FootnoteMeta.fromJson(Map<String, dynamic> json) {
    return FootnoteMeta(
      sourceBlockId: json['sourceBlockId'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}
