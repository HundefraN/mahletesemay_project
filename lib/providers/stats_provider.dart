import 'package:flutter/foundation.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'auth_proveider.dart';

class StatsProvider with ChangeNotifier {
  final SongProvider _songProvider;
  final AuthProvider _authProvider;

  // Cached Stats
  int totalSongs = 0;
  int totalArtists = 0;
  int totalAlbums = 0;
  int totalSongViews = 0;
  int totalModerators = 0;
  Song? mostViewedSong;
  Moderator? mostActiveModerator;

  StatsProvider(this._songProvider, this._authProvider) {
    _songProvider.addListener(_calculateStats);
    _authProvider.addListener(_calculateStats);
    _calculateStats();
  }

  void _calculateStats() {
    totalSongs = _songProvider.allSongs.length;
    totalArtists = _songProvider.artists.length;
    totalAlbums = _songProvider.allAlbums.length;

    if (_songProvider.allSongs.isNotEmpty) {
      totalSongViews = _songProvider.allSongs.fold(0, (sum, song) => sum + song.viewCount);

      // Efficiently find the most viewed song without sorting the whole list.
      mostViewedSong = _songProvider.allSongs.reduce((curr, next) => curr.viewCount > next.viewCount ? curr : next);
    } else {
      totalSongViews = 0;
      mostViewedSong = null;
    }

    totalModerators = 0;

    notifyListeners();
  }

  @override
  void dispose() {
    _songProvider.removeListener(_calculateStats);
    _authProvider.removeListener(_calculateStats);
    super.dispose();
  }
}