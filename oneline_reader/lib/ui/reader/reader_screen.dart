import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/document_model/document.dart';
import '../../domain/document_model/footnote.dart';
import '../../domain/document_model/inline_span.dart';
import '../../reader/pagination/page_ref.dart';
import '../../reader/pagination/sentence_segmenter.dart';
import '../../reader/rendering/rich_text_renderer.dart';
import '../../models/book.dart';
import '../../models/content_unit.dart';
import '../../models/reading_state.dart';
import '../../models/styled_text.dart';
import '../../providers.dart';
import '../../utils/app_logger.dart';
import '../../services/storage/local_storage.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late Future<_ReaderData> _loadFuture;
  final SentenceSegmenter _segmenter = SentenceSegmenter();
  final RichTextRenderer _renderer = const RichTextRenderer();
  final AppLogger _log = const AppLogger('ReaderScreen');

  PageController? _pageController;
  List<PageRef> _pages = const [];
  List<ContentUnit> _legacyUnits = const [];
  PageMode _mode = PageMode.sentence;
  Document? _document;
  double? _progressDragValue;

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
    _pageController?.removeListener(_onPageScrolled);
    _pageController?.dispose();
    super.dispose();
  }

  Future<_ReaderData> _loadData() async {
    final repo = ref.read(libraryRepositoryProvider);
    final doc = await repo.loadDocument(widget.book.id);
    final units = doc == null
        ? await repo.loadContentUnits(widget.book.id)
        : <ContentUnit>[];
    final states = await repo.loadStates();
    final existing = states.firstWhere(
      (s) => s.bookId == widget.book.id,
      orElse: () => repo.createInitialState(widget.book.id),
    );
    final mode = existing.pageMode == ReadingPageMode.paragraph
        ? PageMode.paragraph
        : PageMode.sentence;
    final pages = doc != null
        ? paginateDocument(document: doc, segmenter: _segmenter, mode: mode)
        : <PageRef>[];
    return _ReaderData(
      document: doc,
      pages: pages,
      legacyUnits: units,
      state: existing,
      mode: mode,
    );
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

  void _attachController(PageController controller) {
    controller.removeListener(_onPageScrolled);
    controller.addListener(_onPageScrolled);
  }

  void _onPageScrolled() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return FutureBuilder<_ReaderData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        if (_pageController == null) {
          _bootstrapState(data);
        }

        if (_document == null && _legacyUnits.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: const Center(child: Text('No content to display')),
          );
        }

        final total = _document != null ? _pages.length : _legacyUnits.length;
        final controller = _pageController!;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                            _onPageChanged(index, fontScale, themeMode),
                        itemBuilder: (context, index) {
                          if (_document != null) {
                            final page = _pages[index];
                            final attachedFootnotes = _footnotesFor(page);
                            return _DocPage(
                              page: page,
                              mode: _mode,
                              renderer: _renderer,
                              onFootnoteTap: (footnoteId) =>
                                  _showFootnote(context, footnoteId),
                              onLinkTap: (url) {
                                _log.info('Link tapped', context: {'url': url});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Open link: $url')),
                                );
                              },
                              footnotes: attachedFootnotes,
                              maxHeight: constraints.maxHeight * 0.75,
                            );
                          }
                          return _LegacyReaderPage(
                            unit: _legacyUnits[index],
                            fontScale: fontScale,
                            maxHeight: constraints.maxHeight * 0.6,
                          );
                        },
                      ),
                    ),
                    if (_controlsVisible) _buildTopBar(context, themeMode),
                    if (_controlsVisible)
                      _buildBottomBar(
                        context: context,
                        fontScale: fontScale,
                        totalUnits: total,
                        controller: controller,
                        showFallback:
                            _document?.meta.nativePdfFallback == true &&
                            _document != null,
                        originalPath: _document?.meta.originalPath,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _bootstrapState(_ReaderData data) {
    _document = data.document;
    _mode = data.mode;
    if (_document != null) {
      _pages = data.pages ?? const [];
      final initial = _initialDocPageIndex(data.state, _pages);
      _pageController = PageController(initialPage: initial);
      _attachController(_pageController!);
    } else {
      _legacyUnits = _expandUnits(
        data.legacyUnits,
        data.state.fontScale,
        400,
        600,
      );
      final initial = data.state.currentUnitIndex.clamp(
        0,
        _legacyUnits.length - 1,
      );
      _pageController = PageController(initialPage: initial);
      _attachController(_pageController!);
    }
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
              if (_document != null)
                ToggleButtons(
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    minWidth: 60,
                  ),
                  isSelected: [
                    _mode == PageMode.sentence,
                    _mode == PageMode.paragraph,
                  ],
                  onPressed: (idx) {
                    final target = idx == 0
                        ? PageMode.sentence
                        : PageMode.paragraph;
                    _switchMode(target);
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Sentence'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Paragraph'),
                    ),
                  ],
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

  Widget _buildBottomBar({
    required BuildContext context,
    required double fontScale,
    required int totalUnits,
    required PageController controller,
    bool showFallback = false,
    String? originalPath,
  }) {
    final hasPages = totalUnits > 0;
    final safeTotal = hasPages ? totalUnits : 1;
    final maxIndex = (safeTotal - 1).toDouble();
    final pagePosition = _progressDragValue ??
        (controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble());
    final clampedIndex = maxIndex > 0
        ? pagePosition.clamp(0.0, maxIndex)
        : 0.0;
    final progress = hasPages
        ? ((clampedIndex + 1) / safeTotal * 100)
            .clamp(0, 100)
            .toStringAsFixed(0)
        : '0';

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
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: SliderComponentShape.noThumb,
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: clampedIndex,
                        min: 0,
                        max: maxIndex,
                        divisions: safeTotal > 1 ? safeTotal - 1 : null,
                        label: '$progress%',
                        onChanged: safeTotal > 1
                            ? (value) {
                                setState(() {
                                  _progressDragValue = value;
                                });
                              }
                            : null,
                        onChangeEnd: safeTotal > 1
                            ? (value) {
                                final target =
                                    value.round().clamp(0, safeTotal - 1);
                                controller.animateToPage(
                                  target,
                                  duration:
                                      const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                );
                                setState(() {
                                  _progressDragValue = null;
                                });
                              }
                            : null,
                      ),
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
              if (showFallback && originalPath != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PDF shown in placeholder. Open original file: $originalPath',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openOriginalFile(context, originalPath),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPageChanged(
    int index,
    double fontScale,
    ThemeMode themeMode,
  ) async {
    _startHideTimer();
    setState(() {
      _progressDragValue = null;
    });
    final state = _document != null
        ? ReadingState(
            bookId: widget.book.id,
            currentUnitIndex: index,
            blockId: _pages[index].blockId,
            charOffset: _pages[index].start,
            pageMode: _mode == PageMode.paragraph
                ? ReadingPageMode.paragraph
                : ReadingPageMode.sentence,
            theme: _mapTheme(themeMode),
            fontScale: fontScale,
            lastOpenedAt: DateTime.now(),
          )
        : ReadingState(
            bookId: widget.book.id,
            currentUnitIndex: index,
            theme: _mapTheme(themeMode),
            fontScale: fontScale,
            lastOpenedAt: DateTime.now(),
          );
    await ref.read(readingStatesProvider.notifier).upsert(state);
  }

  void _switchMode(PageMode target) {
    if (_document == null || target == _mode) return;
    final currentIndex = _pageController?.page?.round() ?? 0;
    final currentPage = currentIndex >= 0 && currentIndex < _pages.length
        ? _pages[currentIndex]
        : null;
    final newPages = paginateDocument(
      document: _document!,
      segmenter: _segmenter,
      mode: target,
    );
    int newIndex = 0;
    if (currentPage != null) {
      newIndex = _findPageIndex(
        newPages,
        currentPage.blockId,
        currentPage.start,
      );
    }
    _log.info(
      'Switching mode',
      context: {
        'from': _mode.name,
        'to': target.name,
        'pages': newPages.length,
        'newIndex': newIndex,
      },
    );
    setState(() {
      _mode = target;
      _pages = newPages;
      _pageController = PageController(initialPage: newIndex);
      _attachController(_pageController!);
    });
  }

  int _initialDocPageIndex(ReadingState state, List<PageRef> pages) {
    if (pages.isEmpty) return 0;
    if (state.blockId != null) {
      final idx = _findPageIndex(pages, state.blockId!, state.charOffset ?? 0);
      if (idx >= 0) return idx;
    }
    return state.currentUnitIndex.clamp(0, pages.length - 1);
  }

  int _findPageIndex(List<PageRef> pages, String blockId, int charOffset) {
    final idx = pages.indexWhere(
      (p) =>
          p.blockId == blockId && charOffset >= p.start && charOffset < p.end,
    );
    return idx >= 0 ? idx : 0;
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
    final approxCharsPerLine = (maxWidth / (10 * fontScale))
        .clamp(20, 120)
        .toInt();
    final approxLines = (maxHeight / (20 * fontScale)).clamp(4, 40).toInt();
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
        ['"', '\'', ')', ']', '}'].contains(trimmed.characters.last)) {
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
    const closers = {'"', '\'', ')', ']', '}'};
    for (final ch in text.characters) {
      if (!closers.contains(ch)) return false;
    }
    return true;
  }

  List<Footnote> _footnotesFor(PageRef page) {
    final doc = _document;
    if (doc == null) return const [];
    final ids = page.spans
        .whereType<FootnoteRefSpan>()
        .map((s) => s.footnoteId)
        .toSet();
    return ids.map((id) => doc.footnotes[id]).whereNotNull().toList();
  }

  void _showFootnote(BuildContext context, String footnoteId) {
    final doc = _document;
    if (doc == null) return;
    final footnote = doc.footnotes[footnoteId];
    if (footnote == null) return;
    _log.info('Showing footnote', context: {'footnoteId': footnoteId});
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: footnote.blocks.length,
              itemBuilder: (context, index) {
                final block = footnote.blocks[index];
                final span = _renderer.buildSpanTree(
                  text: block.text,
                  spans: block.spans,
                  onFootnoteTap: (_) {},
                  onLinkTap: (_) {},
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RichText(text: span),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openOriginalFile(BuildContext context, String path) async {
    final success = await LocalStorage.instance.openExternally(path);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open original file on this device.'),
        ),
      );
    }
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
}

