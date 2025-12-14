import 'package:flutter_test/flutter_test.dart';

import 'package:oneline_reader/domain/document_model/block.dart';
import 'package:oneline_reader/domain/document_model/inline_span.dart';
import 'package:oneline_reader/domain/document_model/metadata.dart';
import 'package:oneline_reader/domain/document_model/slicing.dart';

void main() {
  test('sliceParagraph remaps spans correctly', () {
    final block = ParagraphBlock(
      id: 'p1',
      text: 'Hello world',
      spans: [
        StyleSpan(
          start: 0,
          end: 5,
          attrs: const TextStyleAttrs(bold: true),
        ),
        FootnoteRefSpan(start: 6, end: 7, footnoteId: 'fn1', label: '1'),
      ],
      meta: const BlockMeta(),
    );

    final slice = sliceParagraph(block, 0, 7);
    expect(slice.text, 'Hello w');
    expect(slice.spans.length, 2);
    final bold = slice.spans.firstWhere((s) => s is StyleSpan) as StyleSpan;
    expect(bold.start, 0);
    expect(bold.end, 5);
    final foot = slice.spans.firstWhere((s) => s is FootnoteRefSpan)
        as FootnoteRefSpan;
    expect(foot.start, 6);
    expect(foot.end, 7);
  });
}
