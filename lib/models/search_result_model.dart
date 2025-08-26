enum MatchType { title, artist, album, lyric }

class SearchResult {
  final dynamic item;
  final MatchType matchType;
  final String? matchSnippet;

  SearchResult({
    required this.item,
    required this.matchType,
    this.matchSnippet,
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