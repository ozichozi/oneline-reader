enum AppThemeMode { light, dark, system }

class ReadingState {
  final String bookId;
  final int currentUnitIndex;
  final AppThemeMode theme;
  final double fontScale;
  final DateTime lastOpenedAt;

  const ReadingState({
    required this.bookId,
    required this.currentUnitIndex,
    required this.theme,
    required this.fontScale,
    required this.lastOpenedAt,
  });

  ReadingState copyWith({
    int? currentUnitIndex,
    AppThemeMode? theme,
    double? fontScale,
    DateTime? lastOpenedAt,
  }) {
    return ReadingState(
      bookId: bookId,
      currentUnitIndex: currentUnitIndex ?? this.currentUnitIndex,
      theme: theme ?? this.theme,
      fontScale: fontScale ?? this.fontScale,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'currentUnitIndex': currentUnitIndex,
        'theme': theme.name,
        'fontScale': fontScale,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };

  factory ReadingState.fromJson(Map<String, dynamic> json) => ReadingState(
        bookId: json['bookId'] as String,
        currentUnitIndex: json['currentUnitIndex'] as int? ?? 0,
        theme: AppThemeMode.values.firstWhere(
          (m) => m.name == (json['theme'] as String? ?? 'system'),
          orElse: () => AppThemeMode.system,
        ),
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      );
}
