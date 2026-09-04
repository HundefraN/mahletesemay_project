import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/supabase_config.dart';
import '../services/firebase_service.dart';
import '../services/local_db_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

const String periodicSyncTaskUniqueName = 'mahlete_semay_periodic_sync';
const String periodicSyncTaskKey = 'com.hundefra.mahletesemay.periodicSync';
const String immediateSyncTaskKey = 'com.hundefra.mahletesemay.immediateSync';

/// Top-level callback dispatcher executed by WorkManager in a separate background isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('BackgroundSync: executing worker task "$task"');

    try {
      // 1. Initialize Supabase in the background isolate if needed
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );
      } catch (e) {
        // May already be initialized in some runtime configurations
        debugPrint('BackgroundSync: Supabase init notice ($e)');
      }

      // 2. Initialize notification service
      await NotificationService.initialize();

      // 3. Perform background database synchronization
      final syncSuccess = await BackgroundSyncService.performBackgroundSync();
      return Future.value(syncSuccess);
    } catch (error, stackTrace) {
      debugPrint('BackgroundSync: worker execution failed: $error\n$stackTrace');
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  BackgroundSyncService._();

  static bool _isInitialized = false;

  /// Initializes the WorkManager plugin and registers the periodic sync task.
  /// Strictly guarded to run only on Android and iOS.
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic background sync (runs every 15 minutes or when network allows)
      await Workmanager().registerPeriodicTask(
        periodicSyncTaskUniqueName,
        periodicSyncTaskKey,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      _isInitialized = true;
      debugPrint('BackgroundSyncService: WorkManager initialized and periodic task registered');
    } catch (e) {
      debugPrint('BackgroundSyncService: initialization error ($e)');
    }
  }

  /// Triggers a one-off immediate background sync via WorkManager.
  static Future<void> triggerImmediateSync() async {
    if (kIsWeb) return;
    try {
      final taskId = 'immediate_sync_${DateTime.now().millisecondsSinceEpoch}';
      await Workmanager().registerOneOffTask(
        taskId,
        immediateSyncTaskKey,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('BackgroundSyncService: scheduled immediate background task $taskId');
    } catch (e) {
      debugPrint('BackgroundSyncService: immediate sync scheduling error ($e)');
    }
  }

  /// Worker logic: checks for remote changes, updates SQLite cache, and raises
  /// a high-priority local notification if new songs were pulled down.
  static Future<bool> performBackgroundSync() async {
    try {
      final localDb = LocalDbService();
      final firebaseService = FirebaseService();

      // Check network connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.any((r) => r != ConnectivityResult.none);
      if (!isConnected) {
        debugPrint('BackgroundSync: device is offline, skipping');
        return true;
      }

      // Read current SQLite song IDs
      final existingSongs = await localDb.getSongs();
      final existingSongIds = existingSongs.map((s) => s.id).toSet();

      // Fetch remote content
      final artists = await firebaseService.getArtists();
      if (artists.isNotEmpty) {
        await localDb.syncArtists(artists);
      }

      final albums = await firebaseService.getAlbums();
      if (albums.isNotEmpty) {
        await localDb.syncAlbums(albums);
      }

      final remoteSongs = await firebaseService.getSongs();
      if (remoteSongs.isNotEmpty) {
        await localDb.syncSongs(remoteSongs);
      }

      // Check if new songs were added that were not in the local database
      if (existingSongIds.isNotEmpty) {
        final newSongs = remoteSongs.where((s) => !existingSongIds.contains(s.id)).toList();

        if (newSongs.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final alertsEnabled = prefs.getBool(prefNewContentAlertsEnabled) ?? true;

          if (alertsEnabled) {
            if (newSongs.length == 1) {
              final song = newSongs.first;
              await NotificationService.showNewContentNotification(
                title: 'New Song Available',
                body: '"${song.title}" by ${song.artistName} has been synced to your library.',
                songId: song.id,
              );
            } else {
              await NotificationService.showNewContentNotification(
                title: '${newSongs.length} New Songs Added',
                body: 'Fresh songs are now downloaded and ready in your library, including "${newSongs.first.title}".',
              );
            }
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefLastSyncTimestamp, DateTime.now().millisecondsSinceEpoch);
      debugPrint('BackgroundSync: successfully synced SQLite cache in background');
      return true;
    } catch (e, stack) {
      debugPrint('BackgroundSync: background sync error: $e\n$stack');
      return false;
    }
  }
}
