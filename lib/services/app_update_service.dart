import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_config_model.dart';
import 'force_update_service.dart';
import 'supabase_service.dart';

/// Centralized state and execution engine for In-App Force Update and native APK downloads.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _prefApkPath = 'apk_update_local_path';
  static const String _prefApkVersion = 'apk_update_version';
  static const String _prefApkUrl = 'apk_update_url';
  static const String _prefApkBytes = 'apk_update_bytes';
  static const String _prefAwaitingPermission = 'apk_update_awaiting_permission';
  static const String _apkFileName = 'mahletesemay_update.apk';

  AppConfigModel? _currentConfig;
  AppConfigModel? get currentConfig => _currentConfig;

  String? _installedVersion;
  String? get installedVersion => _installedVersion;

  bool _isUpdateRequired = false;
  bool get isUpdateRequired => _isUpdateRequired;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  int _totalBytes = 0;
  int get totalBytes => _totalBytes;

  String? _downloadedApkPath;
  String? get downloadedApkPath => _downloadedApkPath;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _installPermissionRequired = false;
  bool get installPermissionRequired => _installPermissionRequired;

  /// True when a complete APK for the pending update is already on disk.
  bool get isApkReady => _downloadedApkPath != null;

  CancelToken? _cancelToken;

  String? _persistedPath;
  String? _persistedVersion;
  String? _persistedUrl;
  int? _persistedBytes;
  bool _awaitingInstallPermission = false;
  bool _isInstalling = false;
  bool _handlingResume = false;
  bool _didRestorePersistedApk = false;

  bool _monitoring = false;
  StreamSubscription<AppConfigModel?>? _configStreamSub;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;
  Future<bool>? _inFlightCheck;

  static const Duration _pollInterval = Duration(seconds: 15);

  /// Starts live release monitoring: Realtime channel, table stream, and a
  /// short foreground poll so a published force-update locks the app immediately.
  void startMonitoring() {
    if (kIsWeb) return;

    if (_monitoring) {
      _bindRealtime();
      _startPollTimer();
      unawaited(checkForUpdate());
      return;
    }

    _monitoring = true;
    _bindRealtime();
    _startPollTimer();
    unawaited(checkForUpdate());
  }

  /// Applies a remote `app_config` row immediately — used by Realtime and FCM
  /// so the lock screen does not wait for a second REST round-trip.
  Future<void> applyRemoteConfig(AppConfigModel config) async {
    if (kIsWeb) return;

    await _ensureInstalledVersion();
    _currentConfig = config;

    final installed = _installedVersion ?? '';
    final parts = installed.split('+');
    final requiresUpdate = ForceUpdateService.isUpdateRequired(
      installedVersion: parts.first,
      installedBuild: parts.length > 1 ? parts.last : null,
      minRequiredVersion: config.minRequiredVersion,
      latestVersion: config.latestVersion,
      forceUpdate: config.forceUpdate,
    );

    debugPrint(
      '[AppUpdateService] Apply config: installed=$_installedVersion, '
      'min=${config.minRequiredVersion}, latest=${config.latestVersion}, '
      'forceFlag=${config.forceUpdate} -> required=$requiresUpdate',
    );

    _isUpdateRequired = requiresUpdate;
    if (!requiresUpdate) {
      await _clearPersistedApk(deleteFile: true);
    } else {
      await _syncPermissionFlagWithDisk();
      unawaited(_resumePendingInstall());
    }
    notifyListeners();
  }

  /// Performs version comparison against remote `app_config` record.
  /// Safe across Web, Android, and iOS.
  Future<bool> checkForUpdate() async {
    final inFlight = _inFlightCheck;
    if (inFlight != null) return inFlight;

    final future = _checkForUpdateInternal();
    _inFlightCheck = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightCheck, future)) {
        _inFlightCheck = null;
      }
    }
  }

  Future<bool> _checkForUpdateInternal() async {
    await _restorePersistedApk();

    if (kIsWeb) {
      _isUpdateRequired = false;
      notifyListeners();
      return false;
    }

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final isConnected = connectivityResults.any((r) => r != ConnectivityResult.none);
      if (!isConnected) {
        debugPrint('[AppUpdateService] Device is offline, keeping last known update state');
        return _isUpdateRequired;
      }
    } catch (_) {
      // Continue if connectivity check itself throws
    }

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = await SupabaseService().getAppConfig(
        timeout: const Duration(seconds: 8),
      );

      if (config == null) {
        debugPrint('[AppUpdateService] Config fetch returned empty; keeping last known state');
        _isChecking = false;
        notifyListeners();
        return _isUpdateRequired;
      }

      await applyRemoteConfig(config);
      _isChecking = false;
      notifyListeners();
      return _isUpdateRequired;
    } catch (e, st) {
      debugPrint('[AppUpdateService] Error checking for update: $e\n$st');
      _isChecking = false;
      notifyListeners();
      return _isUpdateRequired;
    }
  }

  void pauseBackgroundPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Called when the app returns to the foreground (e.g. after the install-permission
  /// settings screen). Continues installation of an already-downloaded APK — never
  /// starts a new download.
  Future<void> onAppResumed() async {
    if (_handlingResume || _isDownloading) return;
    _handlingResume = true;
    try {
      _bindRealtime();
      _startPollTimer();
      await _restorePersistedApk();
      await _syncPermissionFlagWithDisk();
      await _resumePendingInstall();
      if (!_isInstalling) {
        await checkForUpdate();
      }
    } finally {
      _handlingResume = false;
    }
  }

  Future<void> _ensureInstalledVersion() async {
    if (_installedVersion != null && _installedVersion!.isNotEmpty) return;
    final packageInfo = await PackageInfo.fromPlatform();
    _installedVersion = packageInfo.buildNumber.isNotEmpty
        ? '${packageInfo.version}+${packageInfo.buildNumber}'
        : packageInfo.version;
  }

  void _bindRealtime() {
    _unbindRealtime();

    _configStreamSub = SupabaseService().getAppConfigStream().listen(
      (config) {
        if (config != null) {
          unawaited(applyRemoteConfig(config));
        }
      },
      onError: (Object error) {
        debugPrint('[AppUpdateService] app_config stream error: $error');
      },
    );

    try {
      _realtimeChannel = Supabase.instance.client
          .channel('app_config_force_update')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_config',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isEmpty) return;
              debugPrint('[AppUpdateService] Realtime app_config change received');
              unawaited(applyRemoteConfig(AppConfigModel.fromJson(record)));
            },
          );
      _realtimeChannel!.subscribe((status, error) {
        debugPrint(
          '[AppUpdateService] Realtime status=$status'
          '${error != null ? ' error=$error' : ''}',
        );
      });
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to bind Realtime channel: $e');
    }
  }

  void _unbindRealtime() {
    _configStreamSub?.cancel();
    _configStreamSub = null;
    if (_realtimeChannel != null) {
      unawaited(_realtimeChannel!.unsubscribe());
      unawaited(Supabase.instance.client.removeChannel(_realtimeChannel!));
      _realtimeChannel = null;
    }
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_isDownloading || _isInstalling) return;
      unawaited(checkForUpdate());
    });
  }

  /// Downloads the APK directly from [apkUrl] with live byte & percentage tracking.
  /// If a complete APK for this release is already on the device, skips the
  /// download and opens the installer instead.
  Future<void> downloadAndInstallApk({
    String? apkUrl,
    bool forceRedownload = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      _errorMessage = 'In-app APK installation is supported on Android devices.';
      notifyListeners();
      return;
    }

    if (_isDownloading) return;

    final targetUrl = apkUrl ?? _currentConfig?.apkUrl;
    if (targetUrl == null || targetUrl.trim().isEmpty) {
      _errorMessage = 'No valid APK download URL provided.';
      notifyListeners();
      return;
    }

    if (!forceRedownload &&
        await hasValidDownloadedApk(
          expectedUrl: targetUrl,
          expectedVersion: _currentConfig?.latestVersion,
        )) {
      debugPrint('[AppUpdateService] APK already on device. Opening installer instead of re-downloading.');
      _errorMessage = null;
      notifyListeners();
      await triggerApkInstallation();
      return;
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _errorMessage = null;
    _installPermissionRequired = false;
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      final savePath = await _canonicalApkPath();
      final partialPath = '$savePath.partial';

      if (forceRedownload) {
        await _deleteFileIfExists(savePath);
        await _deleteFileIfExists(partialPath);
        await _deleteFileIfExists(_downloadedApkPath);
        await _deleteFileIfExists(await _legacyTempApkPath());
        _downloadedApkPath = null;
        await _clearPersistedApk(deleteFile: false);
      } else {
        await _deleteFileIfExists(partialPath);
      }

      final dio = Dio();
      await dio.download(
        targetUrl,
        partialPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            _downloadedBytes = received;
            _totalBytes = total;
            notifyListeners();
          }
        },
      );

      final partialFile = File(partialPath);
      if (!await partialFile.exists() || await partialFile.length() == 0) {
        throw Exception('Downloaded APK file is empty or missing.');
      }

      await _deleteFileIfExists(savePath);
      await partialFile.rename(savePath);

      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
        throw Exception('Downloaded APK file is empty or missing.');
      }

      _downloadedApkPath = savePath;
      _persistedPath = savePath;
      _persistedUrl = targetUrl;
      _persistedVersion = _currentConfig?.latestVersion;
      _persistedBytes = await downloadedFile.length();
      _isDownloading = false;
      _downloadProgress = 1.0;
      // Persist before leaving the app for the install-permission screen so a
      // process restart does not lose the completed download.
      await _persistMetadata();
      notifyListeners();

      await triggerApkInstallation();
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        debugPrint('[AppUpdateService] APK download cancelled by user.');
        _errorMessage = 'Download cancelled.';
      } else {
        debugPrint('[AppUpdateService] APK download failed: $e');
        _errorMessage = 'Download failed: ${e.toString().replaceAll('Exception:', '').trim()}';
      }
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Cancels any in-progress APK download.
  void cancelDownload() {
    if (_isDownloading && _cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken?.cancel('User cancelled download');
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Checks Android 8.0+ install permissions and triggers the native APK installer.
  Future<void> triggerApkInstallation() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_isInstalling) return;

    if (!await hasValidDownloadedApk()) {
      _errorMessage = 'APK file not found. Please tap Update Now again.';
      notifyListeners();
      return;
    }

    _isInstalling = true;
    try {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        debugPrint('[AppUpdateService] REQUEST_INSTALL_PACKAGES not granted. Requesting...');
        _awaitingInstallPermission = true;
        _installPermissionRequired = true;
        _errorMessage = null;
        await _persistMetadata();
        notifyListeners();

        final reqStatus = await Permission.requestInstallPackages.request();
        // OEMs often update the grant after the activity resumes; re-query.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        status = await Permission.requestInstallPackages.status;

        if (!status.isGranted && !reqStatus.isGranted) {
          debugPrint('[AppUpdateService] Install unknown apps permission not granted yet.');
          _installPermissionRequired = true;
          _awaitingInstallPermission = true;
          await _persistMetadata();
          notifyListeners();
          return;
        }
      }

      _awaitingInstallPermission = false;
      _installPermissionRequired = false;
      _errorMessage = null;
      await _persistMetadata();
      notifyListeners();

      debugPrint('[AppUpdateService] Launching native package installer for: $_downloadedApkPath');
      final result = await OpenFilex.open(
        _downloadedApkPath!,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[AppUpdateService] OpenFile result: ${result.type} - ${result.message}');
      if (result.type != ResultType.done) {
        _errorMessage = 'Could not launch package installer: ${result.message}';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error triggering installation: $e');
      _errorMessage = 'Error launching package installer: $e';
      notifyListeners();
    } finally {
      _isInstalling = false;
    }
  }

  /// Opens the system "Install unknown apps" screen for this package.
  Future<void> openInstallSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _awaitingInstallPermission = true;
    await _persistMetadata();
    await Permission.requestInstallPackages.request();
  }

  /// Bypasses the lock screen for the current session (used for Admin or Debug).
  void bypassForAdminOrDebug() {
    _isUpdateRequired = false;
    notifyListeners();
  }

  /// Returns true when a complete APK for the pending release is already stored.
  Future<bool> hasValidDownloadedApk({
    String? expectedUrl,
    String? expectedVersion,
  }) async {
    await _restorePersistedApk();

    final canonical = await _canonicalApkPath();
    final legacy = await _legacyTempApkPath();
    final candidates = <String>{
      if (_downloadedApkPath != null) _downloadedApkPath!,
      canonical,
      if (_persistedPath != null) _persistedPath!,
      if (_persistedPath == legacy) legacy,
    };

    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      final length = await file.length();
      if (length <= 0) continue;

      if (_persistedBytes != null && _persistedBytes! > 0 && length != _persistedBytes) {
        debugPrint('[AppUpdateService] Incomplete APK at $path ($length vs $_persistedBytes).');
        continue;
      }

      final targetVersion = expectedVersion ?? _currentConfig?.latestVersion;
      if (targetVersion != null &&
          targetVersion.isNotEmpty &&
          _persistedVersion != null &&
          _persistedVersion!.isNotEmpty &&
          _persistedVersion != targetVersion) {
        debugPrint('[AppUpdateService] Stale APK version $_persistedVersion != $targetVersion.');
        continue;
      }

      final targetUrl = expectedUrl ?? _currentConfig?.apkUrl;
      if (targetUrl != null &&
          targetUrl.isNotEmpty &&
          _persistedUrl != null &&
          _persistedUrl!.isNotEmpty &&
          _persistedUrl != targetUrl) {
        debugPrint('[AppUpdateService] Stale APK url. Ignoring $path.');
        continue;
      }

      _downloadedApkPath = path;
      if (_persistedBytes == null || _persistedBytes == 0) {
        _persistedBytes = length;
      }
      return true;
    }

    return false;
  }

  Future<void> _resumePendingInstall() async {
    if (_isDownloading || _isInstalling) return;
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_awaitingInstallPermission) return;
    if (!await hasValidDownloadedApk()) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final granted = (await Permission.requestInstallPackages.status).isGranted;
    if (!granted) {
      _installPermissionRequired = true;
      notifyListeners();
      return;
    }

    debugPrint('[AppUpdateService] Install permission granted. Continuing with existing APK.');
    await triggerApkInstallation();
  }

  Future<void> _syncPermissionFlagWithDisk() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!await hasValidDownloadedApk()) return;

    final granted = (await Permission.requestInstallPackages.status).isGranted;
    _installPermissionRequired = !granted;
    if (!granted) {
      _awaitingInstallPermission = true;
    }
  }

  Future<void> _restorePersistedApk() async {
    if (_didRestorePersistedApk && _downloadedApkPath != null) {
      if (File(_downloadedApkPath!).existsSync()) return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _persistedPath = prefs.getString(_prefApkPath);
      _persistedVersion = prefs.getString(_prefApkVersion);
      _persistedUrl = prefs.getString(_prefApkUrl);
      _persistedBytes = prefs.getInt(_prefApkBytes);
      _awaitingInstallPermission = prefs.getBool(_prefAwaitingPermission) ?? _awaitingInstallPermission;

      final savedPath = _persistedPath;
      final candidates = <String>{
        if (savedPath != null && savedPath.isNotEmpty) savedPath,
        await _canonicalApkPath(),
        await _legacyTempApkPath(),
      };

      for (final path in candidates) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          _downloadedApkPath = path;
          _downloadProgress = 1.0;
          _downloadedBytes = await file.length();
          _totalBytes = _persistedBytes ?? _downloadedBytes;
          debugPrint('[AppUpdateService] Restored downloaded APK at $path');
          break;
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to restore persisted APK: $e');
    } finally {
      _didRestorePersistedApk = true;
    }
  }

  Future<void> _persistMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_downloadedApkPath != null) {
        await prefs.setString(_prefApkPath, _downloadedApkPath!);
      }
      if (_persistedVersion != null) {
        await prefs.setString(_prefApkVersion, _persistedVersion!);
      }
      if (_persistedUrl != null) {
        await prefs.setString(_prefApkUrl, _persistedUrl!);
      }
      if (_persistedBytes != null) {
        await prefs.setInt(_prefApkBytes, _persistedBytes!);
      }
      await prefs.setBool(_prefAwaitingPermission, _awaitingInstallPermission);
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to persist APK metadata: $e');
    }
  }

  Future<void> _clearPersistedApk({required bool deleteFile}) async {
    if (deleteFile) {
      await _deleteFileIfExists(_downloadedApkPath);
      await _deleteFileIfExists(await _canonicalApkPath());
      await _deleteFileIfExists(await _legacyTempApkPath());
    }

    _downloadedApkPath = null;
    _persistedPath = null;
    _persistedVersion = null;
    _persistedUrl = null;
    _persistedBytes = null;
    _awaitingInstallPermission = false;
    _installPermissionRequired = false;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefApkPath);
      await prefs.remove(_prefApkVersion);
      await prefs.remove(_prefApkUrl);
      await prefs.remove(_prefApkBytes);
      await prefs.remove(_prefAwaitingPermission);
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to clear APK metadata: $e');
    }
  }

  Future<String> _canonicalApkPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_apkFileName';
  }

  Future<String> _legacyTempApkPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$_apkFileName';
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Could not delete $path: $e');
    }
  }
}