class _DocPage extends StatelessWidget {
  const _DocPage({
    required this.page,
    required this.mode,
    required this.renderer,
    required this.onFootnoteTap,
    required this.onLinkTap,
    required this.footnotes,
    required this.maxHeight,
  });

  final PageRef page;
  final PageMode mode;
  final RichTextRenderer renderer;
  final FootnoteTap onFootnoteTap;
  final LinkTap onLinkTap;
  final List<Footnote> footnotes;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final spanTree = renderer.buildSpanTree(
      text: page.text,
      spans: page.spans,
      onFootnoteTap: onFootnoteTap,
      onLinkTap: onLinkTap,
    );
    return Center(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(textAlign: TextAlign.center, text: spanTree),
              if (footnotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: footnotes
                      .map(
                        (f) => ActionChip(
                          label: Text('Footnote ${f.label}'),
                          onPressed: () => onFootnoteTap(f.id),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyReaderPage extends StatelessWidget {
  const _LegacyReaderPage({
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
      final baseStyle = TextStyle(
        fontSize: fontSize,
        fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
        decoration:
            s.underline ? TextDecoration.underline : TextDecoration.none,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurface,
      );
      return TextSpan(
        text: s.text,
        style: GoogleFonts.ebGaramond(textStyle: baseStyle),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final allowedHeight = maxHeight
            .clamp(0, constraints.maxHeight)
            .toDouble();
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
  final Document? document;
  final List<PageRef>? pages;
  final List<ContentUnit> legacyUnits;
  final ReadingState state;
  final PageMode mode;

  const _ReaderData({
    required this.document,
    required this.pages,
    required this.legacyUnits,
    required this.state,
    required this.mode,
  });
}

extension on ContentUnit {
  ContentUnit copyWith({int? index}) {
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
