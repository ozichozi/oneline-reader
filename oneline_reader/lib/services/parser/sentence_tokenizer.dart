import '../../models/content_unit.dart';
import '../../models/styled_text.dart';

class SentenceTokenizer {
  SentenceTokenizer();

  static final _abbreviationPattern = RegExp(
    r'^(?:Mr|Mrs|Ms|Miss|Mx|Dr|Prof|Sir|Madam|Mme|Mlle|Sr|Jr|Fr|Rev|Hon|Pres|Gov|Sen|Rep|Amb|Supt|Det|Col|Gen|Capt|Cmdr|Lt|Maj|Sgt|Cpl|Pvt|Brig|Ph\.?D|M\.?D|M\.?B\.?A|B\.?A|B\.?S|M\.?S|D\.?D\.?S|D\.?O|D\.?Min|LL\.?D|J\.?D|Esq|CPA|RN|R\.?N|DVM|Ed\.?D|Psy\.?D|Ala|Ariz|Ark|Calif|Colo|Conn|Del|Fla|Ga|Ida|Ill|Ind|Kan|Ky|La|Md|Mass|Mich|Minn|Miss|Mo|Mont|Nebr|Nev|Okla|Ore|Pa|Tenn|Tex|Va|Wash|Wis|Wyo|St|Ft|a\.?m|p\.?m|A\.M|P\.M|yr|yrs|mo|mos|wk|wks|Co|Corp|Inc|Ltd|LLC|LLP|Bros|etc|et al|i\.?e|e\.?g|cf|viz|vs|v|ibid|op\. cit|loc\. cit|q\.v|N\.B|approx|appt|dept|est|temp|vol|no|fig|al|misc|min|sec|hr|in|ft|yd|mi|cm|mm|kg|mg|lb|oz|pt|qt|gal|deg|U\.S|U\.K|E\.U|U\.N|A\.I|I\.B\.M|A\.T\.&T|R\.H\.I\.P|R\.S\.V\.P|B\.C|A\.D|B\.C\.E|C\.E)$',
    caseSensitive: false,
  );

  List<ContentUnit> buildUnits({
    required String bookId,
    required List<ParagraphInput> paragraphs,
  }) {
    final units = <ContentUnit>[];
    var index = 0;
    for (final paragraph in paragraphs) {
      final sentenceRanges = _splitParagraph(paragraph.text);
      for (final range in sentenceRanges) {
        final segments =
            _sliceSegments(paragraph.segments, range.start, range.end);
        units.add(
          ContentUnit(
            id: '${bookId}_$index',
            bookId: bookId,
            index: index,
            type: ContentUnitType.sentence,
            segments: segments,
            paragraphId: paragraph.id,
          ),
        );
        index++;
      }
      units.add(
        ContentUnit(
          id: '${bookId}_$index',
          bookId: bookId,
          index: index,
          type: ContentUnitType.emptyParagraphBreak,
          segments: const [],
          paragraphId: paragraph.id,
        ),
      );
      index++;
    }
    return units;
  }

  List<_TextRange> _splitParagraph(String paragraph) {
    if (paragraph.trim().isEmpty) return [];
    final boundaries = <int>{};
    int start = 0;

    final matches = RegExp("[.!?]+[\"')\\]]*").allMatches(paragraph);
    for (final match in matches) {
      final end = match.end;
      final after = paragraph.substring(end);
      final prevToken = _previousToken(paragraph, match.start);
      final nextStartChar = _firstNonSpace(after);
      final nextToken = _nextToken(paragraph, end);

      final mergedInitials = _consumeInitialRun(paragraph, match.start);
      final tokenWithPunct =
          _tokenWithPunctuation(paragraph, match.start, end);
      final tokenForCheck = mergedInitials ?? tokenWithPunct ?? prevToken;
      if (tokenForCheck != null && _isAbbreviation(tokenForCheck)) {
        continue;
      }
      if (prevToken != null &&
          nextToken != null &&
          _isInitial(prevToken) &&
          _isInitial(nextToken)) {
        continue;
      }

      final isEllipsis = match.group(0)?.contains('...') ?? false;
      if (isEllipsis && (nextStartChar == null || !_isUpper(nextStartChar))) {
        continue;
      }

      if (nextStartChar != null && !_isUpper(nextStartChar)) {
        continue;
      }

      boundaries.add(end);
    }

    final sorted = boundaries.toList()..sort();
    final ranges = <_TextRange>[];
    for (final end in sorted) {
      if (end > start) {
        ranges.add(_TextRange(start, end));
        start = end;
      }
    }
    if (start < paragraph.length) {
      ranges.add(_TextRange(start, paragraph.length));
    }
    return ranges.where((r) => r.end > r.start).toList();
  }

