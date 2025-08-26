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

class SongProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalDbService _localDbService = LocalDbService();
  late final SyncService _syncService;

  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _hasNewDataOnMobile = false;

  List<HistoryEntry> _history = [];
  final String _historyKey = 'songHistory';
  List<HistoryEntry> get history => _history;

  List<String> _favoriteSongIds = [];
  final String _favoritesKey = 'favoriteSongIds';

  List<Artist> get artists => _artists;
  List<Album> get allAlbums => _albums;
  List<Song> get allSongs => _songs;
  bool get isLoading => _isLoading;
  bool get hasNewDataOnMobile => _hasNewDataOnMobile;

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
    await _loadFavorites();
    await _loadHistory();
    await _handleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleSync();
    }
  }

  Future<void> _handleSync({bool forceOnMobile = false}) async {
    final result = await _syncService.performSmartSync(forceOnMobile: forceOnMobile);

    if (result == SyncResult.synced) {
      _hasNewDataOnMobile = false;
      await _loadFromLocalDb();
    } else if (result == SyncResult.mobileData) {
      _hasNewDataOnMobile = true;
    } else if (result == SyncResult.noNewData) {
      _hasNewDataOnMobile = false;
    }
    notifyListeners();
  }

  Future<void> forceSyncOnMobileData() async {
    await _handleSync(forceOnMobile: true);
  }

  Future<void> _loadFromLocalDb() async {
    _artists = await _localDbService.getArtists();
    _albums = await _localDbService.getAlbums();
    _songs = await _localDbService.getSongs();
    if (_artists.isNotEmpty || _songs.isNotEmpty || _albums.isNotEmpty) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    _history = historyJson.map((json) => HistoryEntry.fromJson(json)).toList();
    notifyListeners();
  }

  List<Song> sortSongsByRecommendation({required List<Song> songsToSort}) {
    if (songsToSort.isEmpty) return [];

    double maxViews = songsToSort
        .map((s) => s.viewCount)
        .fold(0, (max, current) => current > max ? current : max)
        .toDouble();
    if (maxViews == 0) maxViews = 1.0;

    List<({Song song, double score})> scoredSongs = [];
    for (var song in songsToSort) {
      final daysAgo = DateTime.now().difference(song.createdAt.toDate()).inDays;
      final recencyScore = 1 / (daysAgo + 1);
      final popularityScore = song.viewCount / maxViews;
      final totalScore = (popularityScore * 0.7) + (recencyScore * 0.3);
      scoredSongs.add((song: song, score: totalScore));
    }

    scoredSongs.sort((a, b) => b.score.compareTo(a.score));
    return scoredSongs.map((e) => e.song).toList();
  }

  Future<void> addToHistory(Song song) async {
    _history.removeWhere((entry) => entry.songId == song.id);
    _history.insert(0, HistoryEntry(songId: song.id, viewedAt: DateTime.now()));

    if (_history.length > 50) {
      _history = _history.sublist(0, 50);
    }

    final historyJson = _history.map((entry) => entry.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, historyJson);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteSongIds = prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> toggleFavorite(String songId) async {
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteSongIds);
    notifyListeners();
  }

  bool isFavorite(String songId) => _favoriteSongIds.contains(songId);

  Future<void> incrementViewCount(String songId) async =>
      await _firebaseService.incrementSongViewCount(songId);

  List<Album> getAlbumsByArtist(String artistId) {
    if (_albums.isEmpty) return [];
    return _albums.where((album) => album.artistId == artistId).toList();
  }

  List<Song> getSongsByAlbum(String albumId) {
    if (_songs.isEmpty) return [];
    return _songs.where((song) => song.albumId == albumId).toList();
  }

  List<Song> getRecommendedSongs({int count = 6}) {
    if (_songs.isEmpty) return [];
    return sortSongsByRecommendation(songsToSort: _songs).take(count).toList();
  }

  List<Artist> getRecommendedArtists({String? region, int? count}) {
    if (_artists.isEmpty || _songs.isEmpty) return [];
    Map<String, double> artistScores = {};
    double totalViews = _songs
        .map((s) => s.viewCount)
        .fold(0, (prev, count) => prev + count)
        .toDouble();
    if (totalViews == 0) totalViews = 1.0;
    for (var artist in _artists) {
      double popularityScore = 0;
      double favoriteScore = 0;
      final artistSongs = _songs.where((s) => s.artistId == artist.id);
      if (artistSongs.isNotEmpty) {
        int artistTotalViews = artistSongs
            .map((s) => s.viewCount)
            .fold(0, (prev, count) => prev + count);
        popularityScore = artistTotalViews / totalViews;
      }
      int artistFavoriteCount =
          artistSongs.where((s) => _favoriteSongIds.contains(s.id)).length;
      if (_favoriteSongIds.isNotEmpty) {
        favoriteScore = artistFavoriteCount / _favoriteSongIds.length;
      }
      artistScores[artist.id] = (popularityScore * 0.6) + (favoriteScore * 0.4);
    }
    List<Artist> sortedArtists = List.from(_artists);
    sortedArtists.sort((a, b) {
      double scoreA = artistScores[a.id] ?? 0;
      double scoreB = artistScores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });
    List<Artist> result = sortedArtists;
    if (region != null) {
      result = sortedArtists.where((artist) => artist.region == region).toList();
    }
    if (count != null) result = result.take(count).toList();
    return result;
  }
}