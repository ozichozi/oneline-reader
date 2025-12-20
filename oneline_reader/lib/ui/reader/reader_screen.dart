import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/book.dart';
import '../../models/content_unit.dart';
import '../../models/reading_state.dart';
import '../../models/styled_text.dart';
import '../../providers.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late Future<_ReaderData> _loadFuture;
  PageController? _pageController;
  List<ContentUnit> _displayUnits = const [];
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Future<_ReaderData> _loadData() async {
    final repo = ref.read(libraryRepositoryProvider);
    final units = await repo.loadContentUnits(widget.book.id);
    final states = await repo.loadStates();
    final existing = states.firstWhere(
      (s) => s.bookId == widget.book.id,
      orElse: () => repo.createInitialState(widget.book.id),
    );
    return _ReaderData(units: units, state: existing);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return FutureBuilder<_ReaderData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        if (data.units.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: const Center(child: Text('No content to display')),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_displayUnits.isEmpty) {
                  final allowedHeight = constraints.maxHeight * 0.6;
                  _displayUnits = _expandUnits(
                    data.units,
                    fontScale,
                    constraints.maxWidth - 48, // padding
                    allowedHeight - 24, // breathing room inside 60% box
                  );
                  final total = _displayUnits.length;
                  final initial =
                      data.state.currentUnitIndex.clamp(0, total - 1);
                  _pageController ??= PageController(initialPage: initial);
                }
                final controller =
                    _pageController ?? PageController(initialPage: 0);
                final total = _displayUnits.length;

                return Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      child: PageView.builder(
                        controller: controller,
                        scrollDirection: Axis.vertical,
                        physics: const PageScrollPhysics(),
                        itemCount: total,
                        onPageChanged: (index) =>
                            _onPageChanged(index, total, fontScale, themeMode),
                        itemBuilder: (context, index) {
                          return _ReaderPage(
                            unit: _displayUnits[index],
                            fontScale: fontScale,
                            maxHeight: constraints.maxHeight * 0.6,
                          );
                        },
                      ),
                    ),
                    if (_controlsVisible) _buildTopBar(context, themeMode),
                    if (_controlsVisible)
                      _buildBottomBar(
                          context, fontScale, total, controller),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeMode themeMode) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : themeMode == ThemeMode.light
                          ? Icons.light_mode
                          : Icons.brightness_auto,
                ),
                onPressed: () {
                  final next = themeMode == ThemeMode.light
                      ? ThemeMode.dark
                      : themeMode == ThemeMode.dark
                          ? ThemeMode.system
                          : ThemeMode.light;
                  ref.read(themeControllerProvider.notifier).setTheme(next);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, double fontScale, int totalUnits,
      PageController controller) {
    final currentIndex = controller.hasClients
        ? (controller.page?.round() ?? controller.initialPage)
        : controller.initialPage;
    final progress =
        ((currentIndex + 1) / totalUnits * 100).clamp(0, 100).toStringAsFixed(0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (currentIndex + 1) / totalUnits,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$progress%'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.text_fields),
                  Expanded(
                    child: Slider(
                      value: fontScale.clamp(0.8, 1.6),
                      min: 0.8,
                      max: 1.6,
                      divisions: 4,
                      label: fontScale.toStringAsFixed(1),
                      onChanged: (value) {
                        ref.read(fontScaleProvider.notifier).setScale(value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPageChanged(
      int index, int totalUnits, double fontScale, ThemeMode themeMode) async {
    _startHideTimer();
    final state = ReadingState(
      bookId: widget.book.id,
      currentUnitIndex: index,
      theme: _mapTheme(themeMode),
      fontScale: fontScale,
      lastOpenedAt: DateTime.now(),
    );
    await ref.read(readingStatesProvider.notifier).upsert(state);
  }

  AppThemeMode _mapTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }

  List<ContentUnit> _expandUnits(
    List<ContentUnit> baseUnits,
    double fontScale,
    double maxWidth,
    double maxHeight,
  ) {
    final result = <ContentUnit>[];
    int index = 0;
    for (final unit in baseUnits) {
      if (unit.type == ContentUnitType.emptyParagraphBreak) {
        result.add(unit.copyWith(index: index));
        index++;
        continue;
      }
      final splits = _splitUnit(unit, fontScale, maxWidth, maxHeight);
      for (final split in splits) {
        result.add(split.copyWith(index: index));
        index++;
      }
    }
    return result;
  }

  List<ContentUnit> _splitUnit(
    ContentUnit unit,
    double fontScale,
    double maxWidth,
    double maxHeight,
  ) {
    final tokens = _tokenize(unit.segments);
    if (tokens.isEmpty) return [unit];

    // Rough capacity estimate based on area and font scale; keeps compute light to avoid crashes.
    final approxCharsPerLine = (maxWidth / (10 * fontScale)).clamp(20, 120).toInt();
    final approxLines =
        (maxHeight / (20 * fontScale)).clamp(4, 40).toInt();
    final maxChars = (approxCharsPerLine * approxLines).clamp(80, 1200);

    final pages = <List<_Token>>[];
    var current = <_Token>[];
    var currentChars = 0;

    void pushCurrent({bool addEllipsis = false, StyledSegment? style}) {
      if (current.isEmpty) return;
      if (addEllipsis && style != null) {
        current.add(_ellipsisToken(style));
      }
      pages.add(current);
      current = [];
      currentChars = 0;
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final tokenLen = token.text.length;
      final isEnd = _isSentenceEndToken(token);
      final hasMore = i < tokens.length - 1;

      // If adding this token would exceed capacity, break page.
      if (currentChars + tokenLen > maxChars && current.isNotEmpty) {
        pushCurrent(addEllipsis: true, style: _styleFor(current.last));
      }

      current.add(token);
      currentChars += tokenLen;

      if (isEnd && hasMore) {
        pushCurrent();
      }
    }
    if (current.isNotEmpty) {
      pages.add(current);
    }

    return pages.asMap().entries.map((entry) {
      final pageSegments = _mergeTokens(entry.value);
      return ContentUnit(
        id: '${unit.id}_${entry.key}',
        bookId: unit.bookId,
        index: unit.index,
        type: ContentUnitType.sentence,
        segments: pageSegments,
        paragraphId: unit.paragraphId,
      );
    }).toList();
  }

  List<_Token> _tokenize(List<StyledSegment> segments) {
    final rawTokens = <_Token>[];
    final regex = RegExp(r'\s+|\S+');
    for (final seg in segments) {
      for (final match in regex.allMatches(seg.text)) {
        final part = match.group(0);
        if (part == null || part.isEmpty) continue;
        rawTokens.add(_Token(part, seg));
      }
    }

    // Merge closing-quote tokens into the previous token to keep sentence endings intact.
    final tokens = <_Token>[];
    for (final token in rawTokens) {
      final trimmed = token.text.trim();
      final isClosingOnly = _isClosingQuoteText(trimmed);
      if (isClosingOnly && tokens.isNotEmpty) {
        final last = tokens.removeLast();
        tokens.add(_Token('${last.text}${token.text}', last.style));
        continue;
      }
      tokens.add(token);
    }

    return tokens;
  }

  List<StyledSegment> _mergeTokens(List<_Token> tokens) {
    final merged = <StyledSegment>[];
    StyledSegment? current;
    final buffer = StringBuffer();

    void flush() {
      final seg = current;
      if (seg != null) {
        merged.add(seg.copyWith(text: buffer.toString()));
        buffer.clear();
      }
    }

    for (final token in tokens) {
      final seg = current;
      if (seg == null || !_sameStyle(seg, token.style)) {
        flush();
        current = token.style.copyWith();
      }
      buffer.write(token.text);
    }
    flush();
    return merged;
  }

  bool _sameStyle(StyledSegment a, StyledSegment b) {
    return a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.headingLevel == b.headingLevel;
  }

  bool _isSentenceEndToken(_Token token) {
    String trimmed = token.text.trimRight();
    while (trimmed.isNotEmpty &&
        ['"', "'", '”', '’', ')', ']', '}'].contains(trimmed.characters.last)) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return false;
    final last = trimmed.characters.last;
    return last == '.' || last == '!' || last == '?';
  }

  StyledSegment _styleFor(_Token token) => token.style;

  _Token _ellipsisToken(StyledSegment style) {
    return _Token(' ... ', style);
  }

  bool _isClosingQuoteText(String text) {
    if (text.isEmpty) return false;
    const closers = {'"', "'", '”', '’', ')', ']', '}'};
    for (final ch in text.characters) {
      if (!closers.contains(ch)) return false;
    }
    return true;
  }
}

class _ReaderPage extends StatelessWidget {
  const _ReaderPage({
    required this.unit,
    required this.fontScale,
    required this.maxHeight,
  });

  final ContentUnit unit;
  final double fontScale;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (unit.type == ContentUnitType.emptyParagraphBreak) {
      return const Center(child: SizedBox.shrink());
    }
    final baseSize = 20.0 * fontScale;
    final spans = unit.segments.map((s) {
      final headingMultiplier = (s.headingLevel != null)
          ? (1.2 + (6 - s.headingLevel!).clamp(0, 5) * 0.05)
          : 1.0;
      final fontSize = baseSize * headingMultiplier;
      return TextSpan(
        text: s.text,
        style: GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
          decoration:
              s.underline ? TextDecoration.underline : TextDecoration.none,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final allowedHeight =
            maxHeight.clamp(0, constraints.maxHeight).toDouble();
        return Center(
          child: SizedBox(
            height: allowedHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(children: spans),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderData {
  final List<ContentUnit> units;
  final ReadingState state;

  _ReaderData({required this.units, required this.state});
}

extension on ContentUnit {
  ContentUnit copyWith({
    int? index,
  }) {
    return ContentUnit(
      id: id,
      bookId: bookId,
      index: index ?? this.index,
      type: type,
      segments: segments,
      paragraphId: paragraphId,
    );
  }
}

class _Token {
  final String text;
  final StyledSegment style;
  _Token(this.text, this.style);
}
