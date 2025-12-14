import '../../domain/document_model/metadata.dart';
import 'page_ref.dart';

/// English sentence segmenter with heuristics for abbreviations, ellipses, initials, decimals.
class SentenceSegmenter {
  SentenceSegmenter({
    this.abbreviations = _defaultAbbreviations,
  });

  final Set<String> abbreviations;

  List<TextRange> split(String paragraph) {
    if (paragraph.trim().isEmpty) return [];
    final boundaries = <int>{};
    final regex = RegExp("[.!?]+[\"')\\]]*");
    for (final match in regex.allMatches(paragraph)) {
      final end = match.end;
      final prevToken = _previousToken(paragraph, match.start);
      final nextToken = _nextToken(paragraph, end);
      final nextStartChar = _firstNonSpace(paragraph.substring(end));

      final tokenForCheck = _mergeInitials(paragraph, match.start) ??
          _tokenWithPunctuation(paragraph, match.start, end) ??
          prevToken;
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
      if (_looksLikeDecimal(prevToken, nextToken)) continue;
      if (nextStartChar != null && !_isUpper(nextStartChar)) {
        continue;
      }
      boundaries.add(end);
    }
    if (boundaries.isEmpty) {
      return [TextRange(0, paragraph.length)];
    }
    final sorted = boundaries.toList()..sort();
    final ranges = <TextRange>[];
    int start = 0;
    for (final end in sorted) {
      if (end > start) {
        ranges.add(TextRange(start, end));
        start = end;
      }
    }
    if (start < paragraph.length) {
      ranges.add(TextRange(start, paragraph.length));
    }
    return ranges;
  }

  bool _isAbbreviation(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    final normalized = trimmed
        .replaceAll(RegExp("[)\\]\"'\\u2019\\u201d]+\$"), '')
        .replaceAll(RegExp(r'\.+$'), '');
    if (normalized.isEmpty) return false;
    if (abbreviations.contains(normalized.toLowerCase())) return true;
    if (RegExp(r'^(?:[A-Z]\.){1,3}$').hasMatch(trimmed)) return true;
    return false;
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

  String? _firstNonSpace(String text) {
    for (final codeUnit in text.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      if (!RegExp(r'\s').hasMatch(ch)) return ch;
    }
    return null;
  }

  bool _isUpper(String ch) =>
      ch.toUpperCase() == ch && RegExp(r'[A-Z]').hasMatch(ch);

  bool _isInitial(String token) => RegExp(r'^[A-Z]\.$').hasMatch(token.trim());

  bool _looksLikeDecimal(String? prev, String? next) {
    if (prev == null || next == null) return false;
    return RegExp(r'^\d+$').hasMatch(prev) && RegExp(r'^\d').hasMatch(next);
  }

  String? _mergeInitials(String paragraph, int boundaryIndex) {
    final left = paragraph.substring(0, boundaryIndex);
    final tokens =
        left.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
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

const _defaultAbbreviations = <String>{
  'mr',
  'mrs',
  'ms',
  'miss',
  'mx',
  'dr',
  'prof',
  'sir',
  'madam',
  'mme',
  'mlle',
  'sr',
  'jr',
  'fr',
  'rev',
  'hon',
  'pres',
  'gov',
  'sen',
  'rep',
  'amb',
  'supt',
  'det',
  'col',
  'gen',
  'capt',
  'cmdr',
  'lt',
  'maj',
  'sgt',
  'cpl',
  'pvt',
  'brig',
  'phd',
  'ph.d',
  'md',
  'm.d',
  'mba',
  'm.b.a',
  'ba',
  'b.a',
  'bs',
  'b.s',
  'dds',
  'd.d.s',
  'do',
  'd.o',
  'jd',
  'j.d',
  'llc',
  'llp',
  'corp',
  'inc',
  'ltd',
  'bros',
  'etc',
  'st',
  'ft',
  'vs',
  'viz',
  'cf',
  'i.e',
  'e.g',
  'a.m',
  'p.m',
};
