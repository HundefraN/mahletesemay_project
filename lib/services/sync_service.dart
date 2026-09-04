import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/services/local_db_service.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncResult {
  synced,
  syncAlreadyInProgress,
  offline,
  mobileData,
  noNewData,
  error,
}

class SyncService {
  final FirebaseService _firebaseService;
  final LocalDbService _localDbService;
  final Connectivity _connectivity;

  static bool _isSyncing = false;

  SyncService({
    required FirebaseService firebaseService,
    required LocalDbService localDbService,
    required Connectivity connectivity,
  })  : _firebaseService = firebaseService,
        _localDbService = localDbService,
        _connectivity = connectivity;

  /// Read straight from preferences because sync can run outside the widget
  /// tree, where NotificationSettingsProvider is not reachable.
  Future<bool> _newContentAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefNewContentAlertsEnabled) ?? true;
  }

  Future<SyncResult> performSmartSync(
      {bool forceOnMobile = false, required bool isInitialSync}) async {
    if (_isSyncing) {
      return SyncResult.syncAlreadyInProgress;
    }

    // On web, the connectivity_plus plugin often reports none incorrectly.
    // Since the web app itself loaded in the browser, we know we have network.
    if (!kIsWeb) {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected =
          connectivityResult.any((r) => r != ConnectivityResult.none);

      if (!isConnected) {
        return SyncResult.offline;
      }
    }

    final existingSongs = await _localDbService.getSongs();
    final bool isEmptyDb = existingSongs.isEmpty;

    if (!isInitialSync && !isEmptyDb && !kIsWeb) {
      final connectivityCheck = await _connectivity.checkConnectivity();
      final isWifiOrUnmetered =
          connectivityCheck.contains(ConnectivityResult.wifi) ||
              connectivityCheck.contains(ConnectivityResult.ethernet) ||
              connectivityCheck.contains(ConnectivityResult.vpn);
      if (!isWifiOrUnmetered && !forceOnMobile) {
        bool hasNewData = await _checkForNewData();
        return hasNewData ? SyncResult.mobileData : SyncResult.noNewData;
      }
    }

    _isSyncing = true;
    try {
      final existingSongs = await _localDbService.getSongs();
      final Set<String> existingSongIds =
          existingSongs.map((s) => s.id).toSet();

      final artists = await _firebaseService.getArtists();
      if (artists.isNotEmpty) {
        await _localDbService.syncArtists(artists);
      }

      final albums = await _firebaseService.getAlbums();
      if (albums.isNotEmpty) {
        await _localDbService.syncAlbums(albums);
      }

      final songs = await _firebaseService.getSongs();
      if (songs.isNotEmpty) {
        await _localDbService.syncSongs(songs);
      }

      if (!isInitialSync && existingSongIds.isNotEmpty) {
        final newSongs =
            songs.where((s) => !existingSongIds.contains(s.id)).toList();
        if (newSongs.isNotEmpty && await _newContentAlertsEnabled()) {
          if (newSongs.length == 1) {
            final song = newSongs.first;
            await NotificationService.showNewContentNotification(
              title: 'New song added',
              body:
                  '"${song.title}" by ${song.artistName} is now in your library.',
              songId: song.id,
            );
          } else {
            await NotificationService.showNewContentNotification(
              title: '${newSongs.length} new songs added',
              body:
                  'Fresh lyrics are waiting in your library, including "${newSongs.first.title}".',
            );
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          prefLastSyncTimestamp, DateTime.now().millisecondsSinceEpoch);

      return SyncResult.synced;
    } catch (e, stackTrace) {
      print("Sync error: $e\n$stackTrace");
      return SyncResult.error;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _checkForNewData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(prefLastSyncTimestamp);
      if (lastSyncMillis == null) {
        return true;
      }

      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
      final hasNewSongs = await _firebaseService.hasNewSongsSince(lastSyncDate);
      return hasNewSongs;
    } catch (e) {
      print("Error checking for new data: $e");
      return false;
    }
  }
}
