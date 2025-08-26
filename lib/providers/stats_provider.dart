import 'package:flutter/material.dart';
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
  Moderator? mostActiveModerator; // Placeholder for future logic

  StatsProvider(this._songProvider, this._authProvider) {
    _songProvider.addListener(_calculateStats);
    _authProvider.addListener(_calculateStats);
    _calculateStats();
  }

  void _calculateStats() {
    // Song Stats
    totalSongs = _songProvider.allSongs.length;
    totalArtists = _songProvider.artists.length;
    totalAlbums = _songProvider.allAlbums.length;

    if (_songProvider.allSongs.isNotEmpty) {
      totalSongViews = _songProvider.allSongs.map((s) => s.viewCount).reduce((a, b) => a + b);
      _songProvider.allSongs.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      mostViewedSong = _songProvider.allSongs.first;
    } else {
      totalSongViews = 0;
      mostViewedSong = null;
    }

    // You can add more complex logic here later, e.g., fetching admin logs
    // to determine the most active moderator. For now, this is a placeholder.
    totalModerators = 0; // This would require fetching all users, which is an admin SDK task.

    notifyListeners();
  }

  @override
  void dispose() {
    _songProvider.removeListener(_calculateStats);
    _authProvider.removeListener(_calculateStats);
    super.dispose();
  }
}