  List<StyledSegment> _sliceSegments(
    List<StyledSegment> segments,
    int start,
    int end,
  ) {
    final result = <StyledSegment>[];
    int offset = 0;
    for (final segment in segments) {
      final segText = segment.text;
      final segStart = offset;
      final segEnd = offset + segText.length;
      if (segEnd <= start) {
        offset = segEnd;
        continue;
      }
      if (segStart >= end) break;
      final sliceStart = start.clamp(segStart, segEnd) - segStart;
      final sliceEnd = end.clamp(segStart, segEnd) - segStart;
      if (sliceStart < sliceEnd) {
        result.add(
          StyledSegment(
            text: segText.substring(sliceStart, sliceEnd),
            bold: segment.bold,
            italic: segment.italic,
            underline: segment.underline,
            headingLevel: segment.headingLevel,
          ),
        );
      }
      offset = segEnd;
    }
    if (result.isEmpty) {
      final plain = segments.map((s) => s.text).join();
      final safeStart = start.clamp(0, plain.length);
      final safeEnd = end.clamp(0, plain.length);
      result.add(StyledSegment(text: plain.substring(safeStart, safeEnd)));
    }
    return result;
  }

  String? _previousToken(String text, int index) {
    final left = text.substring(0, index).trimRight();
    if (left.isEmpty) return null;
    final tokens = left.split(RegExp(r'\s+'));
    return tokens.isEmpty ? null : tokens.last;
  }

  String? _nextToken(String text, int index) {
    if (index >= text.length) return null;
    final right = text.substring(index).trimLeft();
    if (right.isEmpty) return null;
    final tokens = right.split(RegExp(r'\s+'));
    return tokens.isEmpty ? null : tokens.first;
  }

  bool _isUpper(String ch) =>
      ch.toUpperCase() == ch && RegExp(r'[A-Z]').hasMatch(ch);

  String? _firstNonSpace(String text) {
    for (final codeUnit in text.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      if (!RegExp(r'\s').hasMatch(ch)) return ch;
    }
    return null;
  }

  bool _isAbbreviation(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    final normalized = trimmed
        .replaceAll(RegExp("[)\\]\"'\\u2019\\u201d]+\$"), '')
        .replaceAll(RegExp(r'\.+$'), '');
    if (normalized.isEmpty) return false;
    if (_abbreviationPattern.hasMatch(normalized)) return true;
    if (RegExp(r'^(?:[A-Z]\.){1,3}$').hasMatch(trimmed)) return true;
    return false;
  }

  bool _isInitial(String token) {
    return RegExp(r'^[A-Z]\.$').hasMatch(token.trim());
  }

  String? _consumeInitialRun(String paragraph, int boundaryIndex) {
    // Look back for contiguous initials like "F." "H."
    final left = paragraph.substring(0, boundaryIndex);
    final tokens = left.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    final initials = <String>[];
    for (var i = tokens.length - 1; i >= 0 && initials.length < 3; i--) {
      final t = tokens[i];
      if (_isInitial(t)) {
        initials.insert(0, t);
      } else {
        break;
      }
    }
    if (initials.length >= 2) {
      return initials.join(' ');
    }
    return null;
  }

  String? _tokenWithPunctuation(String text, int boundaryStart, int boundaryEnd) {
    int idx = boundaryStart - 1;
    while (idx >= 0 && !RegExp(r'\s').hasMatch(text[idx])) {
      idx--;
    }
    final start = (idx + 1).clamp(0, text.length);
    if (start >= boundaryEnd) return null;
    return text.substring(start, boundaryEnd);
  }
}

class ParagraphInput {
  final String id;
  final String text;
  final List<StyledSegment> segments;

  ParagraphInput({
    required this.id,
    required this.text,
    required this.segments,
  });
}

class _TextRange {
  final int start;
  final int end;
  _TextRange(this.start, this.end);
}
