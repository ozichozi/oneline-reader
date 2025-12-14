import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/document_model/inline_span.dart';
import '../../domain/document_model/metadata.dart';

typedef FootnoteTap = void Function(String footnoteId);
typedef LinkTap = void Function(String url);

class RichTextRenderer {
  const RichTextRenderer();

  InlineSpan buildSpanTree({
    required String text,
    required List<InlineSpanModel> spans,
    required FootnoteTap onFootnoteTap,
    required LinkTap onLinkTap,
  }) {
    if (spans.isEmpty) {
      return TextSpan(text: text, style: _baseStyle());
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    final children = <InlineSpan>[];
    int cursor = 0;
    for (final span in spans) {
      if (span.start > cursor) {
        children.add(TextSpan(
          text: text.substring(cursor, span.start),
          style: _baseStyle(),
        ));
      }
      if (span is StyleSpan) {
        children.add(TextSpan(
          text: text.substring(span.start, span.end),
          style: _styleFor(span.attrs),
        ));
      } else if (span is LinkSpan) {
        children.add(TextSpan(
          text: text.substring(span.start, span.end),
          style: _styleFor(span.attrs ?? const TextStyleAttrs()).copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onLinkTap(span.url),
        ));
      } else if (span is FootnoteRefSpan) {
        children.add(WidgetSpan(
          baseline: TextBaseline.alphabetic,
          alignment: PlaceholderAlignment.aboveBaseline,
          child: GestureDetector(
            onTap: () => onFootnoteTap(span.footnoteId),
            child: Transform.translate(
              offset: const Offset(1, -4),
              child: Text(
                text.substring(span.start, span.end),
                style: _baseStyle().copyWith(
                  fontSize: _baseStyle().fontSize != null
                      ? _baseStyle().fontSize! * 0.7
                      : null,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),
        ));
      }
      cursor = span.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(
        text: text.substring(cursor),
        style: _baseStyle(),
      ));
    }
    return TextSpan(children: children, style: _baseStyle());
  }

  TextStyle _baseStyle() => GoogleFonts.lora(
        fontSize: 18,
        height: 1.4,
      );

  TextStyle _styleFor(TextStyleAttrs attrs) {
    return _baseStyle().copyWith(
          fontWeight: attrs.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: attrs.italic ? FontStyle.italic : FontStyle.normal,
          decoration: TextDecoration.combine([
            if (attrs.underline) TextDecoration.underline,
            if (attrs.strike) TextDecoration.lineThrough,
          ]),
          fontFamily: attrs.code ? 'monospace' : null,
        );
  }
}
