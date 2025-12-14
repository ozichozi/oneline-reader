import 'metadata.dart';

abstract class InlineSpanModel {
  final int start;
  final int end;

  InlineSpanModel({required this.start, required this.end});

  Map<String, dynamic> toJson();

  static InlineSpanModel fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? 'style';
    switch (kind) {
      case 'link':
        return LinkSpan.fromJson(json);
      case 'footnote':
        return FootnoteRefSpan.fromJson(json);
      case 'style':
      default:
        return StyleSpan.fromJson(json);
    }
  }
}

class StyleSpan extends InlineSpanModel {
  final TextStyleAttrs attrs;

  StyleSpan({
    required super.start,
    required super.end,
    required this.attrs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'style',
        'start': start,
        'end': end,
        'attrs': attrs.toJson(),
      };

  factory StyleSpan.fromJson(Map<String, dynamic> json) {
    return StyleSpan(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      attrs: TextStyleAttrs.fromJson(
          Map<String, dynamic>.from(json['attrs'] as Map? ?? {})),
    );
  }
}

class LinkSpan extends InlineSpanModel {
  final String url;
  final TextStyleAttrs? attrs;

  LinkSpan({
    required super.start,
    required super.end,
    required this.url,
    this.attrs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'link',
        'start': start,
        'end': end,
        'url': url,
        'attrs': attrs?.toJson(),
      };

  factory LinkSpan.fromJson(Map<String, dynamic> json) {
    return LinkSpan(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      attrs: json['attrs'] == null
          ? null
          : TextStyleAttrs.fromJson(
              Map<String, dynamic>.from(json['attrs'] as Map)),
    );
  }
}

class FootnoteRefSpan extends InlineSpanModel {
  final String footnoteId;
  final String label;

  FootnoteRefSpan({
    required super.start,
    required super.end,
    required this.footnoteId,
    required this.label,
  });

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'footnote',
        'start': start,
        'end': end,
        'footnoteId': footnoteId,
        'label': label,
      };

  factory FootnoteRefSpan.fromJson(Map<String, dynamic> json) {
    return FootnoteRefSpan(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      footnoteId: json['footnoteId'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}
