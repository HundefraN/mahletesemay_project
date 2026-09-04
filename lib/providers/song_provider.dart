import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<Artist>>? _artistsStreamSubscription;
  StreamSubscription<List<Album>>? _albumsStreamSubscription;
  StreamSubscription<List<Song>>? _songsStreamSubscription;

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

    final Set<String> favoriteSongIdsSet = _favoriteSongIds.toSet();
    final Map<String, double> artistAffinity = {};
    final Map<String, double> albumAffinity = {};
    final Map<String, double> scaleAffinity = {};
    final Map<String, double> rhythmAffinity = {};

    // 1. Process listening history with exponential recency decay
    for (int i = 0; i < _history.length && i < 30; i++) {
      final historyItem = _history[i];
      final recencyWeight = math.exp(-0.12 *
          i); // Exponential decay (most recent = ~1.0, older decays smoothly)
      final song = _songs.firstWhere((s) => s.id == historyItem.songId,
          orElse: () => _songs.first);
      if (song.id != historyItem.songId) continue;

      artistAffinity[song.artistId] =
          (artistAffinity[song.artistId] ?? 0.0) + (10.0 * recencyWeight);
      albumAffinity[song.albumId] =
          (albumAffinity[song.albumId] ?? 0.0) + (6.0 * recencyWeight);
      if (song.scale != null && song.scale!.isNotEmpty) {
        scaleAffinity[song.scale!] =
            (scaleAffinity[song.scale!] ?? 0.0) + (8.0 * recencyWeight);
      }
      if (song.rhythm != null && song.rhythm!.isNotEmpty) {
        rhythmAffinity[song.rhythm!] =
            (rhythmAffinity[song.rhythm!] ?? 0.0) + (6.0 * recencyWeight);
      }
    }

    // 2. Incorporate explicitly favorited songs with high bonus weight
    for (final favId in favoriteSongIdsSet) {
      final song =
          _songs.firstWhere((s) => s.id == favId, orElse: () => _songs.first);
      if (song.id != favId) continue;

      artistAffinity[song.artistId] =
          (artistAffinity[song.artistId] ?? 0.0) + 15.0;
      albumAffinity[song.albumId] = (albumAffinity[song.albumId] ?? 0.0) + 10.0;
      if (song.scale != null && song.scale!.isNotEmpty) {
        scaleAffinity[song.scale!] = (scaleAffinity[song.scale!] ?? 0.0) + 12.0;
      }
      if (song.rhythm != null && song.rhythm!.isNotEmpty) {
        rhythmAffinity[song.rhythm!] =
            (rhythmAffinity[song.rhythm!] ?? 0.0) + 10.0;
      }
    }

    // 3. Compute score for each candidate song
    double maxViews = 1.0;
    for (final s in _songs) {
      if (s.viewCount > maxViews) maxViews = s.viewCount.toDouble();
    }

    final recentViewedIds = _history.take(10).map((e) => e.songId).toSet();
    final List<({Song song, double score})> scoredSongs = [];

    for (final candidate in _songs) {
      double score = 0.0;

      // Affinity matches
      score += artistAffinity[candidate.artistId] ?? 0.0;
      score += albumAffinity[candidate.albumId] ?? 0.0;
      if (candidate.scale != null) {
        score += scaleAffinity[candidate.scale!] ?? 0.0;
      }
      if (candidate.rhythm != null) {
        score += rhythmAffinity[candidate.rhythm!] ?? 0.0;
      }

      // Global popularity signal (normalized log scale to prevent extreme outliers)
      final normViews =
          math.log(candidate.viewCount + 1) / math.log(maxViews + 1);
      score += normViews * 8.0;

      // Freshness bonus for recently created items
      final daysOld =
          DateTime.now().difference(candidate.createdAt.toDate()).inDays;
      if (daysOld < 30) {
        score += (30 - daysOld) / 30.0 * 4.0;
      }

      // Favorite bonus
      if (favoriteSongIdsSet.contains(candidate.id)) {
        score += 5.0;
      }

      // Mild penalty for recently viewed songs to ensure discovery
      if (recentViewedIds.contains(candidate.id)) {
        score -= 15.0;
      }

      scoredSongs.add((song: candidate, score: score));
    }

    scoredSongs.sort((a, b) => b.score.compareTo(a.score));

    // 4. Diversity Re-ranking (Interleaving to prevent clustering single artist)
    final List<Song> finalRecommendations = [];
    final Map<String, int> artistCountMap = {};

    for (final item in scoredSongs) {
      final count = artistCountMap[item.song.artistId] ?? 0;
      if (count < 3 || scoredSongs.length <= 10) {
        finalRecommendations.add(item.song);
        artistCountMap[item.song.artistId] = count + 1;
      }
    }

    // Fill remaining if diversity filter trimmed too many
    if (finalRecommendations.length < 20) {
      for (final item in scoredSongs) {
        if (!finalRecommendations.any((s) => s.id == item.song.id)) {
          finalRecommendations.add(item.song);
          if (finalRecommendations.length >= 20) break;
        }
      }
    }

    return finalRecommendations;
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

    if (kIsWeb) {
      // On web, skip local SQLite DB (its WASM worker can hang) and fetch
      // directly from Supabase. The browser always has network, so there is
      // no benefit to a local cache.
      await _fetchFromNetwork();
      _isLoading = false;
      notifyListeners();

      await _loadFavorites();
      await _loadHistory();

      _subscribeToRealtimeStreams();
      return;
    }

    // ── Mobile path ──────────────────────────────────────────────────────────
    await _loadFromLocalDb();
    if (_songs.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
    }

    await _loadFavorites();
    await _loadHistory();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        _handleSync();
      }
    });

    final bool shouldForce = _songs.isEmpty;
    await _handleSync(forceOnMobile: shouldForce || true);

    if (_isLoading) {
      _isLoading = false;
      notifyListeners();
    }

    // Subscribe to real-time streams for live updates
    _subscribeToRealtimeStreams();
  }

  void _safeNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  /// Fetches artists, albums and songs directly from Supabase in parallel.
  /// Used on web where the local SQLite database is not available.
  Future<void> _fetchFromNetwork() async {
    try {
      final results = await Future.wait([
        _firebaseService.getArtists(),
        _firebaseService.getAlbums(),
        _firebaseService.getSongs(),
      ]);
      final fetchedArtists = results[0] as List<Artist>;
      final fetchedAlbums = results[1] as List<Album>;
      final fetchedSongs = results[2] as List<Song>;

      if (fetchedArtists.isNotEmpty || _artists.isEmpty) {
        _artists = fetchedArtists;
      }
      if (fetchedAlbums.isNotEmpty || _albums.isEmpty) {
        _albums = fetchedAlbums;
      }
      if (fetchedSongs.isNotEmpty || _songs.isEmpty) {
        _songs = fetchedSongs;
      }
      debugPrint(
          'Fetched network data: ${_artists.length} artists, ${_albums.length} albums, ${_songs.length} songs');
    } catch (e) {
      debugPrint('Error fetching from network: $e');
    }
  }

  void _subscribeToRealtimeStreams() {
    _artistsStreamSubscription?.cancel();
    _artistsStreamSubscription = _firebaseService.getArtistsStream().listen(
      (artists) {
        if (artists.isNotEmpty && _hasDataChanged(_artists, artists)) {
          _artists = artists;
          if (!kIsWeb) _localDbService.syncArtists(artists);
          _safeNotifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Artists realtime stream error: $e');
        _fetchFromNetwork().then((_) => _safeNotifyListeners());
      },
    );

    _albumsStreamSubscription?.cancel();
    _albumsStreamSubscription = _firebaseService.getAlbumsStream().listen(
      (albums) {
        if (albums.isNotEmpty && _hasDataChanged(_albums, albums)) {
          _albums = albums;
          if (!kIsWeb) _localDbService.syncAlbums(albums);
          _safeNotifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Albums realtime stream error: $e');
        _fetchFromNetwork().then((_) => _safeNotifyListeners());
      },
    );

    _songsStreamSubscription?.cancel();
    _songsStreamSubscription = _firebaseService.getSongsStream().listen(
      (songs) {
        if (songs.isNotEmpty && _hasDataChanged(_songs, songs)) {
          _songs = songs;
          if (!kIsWeb) _localDbService.syncSongs(songs);
          _safeNotifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Songs realtime stream error: $e');
        _fetchFromNetwork().then((_) => _safeNotifyListeners());
      },
    );
  }

  /// Lightweight diff: checks if two lists differ by length or element IDs.
  bool _hasDataChanged<T>(List<T> oldList, List<T> newList) {
    if (oldList.length != newList.length) return true;
    // Compare by identity of IDs for the known model types
    final oldIds = oldList.map((e) => _extractId(e)).toSet();
    final newIds = newList.map((e) => _extractId(e)).toSet();
    return !oldIds.containsAll(newIds) || !newIds.containsAll(oldIds);
  }

  String _extractId(dynamic item) {
    if (item is Artist) return item.id;
    if (item is Album) return item.id;
    if (item is Song) return item.id;
    return item.hashCode.toString();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleSync();
    }
  }

  Future<void> refreshData() async {
    if (kIsWeb) {
      _isSyncing = true;
      notifyListeners();
      await _fetchFromNetwork();
      _isSyncing = false;
      notifyListeners();
      return;
    }
    await _handleSync(forceOnMobile: true);
  }

  Future<void> _handleSync({bool forceOnMobile = false}) async {
    _isSyncing = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final bool isFirstSyncCompleted =
        prefs.getBool(prefFirstSyncCompleted) ?? false;
    final bool isDbEmpty = _songs.isEmpty;

    final result = await _syncService.performSmartSync(
        forceOnMobile: forceOnMobile || isDbEmpty,
        isInitialSync: !isFirstSyncCompleted || isDbEmpty);

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
    if (_isLoading && _songs.isNotEmpty) {
      _isLoading = false;
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
    _connectivitySubscription?.cancel();
    _artistsStreamSubscription?.cancel();
    _albumsStreamSubscription?.cancel();
    _songsStreamSubscription?.cancel();
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

    if (lastViewedMillis == null ||
        now
                .difference(
                    DateTime.fromMillisecondsSinceEpoch(lastViewedMillis))
                .inHours >
            12) {
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
    if (_artists.isEmpty) return [];

    final Map<String, double> artistScores = {};
    final Set<String> favIds = _favoriteSongIds.toSet();

    // Catalog view baseline
    for (var song in _songs) {
      artistScores[song.artistId] =
          (artistScores[song.artistId] ?? 0.0) + (song.viewCount * 0.5);
      if (favIds.contains(song.id)) {
        artistScores[song.artistId] =
            (artistScores[song.artistId] ?? 0.0) + 25.0;
      }
    }

    // User history boost
    for (int i = 0; i < _history.length && i < 30; i++) {
      final item = _history[i];
      final song = _songs.firstWhere((s) => s.id == item.songId,
          orElse: () => _songs.first);
      if (song.id == item.songId) {
        artistScores[song.artistId] =
            (artistScores[song.artistId] ?? 0.0) + (10.0 * math.exp(-0.1 * i));
      }
    }

    List<Artist> sortedArtists = List.from(_artists);
    sortedArtists.sort((a, b) {
      double scoreA = artistScores[a.id] ?? 0.0;
      double scoreB = artistScores[b.id] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    List<Artist> result = sortedArtists;
    if (region != null) {
      result =
          sortedArtists.where((artist) => artist.region == region).toList();
    }
    if (count != null) result = result.take(count).toList();
    return result;
  }
}
