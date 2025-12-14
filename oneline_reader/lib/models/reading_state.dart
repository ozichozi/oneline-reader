enum AppThemeMode { light, dark, system }
enum ReadingPageMode { sentence, paragraph }

class ReadingState {
  final String bookId;
  final int currentUnitIndex;
  final String? blockId;
  final int? charOffset;
  final ReadingPageMode pageMode;
  final AppThemeMode theme;
  final double fontScale;
  final DateTime lastOpenedAt;

  const ReadingState({
    required this.bookId,
    required this.currentUnitIndex,
    this.blockId,
    this.charOffset,
    this.pageMode = ReadingPageMode.sentence,
    required this.theme,
    required this.fontScale,
    required this.lastOpenedAt,
  });

  ReadingState copyWith({
    int? currentUnitIndex,
    String? blockId,
    int? charOffset,
    ReadingPageMode? pageMode,
    AppThemeMode? theme,
    double? fontScale,
    DateTime? lastOpenedAt,
  }) {
    return ReadingState(
      bookId: bookId,
      currentUnitIndex: currentUnitIndex ?? this.currentUnitIndex,
      blockId: blockId ?? this.blockId,
      charOffset: charOffset ?? this.charOffset,
      pageMode: pageMode ?? this.pageMode,
      theme: theme ?? this.theme,
      fontScale: fontScale ?? this.fontScale,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'currentUnitIndex': currentUnitIndex,
        'blockId': blockId,
        'charOffset': charOffset,
        'pageMode': pageMode.name,
        'theme': theme.name,
        'fontScale': fontScale,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };

  factory ReadingState.fromJson(Map<String, dynamic> json) => ReadingState(
        bookId: json['bookId'] as String,
        currentUnitIndex: json['currentUnitIndex'] as int? ?? 0,
        blockId: json['blockId'] as String?,
        charOffset: json['charOffset'] as int?,
        pageMode: ReadingPageMode.values.firstWhere(
          (m) => m.name == (json['pageMode'] as String? ?? 'sentence'),
          orElse: () => ReadingPageMode.sentence,
        ),
        theme: AppThemeMode.values.firstWhere(
          (m) => m.name == (json['theme'] as String? ?? 'system'),
          orElse: () => AppThemeMode.system,
        ),
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      );
}
