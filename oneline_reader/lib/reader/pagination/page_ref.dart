import 'package:collection/collection.dart';

import '../../domain/document_model/block.dart';
import '../../domain/document_model/document.dart';
import '../../domain/document_model/inline_span.dart';
import '../../domain/document_model/slicing.dart';
import 'sentence_segmenter.dart';

enum PageMode { sentence, paragraph }

class PageRef {
  final String pageId;
  final String blockId;
  final int start;
  final int end;
  final PageMode mode;
  final List<InlineSpanModel> spans;
  final String text;

  const PageRef({
    required this.pageId,
    required this.blockId,
    required this.start,
    required this.end,
    required this.mode,
    required this.spans,
    required this.text,
  });
}

List<PageRef> paginateDocument({
  required Document document,
  required SentenceSegmenter segmenter,
  required PageMode mode,
  int maxSentenceLength = 600,
}) {
  final pages = <PageRef>[];
  for (final block in document.blocks) {
    if (block.type == BlockType.paragraph || block.type == BlockType.heading) {
      if (mode == PageMode.paragraph) {
        pages.add(_buildPage(block, 0, block.text.length, mode));
        continue;
      }
      final ranges = segmenter.split(block.text);
      final bounded = ranges.isNotEmpty ? ranges : [TextRange(0, block.text.length)];
      for (final range in bounded) {
        final slices = _chunkRange(block, range, maxSentenceLength);
        for (final chunk in slices) {
          pages.add(_buildPage(block, chunk.start, chunk.end, mode));
        }
      }
    } else {
      // For non-paragraph blocks, emit as single page.
      pages.add(_buildPage(block, 0, block.text.length, mode));
    }
  }
  return pages;
}

PageRef _buildPage(Block block, int start, int end, PageMode mode) {
  final slice = sliceParagraph(block, start, end);
  final pageId = '${block.id}_${start}_${end}_${mode.name}';
  return PageRef(
    pageId: pageId,
    blockId: block.id,
    start: start,
    end: end,
    mode: mode,
    spans: slice.spans,
    text: slice.text,
  );
}

/// Split a large sentence range into word-bound chunks.
List<TextRange> _chunkRange(Block block, TextRange base, int maxLen) {
  if ((base.end - base.start) <= maxLen) return [base];
  final text = block.text.substring(base.start, base.end);
  final ranges = <TextRange>[];
  int offset = 0;
  while (offset < text.length) {
    final remaining = text.length - offset;
    if (remaining <= maxLen) {
      ranges.add(TextRange(base.start + offset, base.start + text.length));
      break;
    }
    int split = offset + maxLen;
    // try to break at whitespace
    while (split > offset && split < text.length && text[split] != ' ') {
      split--;
    }
    if (split == offset) {
      split = offset + maxLen;
    }
    ranges.add(TextRange(base.start + offset, base.start + split));
    offset = split;
  }
  return ranges;
}

class TextRange {
  final int start;
  final int end;
  const TextRange(this.start, this.end);
}
