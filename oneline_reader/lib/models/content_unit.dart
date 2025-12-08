import 'styled_text.dart';

enum ContentUnitType {
  sentence,
  emptyParagraphBreak,
}

class ContentUnit {
  final String id;
  final String bookId;
  final int index;
  final ContentUnitType type;
  final List<StyledSegment> segments;
  final String? paragraphId;

  const ContentUnit({
    required this.id,
    required this.bookId,
    required this.index,
    required this.type,
    required this.segments,
    this.paragraphId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'index': index,
        'type': type.name,
        'segments': segments.map((s) => s.toJson()).toList(),
        'paragraphId': paragraphId,
      };

  factory ContentUnit.fromJson(Map<String, dynamic> json) => ContentUnit(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        index: json['index'] as int,
        type: ContentUnitType.values.firstWhere(
          (t) => t.name == (json['type'] as String? ?? ''),
          orElse: () => ContentUnitType.sentence,
        ),
        segments: (json['segments'] as List<dynamic>? ?? [])
            .map((s) => StyledSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        paragraphId: json['paragraphId'] as String?,
      );
}
