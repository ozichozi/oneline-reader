class StyledSegment {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final int? headingLevel;

  const StyledSegment({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.headingLevel,
  });

  StyledSegment copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? underline,
    int? headingLevel,
  }) {
    return StyledSegment(
      text: text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      headingLevel: headingLevel ?? this.headingLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'headingLevel': headingLevel,
      };

  factory StyledSegment.fromJson(Map<String, dynamic> json) => StyledSegment(
        text: json['text'] as String? ?? '',
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        underline: json['underline'] as bool? ?? false,
        headingLevel: json['headingLevel'] as int?,
      );
}
