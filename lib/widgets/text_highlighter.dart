import 'package:flutter/material.dart';

class TextHighlighter extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int maxLines;

  const TextHighlighter({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodyMedium!;
    final finalHighlightStyle = highlightStyle ??
        defaultStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );

    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();

    List<InlineSpan> spans = [];
    int start = 0;
    int indexOfHighlight;

    while ((indexOfHighlight = textLower.indexOf(queryLower, start)) != -1) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight), style: defaultStyle));
      }
      final highlightEnd = indexOfHighlight + query.length;
      final highlightedText = text.substring(indexOfHighlight, highlightEnd);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  Color.lerp(theme.colorScheme.secondary, theme.colorScheme.primary, 0.5)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              highlightedText,
              style: finalHighlightStyle.copyWith(color: Colors.white),
            ),
          ),
        ),
      );
      start = highlightEnd;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}