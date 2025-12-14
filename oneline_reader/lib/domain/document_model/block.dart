import 'inline_span.dart';
import 'metadata.dart';

enum BlockType { paragraph, heading, listItem, quote }

abstract class Block {
  final String id;
  final String text;
  final List<InlineSpanModel> spans;
  final BlockMeta meta;
  final BlockType type;

  const Block({
    required this.id,
    required this.text,
    required this.spans,
    required this.meta,
    required this.type,
  });

  Map<String, dynamic> toJson();

  static Block fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? BlockType.paragraph.name;
    final blockType =
        BlockType.values.firstWhere((t) => t.name == typeStr, orElse: () => BlockType.paragraph);
    switch (blockType) {
      case BlockType.heading:
        return HeadingBlock.fromJson(json);
      case BlockType.listItem:
        return ListItemBlock.fromJson(json);
      case BlockType.quote:
        return QuoteBlock.fromJson(json);
      case BlockType.paragraph:
      default:
        return ParagraphBlock.fromJson(json);
    }
  }
}

class ParagraphBlock extends Block {
  ParagraphBlock({
    required super.id,
    required super.text,
    required super.spans,
    BlockMeta? meta,
  }) : super(
          meta: meta ?? const BlockMeta(),
          type: BlockType.paragraph,
        );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'spans': spans.map((s) => s.toJson()).toList(),
        'meta': meta.toJson(),
        'type': type.name,
      };

  factory ParagraphBlock.fromJson(Map<String, dynamic> json) {
    return ParagraphBlock(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      spans: (json['spans'] as List<dynamic>? ?? [])
          .map((s) => InlineSpanModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      meta: BlockMeta.fromJson(Map<String, dynamic>.from(json['meta'] as Map? ?? {})),
    );
  }
}

class HeadingBlock extends Block {
  final int level;

  HeadingBlock({
    required super.id,
    required super.text,
    required super.spans,
    required this.level,
    BlockMeta? meta,
  }) : super(
          meta: (meta ?? const BlockMeta()).copyWith(headingLevel: level),
          type: BlockType.heading,
        );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'spans': spans.map((s) => s.toJson()).toList(),
        'meta': meta.toJson(),
        'type': type.name,
        'level': level,
      };

  factory HeadingBlock.fromJson(Map<String, dynamic> json) {
    final level = json['level'] as int? ?? 1;
    return HeadingBlock(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      spans: (json['spans'] as List<dynamic>? ?? [])
          .map((s) => InlineSpanModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      level: level,
      meta: BlockMeta.fromJson(Map<String, dynamic>.from(json['meta'] as Map? ?? {})),
    );
  }
}

class ListItemBlock extends Block {
  ListItemBlock({
    required super.id,
    required super.text,
    required super.spans,
    BlockMeta? meta,
  }) : super(
          meta: meta ?? const BlockMeta(),
          type: BlockType.listItem,
        );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'spans': spans.map((s) => s.toJson()).toList(),
        'meta': meta.toJson(),
        'type': type.name,
      };

  factory ListItemBlock.fromJson(Map<String, dynamic> json) {
    return ListItemBlock(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      spans: (json['spans'] as List<dynamic>? ?? [])
          .map((s) => InlineSpanModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      meta: BlockMeta.fromJson(Map<String, dynamic>.from(json['meta'] as Map? ?? {})),
    );
  }
}

class QuoteBlock extends Block {
  QuoteBlock({
    required super.id,
    required super.text,
    required super.spans,
    BlockMeta? meta,
  }) : super(
          meta: meta ?? const BlockMeta(),
          type: BlockType.quote,
        );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'spans': spans.map((s) => s.toJson()).toList(),
        'meta': meta.toJson(),
        'type': type.name,
      };

  factory QuoteBlock.fromJson(Map<String, dynamic> json) {
    return QuoteBlock(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      spans: (json['spans'] as List<dynamic>? ?? [])
          .map((s) => InlineSpanModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      meta: BlockMeta.fromJson(Map<String, dynamic>.from(json['meta'] as Map? ?? {})),
    );
  }
}
