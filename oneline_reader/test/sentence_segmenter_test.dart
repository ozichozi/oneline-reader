import 'package:flutter_test/flutter_test.dart';

import 'package:oneline_reader/reader/pagination/sentence_segmenter.dart';

void main() {
  group('SentenceSegmenter', () {
    final segmenter = SentenceSegmenter();

    test('splits simple sentences', () {
      final text = 'Hello world. This is great!';
      final ranges = segmenter.split(text);
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end), 'Hello world.');
      expect(text.substring(ranges[1].start, ranges[1].end), ' This is great!');
    });

    test('ignores abbreviations', () {
      final text = 'Dr. Smith went home. Then he slept.';
      final ranges = segmenter.split(text);
      expect(ranges.length, 2);
    });

    test('handles ellipsis', () {
      final text = 'Wait... what happened? Done.';
      final ranges = segmenter.split(text);
      expect(ranges.length, 2);
    });

    test('handles decimals', () {
      final text = 'Value is 3.14. Next sentence.';
      final ranges = segmenter.split(text);
      expect(ranges.length, 2);
    });
  });
}
