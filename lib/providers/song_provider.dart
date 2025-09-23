import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import '../models/history_entry_model.dart';
import '../models/song_model.dart';
import '../services/firebase_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class SongProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalDbService _localDbService = LocalDbService();
  late final SyncService _syncService;

  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasNewDataOnMobile = false;

  List<HistoryEntry> _history = [];
  List<HistoryEntry> get history => _history;

  List<String> _favoriteSongIds = [];

  List<Artist> get artists => _artists;
  List<Album> get allAlbums => _albums;
  List<Song> get allSongs => _songs;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get hasNewDataOnMobile => _hasNewDataOnMobile;

  static const int _recommendationHistoryThreshold = 3;

  final Map<String, double> _scoringWeights = {
    'favoriteArtist': 15.0,
    'viewedArtist': 8.0,
    'favoriteAlbum': 10.0,
    'viewedAlbum': 5.0,
    'favoriteScale': 12.0,
    'viewedScale': 6.0,
    'favoriteRhythm': 10.0,
    'viewedRhythm': 4.0,
    'seenPenalty': -20.0,
  };

  List<Song> get favoriteSongs {
    if (_songs.isEmpty || _favoriteSongIds.isEmpty) return [];
    return _songs.where((s) => _favoriteSongIds.contains(s.id)).toList();
  }

  List<Song> get newestSongs {
    if (_songs.isEmpty) return [];
    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedSongs;
  }

  List<Song> get trendingSongs {
    if (_songs.isEmpty) return [];
    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return sortedSongs;
  }

  List<Song> getPersonalizedRecommendations() {
    if (_songs.isEmpty) return [];

    if (_history.length < _recommendationHistoryThreshold) {
      return trendingSongs;
    }

    final Map<String, double> artistScores = {};
    final Map<String, double> albumScores = {};
    final Map<String, double> scaleScores = {};
    final Map<String, double> rhythmScores = {};

    final recentHistory = _history.take(20);
    final Set<String> viewedSongIds = recentHistory.map((e) => e.songId).toSet();
    final Set<String> favoriteSongIdsSet = _favoriteSongIds.toSet();

    final List<Song> seedSongs = _songs.where((song) =>
    viewedSongIds.contains(song.id) || favoriteSongIdsSet.contains(song.id)
    ).toList();

    for (final song in seedSongs) {
      final isFavorite = favoriteSongIdsSet.contains(song.id);
      final artistWeight = isFavorite ? _scoringWeights['favoriteArtist']! : _scoringWeights['viewedArtist']!;
      final albumWeight = isFavorite ? _scoringWeights['favoriteAlbum']! : _scoringWeights['viewedAlbum']!;
      final scaleWeight = isFavorite ? _scoringWeights['favoriteScale']! : _scoringWeights['viewedScale']!;
      final rhythmWeight = isFavorite ? _scoringWeights['favoriteRhythm']! : _scoringWeights['viewedRhythm']!;

      artistScores[song.artistId] = (artistScores[song.artistId] ?? 0) + artistWeight;
      albumScores[song.albumId] = (albumScores[song.albumId] ?? 0) + albumWeight;
      if (song.scale != null) scaleScores[song.scale!] = (scaleScores[song.scale!] ?? 0) + scaleWeight;
      if (song.rhythm != null) rhythmScores[song.rhythm!] = (rhythmScores[song.rhythm!] ?? 0) + rhythmWeight;
    }

    final List<({Song song, double score})> scoredSongs = [];
    double maxViews = trendingSongs.isNotEmpty ? trendingSongs.first.viewCount.toDouble() : 1.0;
    if (maxViews == 0) maxViews = 1.0;

    for (final candidateSong in _songs) {
      double score = 0;

      score += artistScores[candidateSong.artistId] ?? 0;
      score += albumScores[candidateSong.albumId] ?? 0;
      if (candidateSong.scale != null) score += scaleScores[candidateSong.scale!] ?? 0;
      if (candidateSong.rhythm != null) score += rhythmScores[candidateSong.rhythm!] ?? 0;

      final popularityScore = (candidateSong.viewCount / maxViews) * 5;
      score += popularityScore;

      if (viewedSongIds.contains(candidateSong.id)) {
        score += _scoringWeights['seenPenalty']!;
      }

      if (score > 0) {
        scoredSongs.add((song: candidateSong, score: score));
      }
    }

    scoredSongs.sort((a, b) => b.score.compareTo(a.score));

    final recommended = scoredSongs.map((e) => e.song).toList();

    if (recommended.length < 20 && trendingSongs.isNotEmpty) {
      final popularFallback = trendingSongs.where((s) => !recommended.any((r) => r.id == s.id)).take(20 - recommended.length);
      recommended.addAll(popularFallback);
    }

    return recommended;
  }

  SongProvider() {
    _syncService = SyncService(
      firebaseService: _firebaseService,
      localDbService: _localDbService,
      connectivity: Connectivity(),
    );
    _init();
  }

  void _init() async {
    WidgetsBinding.instance.addObserver(this);

    await _loadFromLocalDb();
    _isLoading = false;
    notifyListeners();

    await _loadFavorites();
    await _loadHistory();

    _handleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleSync();
    }
  }

  Future<void> _handleSync({bool forceOnMobile = false}) async {
    _isSyncing = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final bool isFirstSyncCompleted = prefs.getBool(prefFirstSyncCompleted) ?? false;

    final result = await _syncService.performSmartSync(
        forceOnMobile: forceOnMobile,
        isInitialSync: !isFirstSyncCompleted
    );

    if (result == SyncResult.synced) {
      _hasNewDataOnMobile = false;
      await _loadFromLocalDb();
      if (!isFirstSyncCompleted) {
        await prefs.setBool(prefFirstSyncCompleted, true);
      }
    } else if (result == SyncResult.mobileData) {
      _hasNewDataOnMobile = true;
    } else if (result == SyncResult.noNewData) {
      _hasNewDataOnMobile = false;
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> forceSyncOnMobileData() async {
    await _handleSync(forceOnMobile: true);
  }

  Future<void> _loadFromLocalDb() async {
    _artists = await _localDbService.getArtists();
    _albums = await _localDbService.getAlbums();
    _songs = await _localDbService.getSongs();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(prefSongHistory) ?? [];
    _history = historyJson.map((json) => HistoryEntry.fromJson(json)).toList();
    notifyListeners();
  }

  Future<void> addToHistory(Song song) async {
    _history.removeWhere((entry) => entry.songId == song.id);
    _history.insert(0, HistoryEntry(songId: song.id, viewedAt: DateTime.now()));

    if (_history.length > 50) {
      _history = _history.sublist(0, 50);
    }

    final historyJson = _history.map((entry) => entry.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefSongHistory, historyJson);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteSongIds = prefs.getStringList(prefFavoriteSongIds) ?? [];
  }

  Future<void> toggleFavorite(String songId) async {
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefFavoriteSongIds, _favoriteSongIds);
    notifyListeners();
  }

  bool isFavorite(String songId) => _favoriteSongIds.contains(songId);

  Future<void> incrementViewCount(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastViewedKey = 'last_viewed_$songId';
    final lastViewedMillis = prefs.getInt(lastViewedKey);
    final now = DateTime.now();

    if (lastViewedMillis == null || now.difference(DateTime.fromMillisecondsSinceEpoch(lastViewedMillis)).inHours > 12) {
      try {
        await _firebaseService.incrementSongViewCount(songId);

        final songIndex = _songs.indexWhere((s) => s.id == songId);
        if (songIndex != -1) {
          final oldSong = _songs[songIndex];
          _songs[songIndex] = Song(
            id: oldSong.id,
            title: oldSong.title,
            artistName: oldSong.artistName,
            artistId: oldSong.artistId,
            albumId: oldSong.albumId,
            albumTitle: oldSong.albumTitle,
            lyrics: oldSong.lyrics,
            scale: oldSong.scale,
            rhythm: oldSong.rhythm,
            viewCount: oldSong.viewCount + 1,
            createdAt: oldSong.createdAt,
          );
          notifyListeners();
        }

        await prefs.setInt(lastViewedKey, now.millisecondsSinceEpoch);
      } catch (e) {
        debugPrint("Failed to increment view count for $songId: $e");
      }
    }
  }

  List<Album> getAlbumsByArtist(String artistId) {
    if (_albums.isEmpty) return [];
    return _albums.where((album) => album.artistId == artistId).toList();
  }

  List<Song> getSongsByAlbum(String albumId) {
    if (_songs.isEmpty) return [];
    return _songs.where((song) => song.albumId == albumId).toList();
  }

  List<Artist> getRecommendedArtists({String? region, int? count}) {
    if (_artists.isEmpty || _songs.isEmpty) return [];
    Map<String, int> artistViewCounts = {};
    for (var song in _songs) {
      artistViewCounts[song.artistId] = (artistViewCounts[song.artistId] ?? 0) + song.viewCount;
    }
    List<Artist> sortedArtists = List.from(_artists);
    sortedArtists.sort((a, b) {
      int viewsA = artistViewCounts[a.id] ?? 0;
      int viewsB = artistViewCounts[b.id] ?? 0;
      return viewsB.compareTo(viewsA);
    });
    List<Artist> result = sortedArtists;
    if (region != null) {
      result = sortedArtists.where((artist) => artist.region == region).toList();
    }
    if (count != null) result = result.take(count).toList();
    return result;
  }
}