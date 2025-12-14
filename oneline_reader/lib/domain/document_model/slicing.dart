import 'block.dart';
import 'inline_span.dart';

class SliceResult {
  final String text;
  final List<InlineSpanModel> spans;
  final String blockId;
  final int start;
  final int end;

  const SliceResult({
    required this.text,
    required this.spans,
    required this.blockId,
    required this.start,
    required this.end,
  });
}

/// Slice a Paragraph/Heading block and remap spans to the sliced range.
SliceResult sliceParagraph(Block block, int start, int end) {
  if (start < 0 || end < 0 || end < start) {
    throw ArgumentError('Invalid slice range: ($start, $end)');
  }
  final safeStart = start.clamp(0, block.text.length);
  final safeEnd = end.clamp(0, block.text.length);
  final slicedText = block.text.substring(safeStart, safeEnd);
  final slicedSpans = <InlineSpanModel>[];
  for (final span in block.spans) {
    if (span.end <= safeStart || span.start >= safeEnd) {
      continue;
    }
    final newStart = (span.start - safeStart).clamp(0, slicedText.length);
    final newEnd = (span.end - safeStart).clamp(0, slicedText.length);
    if (newEnd <= newStart) continue;

    if (span is StyleSpan) {
      slicedSpans.add(StyleSpan(
        start: newStart,
        end: newEnd,
        attrs: span.attrs,
      ));
    } else if (span is LinkSpan) {
      slicedSpans.add(LinkSpan(
        start: newStart,
        end: newEnd,
        url: span.url,
        attrs: span.attrs,
      ));
    } else if (span is FootnoteRefSpan) {
      slicedSpans.add(FootnoteRefSpan(
        start: newStart,
        end: newEnd,
        footnoteId: span.footnoteId,
        label: span.label,
      ));
    }
  }
  return SliceResult(
    text: slicedText,
    spans: slicedSpans,
    blockId: block.id,
    start: safeStart,
    end: safeEnd,
  );
}
