enum DocumentSourceFormat { txt, epub, docx, pdf, mobi, unknown }

class DocumentMeta {
  final DocumentSourceFormat source;
  final String originalPath;
  final DateTime importedAt;
  final String? originalFileName;
  final bool nativePdfFallback;

  const DocumentMeta({
    required this.source,
    required this.originalPath,
    required this.importedAt,
    this.originalFileName,
    this.nativePdfFallback = false,
  });

  DocumentMeta copyWith({
    DocumentSourceFormat? source,
    String? originalPath,
    DateTime? importedAt,
    String? originalFileName,
    bool? nativePdfFallback,
  }) {
    return DocumentMeta(
      source: source ?? this.source,
      originalPath: originalPath ?? this.originalPath,
      importedAt: importedAt ?? this.importedAt,
      originalFileName: originalFileName ?? this.originalFileName,
      nativePdfFallback: nativePdfFallback ?? this.nativePdfFallback,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'originalPath': originalPath,
        'originalFileName': originalFileName,
        'importedAt': importedAt.toIso8601String(),
        'nativePdfFallback': nativePdfFallback,
      };

  factory DocumentMeta.fromJson(Map<String, dynamic> json) {
    final sourceStr = json['source'] as String? ?? DocumentSourceFormat.unknown.name;
    final source = DocumentSourceFormat.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => DocumentSourceFormat.unknown,
    );
    return DocumentMeta(
      source: source,
      originalPath: json['originalPath'] as String? ?? '',
      originalFileName: json['originalFileName'] as String?,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.now(),
      nativePdfFallback: json['nativePdfFallback'] as bool? ?? false,
    );
  }
}

class BlockMeta {
  final int? headingLevel;
  final Map<String, dynamic>? extra;

  const BlockMeta({
    this.headingLevel,
    this.extra,
  });

  BlockMeta copyWith({
    int? headingLevel,
    Map<String, dynamic>? extra,
  }) {
    return BlockMeta(
      headingLevel: headingLevel ?? this.headingLevel,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'headingLevel': headingLevel,
        'extra': extra,
      };

  factory BlockMeta.fromJson(Map<String, dynamic> json) {
    return BlockMeta(
      headingLevel: json['headingLevel'] as int?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

class TextStyleAttrs {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;

  const TextStyleAttrs({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
  });

  TextStyleAttrs copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    bool? code,
  }) {
    return TextStyleAttrs(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      code: code ?? this.code,
    );
  }

  Map<String, dynamic> toJson() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strike': strike,
        'code': code,
      };

  factory TextStyleAttrs.fromJson(Map<String, dynamic> json) {
    return TextStyleAttrs(
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strike: json['strike'] as bool? ?? false,
      code: json['code'] as bool? ?? false,
    );
  }
}
