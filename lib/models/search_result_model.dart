enum MatchType { title, artist, album, lyric, exercise }

class SearchResult {
  final dynamic item;
  final MatchType matchType;
  final String? matchSnippet;
  final double score;

  SearchResult({
    required this.item,
    required this.matchType,
    this.matchSnippet,
    this.score = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          item.id == other.item.id;

  @override
  int get hashCode => item.id.hashCode;
}