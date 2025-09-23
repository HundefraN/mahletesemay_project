import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/services/local_db_service.dart';
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

  Future<SyncResult> performSmartSync({bool forceOnMobile = false, required bool isInitialSync}) async {
    if (_isSyncing) {
      return SyncResult.syncAlreadyInProgress;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);

    if (!isConnected) {
      return SyncResult.offline;
    }

    if (!isInitialSync) {
      final isWifi = connectivityResult.contains(ConnectivityResult.wifi);
      if (!isWifi && !forceOnMobile) {
        bool hasNewData = await _checkForNewData();
        return hasNewData ? SyncResult.mobileData : SyncResult.noNewData;
      }
    }

    _isSyncing = true;
    try {
      final artists = await _firebaseService.getArtists();
      await _localDbService.syncArtists(artists);

      final albums = await _firebaseService.getAlbums();
      await _localDbService.syncAlbums(albums);

      final songs = await _firebaseService.getSongs();
      await _localDbService.syncSongs(songs);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefLastSyncTimestamp, DateTime.now().millisecondsSinceEpoch);

      return SyncResult.synced;
    } catch (e) {
      print("Sync error: $e");
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