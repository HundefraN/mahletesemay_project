import 'package:flutter/material.dart';
import '../utils/amharic_transliterator.dart';

class TextHighlighter extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const TextHighlighter({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty || text.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }

    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodyMedium!;
    final finalHighlightStyle = highlightStyle ??
        defaultStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );

    final cleanQuery = query.trim().toLowerCase();
    final textLower = text.toLowerCase();

    // Find search terms to match (exact query, normalized, and cross-script variants)
    final Set<String> matchTerms = {cleanQuery};
    if (AmharicTransliterator.containsAmharic(cleanQuery)) {
      matchTerms.add(AmharicTransliterator.normalizeAmharic(cleanQuery));
      final lat = AmharicTransliterator.toLatin(cleanQuery);
      if (lat.isNotEmpty) matchTerms.add(lat);
    } else {
      final amharicVariants = AmharicTransliterator.toAmharicVariants(cleanQuery);
      matchTerms.addAll(amharicVariants);
      for (final v in amharicVariants) {
        matchTerms.add(AmharicTransliterator.normalizeAmharic(v));
      }
    }

    // Locate matching ranges in text
    final List<({int start, int end})> matchRanges = [];
    for (final term in matchTerms) {
      if (term.isEmpty) continue;
      int searchIdx = 0;
      while (searchIdx < textLower.length) {
        final found = textLower.indexOf(term, searchIdx);
        if (found == -1) break;
        final end = found + term.length;
        matchRanges.add((start: found, end: end));
        searchIdx = end;
      }
    }

    if (matchRanges.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }

    // Merge overlapping ranges
    matchRanges.sort((a, b) => a.start.compareTo(b.start));
    final List<({int start, int end})> mergedRanges = [];
    var currentRange = matchRanges.first;

    for (int i = 1; i < matchRanges.length; i++) {
      final nextRange = matchRanges[i];
      if (nextRange.start <= currentRange.end) {
        currentRange = (
          start: currentRange.start,
          end: nextRange.end > currentRange.end ? nextRange.end : currentRange.end,
        );
      } else {
        mergedRanges.add(currentRange);
        currentRange = nextRange;
      }
    }
    mergedRanges.add(currentRange);

    // Build spans
    final List<InlineSpan> spans = [];
    int cursor = 0;

    for (final range in mergedRanges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start), style: defaultStyle));
      }

      final highlightedSnippet = text.substring(range.start, range.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              highlightedSnippet,
              style: finalHighlightStyle.copyWith(color: Colors.white),
            ),
          ),
        ),
      );
      cursor = range.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: defaultStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
