import 'package:flutter/material.dart';

/// A widget that displays text with highlighted search matches
class HighlightedText extends StatelessWidget {
  final String text;
  final String? searchQuery;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightedText({
    super.key,
    required this.text,
    this.searchQuery,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final query = searchQuery!.toLowerCase();
    final textLower = text.toLowerCase();

    if (!textLower.contains(query)) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = textLower.indexOf(query, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match (preserve original case)
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle ??
              TextStyle(
                backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.3),
                fontWeight: FontWeight.w600,
              ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
