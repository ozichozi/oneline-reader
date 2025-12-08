import '../../models/content_unit.dart';
import '../../models/styled_text.dart';

class SentenceTokenizer {
  SentenceTokenizer();

  static final _abbreviationPattern = RegExp(
    r'^(?:Mr|Mrs|Ms|Miss|Mx|Dr|Prof|Sir|Madam|Mme|Mlle|Sr|Jr|Fr|Rev|Hon|Pres|Gov|Sen|Rep|Amb|Supt|Det|Col|Gen|Capt|Cmdr|Lt|Maj|Sgt|Cpl|Pvt|Brig|Ph\.?D|M\.?D|M\.?B\.?A|B\.?A|B\.?S|M\.?S|D\.?D\.?S|D\.?O|LL\.?D|J\.?D|Esq|CPA|RN|DVM|Ed\.?D|Psy\.?D|etc|et al|i\.?e|e\.?g|cf|viz|vs|v|ibid|op\. cit|loc\. cit|q\.v|N\.B|Co|Corp|Inc|Ltd|LLC|LLP|Bros|a\.m|p\.m|A\.M|P\.M|St|Ft|U\.S|U\.K|E\.U|U\.N|A\.D|B\.C|B\.C\.E|C\.E)$',
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
      // paragraph break
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

    // Heading rule: line starts with capital/digit and followed by blank line.
    final lines = paragraph.split('\n');
    var offset = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nextBlank = (i + 1 < lines.length) && lines[i + 1].trim().isEmpty;
      final trimmedLine = line.trimLeft();
      final isHeadingLine =
          trimmedLine.isNotEmpty && RegExp(r'^[A-Z0-9]').hasMatch(trimmedLine);
      if (isHeadingLine && nextBlank) {
        boundaries.add(offset + line.length);
      }
      offset += line.length + 1; // include newline char
    }

    final matches = RegExp("[.!?]+[\"')\\]]*").allMatches(paragraph);
    for (final match in matches) {
      final end = match.end;
      final after = paragraph.substring(end);
      final prevToken = _previousToken(paragraph, match.start);
      final nextStartChar = _firstNonSpace(after);

      if (prevToken != null) {
        final core = prevToken.replaceAll(RegExp("[)\"']+\\\$"), '');
        if (_abbreviationPattern.hasMatch(core)) continue;
        if (RegExp(r'(?:[A-Z]\.){1,3}$').hasMatch(core)) continue;
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

  bool _isUpper(String ch) =>
      ch.toUpperCase() == ch && RegExp(r'[A-Z]').hasMatch(ch);

  String? _firstNonSpace(String text) {
    for (final codeUnit in text.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      if (!RegExp(r'\s').hasMatch(ch)) return ch;
    }
    return null;
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
