import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import '../models/song_model.dart';
import '../services/firebase_service.dart';

class SongProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _hasInitialDataLoaded = false;

  late StreamSubscription _artistsSubscription;
  late StreamSubscription _albumsSubscription;
  late StreamSubscription _songsSubscription;

  List<String> _favoriteSongIds = [];
  final String _favoritesKey = 'favoriteSongIds';

  List<Artist> get artists => _artists;
  List<Album> get allAlbums => _albums;
  List<Song> get allSongs => _songs;
  bool get isLoading => _isLoading;

  List<Song> get favoriteSongs => _songs.where((s) => _favoriteSongIds.contains(s.id)).toList();

  List<Song> get newestSongs {
    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedSongs;
  }

  List<Song> get trendingSongs {
    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return sortedSongs;
  }

  SongProvider() {
    _init();
  }

  void _init() async {
    await _loadFavorites();
    _listenToDataStreams();
  }

  void _listenToDataStreams() {
    _artistsSubscription = _firebaseService.getArtistsStream().listen((artistsData) {
      _artists = artistsData;
      _checkInitialLoad();
    });

    _albumsSubscription = _firebaseService.getAlbumsStream().listen((albumsData) {
      _albums = albumsData;
      _checkInitialLoad();
    });

    _songsSubscription = _firebaseService.getSongsStream().listen((songsData) {
      _songs = songsData;
      _checkInitialLoad();
    });
  }

  void _checkInitialLoad() {
    if (_artists.isNotEmpty && _albums.isNotEmpty && _songs.isNotEmpty && !_hasInitialDataLoaded) {
      _isLoading = false;
      _hasInitialDataLoaded = true;
      notifyListeners();
    } else if (_hasInitialDataLoaded) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _artistsSubscription.cancel();
    _albumsSubscription.cancel();
    _songsSubscription.cancel();
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

  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }

  Future<void> incrementSongViewCount(String songId) async {
    await _firebaseService.incrementSongViewCount(songId);
  }
  Future<void> incrementViewCount(String songId) async {
    await _firebaseService.incrementSongViewCount(songId);
  }

  List<Album> getAlbumsByArtist(String artistId) {
    return _albums.where((album) => album.artistId == artistId).toList();
  }

  List<Song> getSongsByAlbum(String albumId) {
    return _songs.where((song) => song.albumId == albumId).toList();
  }

  List<Song> getRecommendedSongs({int count = 6}) {
    if (_songs.isEmpty) return [];
    double maxViews = _songs.map((s) => s.viewCount).fold(0, (max, current) => current > max ? current : max).toDouble();
    if (maxViews == 0) maxViews = 1.0;

    List<({Song song, double score})> scoredSongs = [];
    for (var song in _songs) {
      final daysAgo = DateTime.now().difference(song.createdAt.toDate()).inDays;
      final recencyScore = 1 / (daysAgo + 1);
      final popularityScore = song.viewCount / maxViews;
      final totalScore = (popularityScore * 0.7) + (recencyScore * 0.3);
      scoredSongs.add((song: song, score: totalScore));
    }

    scoredSongs.sort((a, b) => b.score.compareTo(a.score));
    return scoredSongs.take(count).map((e) => e.song).toList();
  }

  List<Artist> getRecommendedArtists({String? region, int? count}) {
    if (_artists.isEmpty || _songs.isEmpty) return [];

    Map<String, double> artistScores = {};

    double totalViews = _songs.map((s) => s.viewCount).fold(0, (prev, count) => prev + count).toDouble();
    if (totalViews == 0) totalViews = 1.0;

    for (var artist in _artists) {
      double popularityScore = 0;
      double favoriteScore = 0;

      final artistSongs = _songs.where((s) => s.artistId == artist.id);

      if (artistSongs.isNotEmpty) {
        int artistTotalViews = artistSongs.map((s) => s.viewCount).fold(0, (prev, count) => prev + count);
        popularityScore = artistTotalViews / totalViews;
      }

      int artistFavoriteCount = artistSongs.where((s) => _favoriteSongIds.contains(s.id)).length;
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
    if (count != null) {
      result = result.take(count).toList();
    }

    return result;
  }
}