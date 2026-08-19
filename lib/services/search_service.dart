import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/search_result_model.dart';
import '../models/song_model.dart';
import '../models/vocal_plan_model.dart';
import '../utils/amharic_transliterator.dart';

enum SearchCategory {
  all,
  songs,
  artists,
  albums,
  exercises,
  lyrics,
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // CLIENT-SIDE MULTI-SCRIPT UNIFIED SEARCH
  // ---------------------------------------------------------------------------

  /// Performs high-speed multi-script search across local collections
  List<SearchResult> searchLocal({
    required String query,
    required List<Song> songs,
    required List<Artist> artists,
    required List<Album> albums,
    List<VocalExerciseDay> exercises = const [],
    SearchCategory category = SearchCategory.all,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final isEng = AmharicTransliterator.isEnglish(cleanQuery);
    final queryLower = cleanQuery.toLowerCase();
    final queryNormalized = AmharicTransliterator.normalizeAmharic(queryLower);
    final amharicVariants = isEng ? AmharicTransliterator.toAmharicVariants(cleanQuery) : <String>[];
    final amharicVariantsNorm = amharicVariants.map((v) => AmharicTransliterator.normalizeAmharic(v)).toSet();

    final searchTokens = queryLower.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    final Map<String, ({double score, SearchResult result})> resultsMap = {};

    // 1. Search Songs (Titles & Lyrics)
    if (category == SearchCategory.all || category == SearchCategory.songs || category == SearchCategory.lyrics) {
      for (final song in songs) {
        double score = 0.0;
        MatchType matchType = MatchType.title;
        String matchSnippet = song.artistName;

        final titleLower = song.title.toLowerCase();
        final titleNorm = AmharicTransliterator.normalizeAmharic(titleLower);
        final engTitleLower = song.englishTitle.toLowerCase();

        // Check Song Title (Amharic & English)
        if (titleLower == queryLower || engTitleLower == queryLower || titleNorm == queryNormalized) {
          score += 100.0;
          matchType = MatchType.title;
        } else if (titleNorm.startsWith(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.startsWith(queryLower))) {
          score += 80.0;
          matchType = MatchType.title;
        } else if (titleNorm.contains(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.contains(queryLower))) {
          score += 65.0;
          matchType = MatchType.title;
        } else {
          // Check transliterated variants
          if (isEng) {
            for (final variant in amharicVariantsNorm) {
              if (titleNorm == variant) {
                score += 85.0;
                matchType = MatchType.title;
                break;
              } else if (titleNorm.startsWith(variant)) {
                score += 70.0;
                matchType = MatchType.title;
                break;
              } else if (titleNorm.contains(variant)) {
                score += 55.0;
                matchType = MatchType.title;
                break;
              }
            }
          }
        }

        // Check Artist Name in song
        final artistLower = song.artistName.toLowerCase();
        final artistNorm = AmharicTransliterator.normalizeAmharic(artistLower);
        if (score < 70) {
          if (artistLower == queryLower || artistNorm == queryNormalized) {
            score += 50.0;
            if (matchType == MatchType.title && score < 70) matchType = MatchType.artist;
          } else if (artistNorm.contains(queryNormalized)) {
            score += 35.0;
            if (matchType == MatchType.title && score < 50) matchType = MatchType.artist;
          } else if (isEng) {
            for (final variant in amharicVariantsNorm) {
              if (artistNorm.contains(variant)) {
                score += 35.0;
                matchType = MatchType.artist;
                break;
              }
            }
          }
        }

        // Check Album Title in song
        final albumLower = song.albumTitle.toLowerCase();
        final albumNorm = AmharicTransliterator.normalizeAmharic(albumLower);
        if (score < 50) {
          if (albumLower == queryLower || albumNorm == queryNormalized) {
            score += 40.0;
            matchType = MatchType.album;
          } else if (albumNorm.contains(queryNormalized)) {
            score += 25.0;
            matchType = MatchType.album;
          }
        }

        // Check Keywords Array
        if (score < 40 && song.searchKeywords.isNotEmpty) {
          for (final kw in song.searchKeywords) {
            final kwLower = kw.toLowerCase();
            final kwNorm = AmharicTransliterator.normalizeAmharic(kwLower);
            if (kwLower == queryLower || kwNorm == queryNormalized) {
              score += 35.0;
              break;
            } else if (kwNorm.contains(queryNormalized)) {
              score += 20.0;
              break;
            }
          }
        }

        // Check Lyrics (if lyrics category or still not strongly matched)
        if (category == SearchCategory.lyrics || (category == SearchCategory.all && score < 50)) {
          final lyricsLower = song.lyrics.toLowerCase();
          final lyricsNorm = AmharicTransliterator.normalizeAmharic(lyricsLower);

          int matchIndex = -1;
          int matchLength = cleanQuery.length;

          if (lyricsNorm.contains(queryNormalized)) {
            matchIndex = lyricsNorm.indexOf(queryNormalized);
            score += 30.0;
            matchType = MatchType.lyric;
          } else if (isEng) {
            for (final variant in amharicVariantsNorm) {
              if (lyricsNorm.contains(variant)) {
                matchIndex = lyricsNorm.indexOf(variant);
                matchLength = variant.length;
                score += 25.0;
                matchType = MatchType.lyric;
                break;
              }
            }
          }

          // Token based lyric match
          if (matchIndex == -1) {
            for (final token in searchTokens) {
              if (token.length >= 2 && lyricsLower.contains(token)) {
                matchIndex = lyricsLower.indexOf(token);
                matchLength = token.length;
                score += 15.0;
                matchType = MatchType.lyric;
                break;
              }
            }
          }

          if (matchIndex != -1) {
            final start = (matchIndex - 25).clamp(0, song.lyrics.length);
            final end = (matchIndex + matchLength + 35).clamp(0, song.lyrics.length);
            matchSnippet = '...${song.lyrics.substring(start, end).replaceAll('\n', ' ')}...';
          }
        }

        if (score > 0) {
          final existing = resultsMap[song.id]?.score ?? 0;
          if (score > existing) {
            resultsMap[song.id] = (
              score: score,
              result: SearchResult(
                item: song,
                matchType: matchType,
                matchSnippet: matchSnippet,
                score: score,
              ),
            );
          }
        }
      }
    }

    // 2. Search Artists
    if (category == SearchCategory.all || category == SearchCategory.artists) {
      for (final artist in artists) {
        double score = 0.0;
        final nameLower = artist.name.toLowerCase();
        final nameNorm = AmharicTransliterator.normalizeAmharic(nameLower);
        final engNameLower = artist.englishName.toLowerCase();

        if (nameLower == queryLower || engNameLower == queryLower || nameNorm == queryNormalized) {
          score += 100.0;
        } else if (nameNorm.startsWith(queryNormalized) || (engNameLower.isNotEmpty && engNameLower.startsWith(queryLower))) {
          score += 85.0;
        } else if (nameNorm.contains(queryNormalized) || (engNameLower.isNotEmpty && engNameLower.contains(queryLower))) {
          score += 70.0;
        } else if (isEng) {
          for (final variant in amharicVariantsNorm) {
            if (nameNorm == variant) {
              score += 85.0;
              break;
            } else if (nameNorm.startsWith(variant)) {
              score += 70.0;
              break;
            } else if (nameNorm.contains(variant)) {
              score += 55.0;
              break;
            }
          }
        }

        if (score < 40 && artist.searchKeywords.isNotEmpty) {
          for (final kw in artist.searchKeywords) {
            final kwNorm = AmharicTransliterator.normalizeAmharic(kw.toLowerCase());
            if (kwNorm == queryNormalized) {
              score += 35.0;
              break;
            }
          }
        }

        if (score > 0) {
          final existing = resultsMap[artist.id]?.score ?? 0;
          if (score > existing) {
            resultsMap[artist.id] = (
              score: score,
              result: SearchResult(
                item: artist,
                matchType: MatchType.artist,
                matchSnippet: artist.region.isNotEmpty ? artist.region : artist.englishName,
                score: score,
              ),
            );
          }
        }
      }
    }

    // 3. Search Albums
    if (category == SearchCategory.all || category == SearchCategory.albums) {
      for (final album in albums) {
        double score = 0.0;
        final titleLower = album.title.toLowerCase();
        final titleNorm = AmharicTransliterator.normalizeAmharic(titleLower);
        final engTitleLower = album.englishTitle.toLowerCase();

        if (titleLower == queryLower || engTitleLower == queryLower || titleNorm == queryNormalized) {
          score += 95.0;
        } else if (titleNorm.startsWith(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.startsWith(queryLower))) {
          score += 80.0;
        } else if (titleNorm.contains(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.contains(queryLower))) {
          score += 65.0;
        } else if (isEng) {
          for (final variant in amharicVariantsNorm) {
            if (titleNorm == variant) {
              score += 80.0;
              break;
            } else if (titleNorm.startsWith(variant)) {
              score += 65.0;
              break;
            } else if (titleNorm.contains(variant)) {
              score += 50.0;
              break;
            }
          }
        }

        // Check Artist Name in Album
        final artistLower = album.artistName.toLowerCase();
        final artistNorm = AmharicTransliterator.normalizeAmharic(artistLower);
        if (artistNorm.contains(queryNormalized)) {
          score += 30.0;
        }

        if (score > 0) {
          final existing = resultsMap[album.id]?.score ?? 0;
          if (score > existing) {
            resultsMap[album.id] = (
              score: score,
              result: SearchResult(
                item: album,
                matchType: MatchType.album,
                matchSnippet: album.artistName,
                score: score,
              ),
            );
          }
        }
      }
    }

    // 4. Search Exercises
    if (category == SearchCategory.all || category == SearchCategory.exercises) {
      for (final exercise in exercises) {
        double score = 0.0;
        final titleLower = exercise.title.toLowerCase();
        final titleNorm = AmharicTransliterator.normalizeAmharic(titleLower);
        final engTitleLower = exercise.englishTitle.toLowerCase();
        final descLower = exercise.description.toLowerCase();

        if (titleLower == queryLower || engTitleLower == queryLower || titleNorm == queryNormalized) {
          score += 95.0;
        } else if (titleNorm.startsWith(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.startsWith(queryLower))) {
          score += 80.0;
        } else if (titleNorm.contains(queryNormalized) || (engTitleLower.isNotEmpty && engTitleLower.contains(queryLower))) {
          score += 65.0;
        } else if (descLower.contains(queryLower) || AmharicTransliterator.normalizeAmharic(descLower).contains(queryNormalized)) {
          score += 40.0;
        }

        if (score > 0) {
          final existing = resultsMap[exercise.id]?.score ?? 0;
          if (score > existing) {
            resultsMap[exercise.id] = (
              score: score,
              result: SearchResult(
                item: exercise,
                matchType: MatchType.exercise,
                matchSnippet: exercise.description.isNotEmpty ? exercise.description : 'Vocal Exercise',
                score: score,
              ),
            );
          }
        }
      }
    }

    final sorted = resultsMap.values.toList();
    sorted.sort((a, b) => b.score.compareTo(a.score));

    return sorted.map((e) => e.result).toList();
  }

  // ---------------------------------------------------------------------------
  // SERVER-SIDE SUPABASE SEARCH (FALLBACK / CROSS-DEVICE)
  // ---------------------------------------------------------------------------

  /// Calls Supabase RPC search_multi_script or queries with GIN index keywords
  Future<List<SearchResult>> searchSupabase({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final tokens = AmharicTransliterator.generateSearchKeywords(title: cleanQuery);

      final response = await _client.rpc('search_multi_script', params: {
        'query_text': cleanQuery,
        'query_tokens': tokens,
        'category': category.name,
        'result_limit': limit,
      });

      final List<SearchResult> results = [];

      if (response is Map<String, dynamic>) {
        if (response['songs'] is List) {
          for (final item in response['songs']) {
            final song = Song.fromMap(item as Map<String, dynamic>);
            results.add(SearchResult(
              item: song,
              matchType: MatchType.title,
              matchSnippet: song.artistName,
              score: (item['match_score'] as num?)?.toDouble() ?? 50.0,
            ));
          }
        }

        if (response['artists'] is List) {
          for (final item in response['artists']) {
            final artist = Artist.fromMap(item as Map<String, dynamic>);
            results.add(SearchResult(
              item: artist,
              matchType: MatchType.artist,
              matchSnippet: artist.region,
              score: (item['match_score'] as num?)?.toDouble() ?? 50.0,
            ));
          }
        }

        if (response['albums'] is List) {
          for (final item in response['albums']) {
            final album = Album.fromMap(item as Map<String, dynamic>);
            results.add(SearchResult(
              item: album,
              matchType: MatchType.album,
              matchSnippet: album.artistName,
              score: (item['match_score'] as num?)?.toDouble() ?? 50.0,
            ));
          }
        }

        if (response['exercises'] is List) {
          for (final item in response['exercises']) {
            final exercise = VocalExerciseDay.fromMap(item as Map<String, dynamic>);
            results.add(SearchResult(
              item: exercise,
              matchType: MatchType.exercise,
              matchSnippet: exercise.description,
              score: (item['match_score'] as num?)?.toDouble() ?? 50.0,
            ));
          }
        }
      }

      results.sort((a, b) => b.score.compareTo(a.score));
      return results;
    } catch (e) {
      debugPrint('Error in searchSupabase RPC: $e');
      return [];
    }
  }
}
