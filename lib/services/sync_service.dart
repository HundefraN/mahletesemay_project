import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/services/local_db_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum to represent the outcome of a sync check.
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

  // Use a static flag to prevent multiple syncs from running at the same time.
  static bool _isSyncing = false;

  SyncService({
    required FirebaseService firebaseService,
    required LocalDbService localDbService,
    required Connectivity connectivity,
  })  : _firebaseService = firebaseService,
        _localDbService = localDbService,
        _connectivity = connectivity;

  // Checks if a sync is needed and allowed based on network conditions.
  Future<SyncResult> performSmartSync({bool forceOnMobile = false}) async {
    if (_isSyncing) {
      return SyncResult.syncAlreadyInProgress;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);

    if (!isConnected) {
      return SyncResult.offline;
    }

    final isWifi = connectivityResult.contains(ConnectivityResult.wifi);
    if (!isWifi && !forceOnMobile) {
      // User is on mobile data, but hasn't forced the sync.
      // We will check for new data without downloading it.
      bool hasNewData = await _checkForNewData();
      return hasNewData ? SyncResult.mobileData : SyncResult.noNewData;
    }

    // Proceed with the full sync (either on Wi-Fi or forced on mobile).
    _isSyncing = true;
    try {
      final artists = await _firebaseService.getArtists();
      await _localDbService.syncArtists(artists);

      final albums = await _firebaseService.getAlbums();
      await _localDbService.syncAlbums(albums);

      final songs = await _firebaseService.getSongs();
      await _localDbService.syncSongs(songs);

      // Save the current timestamp to know when the last successful sync was.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastSyncTimestamp', DateTime.now().millisecondsSinceEpoch);

      return SyncResult.synced;
    } catch (e) {
      print("Sync error: $e");
      return SyncResult.error;
    } finally {
      _isSyncing = false;
    }
  }

  // A lightweight check to see if there's new content without downloading it.
  Future<bool> _checkForNewData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt('lastSyncTimestamp');
      if (lastSyncMillis == null) {
        // If we've never synced, there's definitely "new" data.
        return true;
      }

      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);

      // Check if there are any new songs since the last sync.
      final hasNewSongs = await _firebaseService.hasNewSongsSince(lastSyncDate);
      return hasNewSongs;

    } catch (e) {
      print("Error checking for new data: $e");
      return false;
    }
  }
}