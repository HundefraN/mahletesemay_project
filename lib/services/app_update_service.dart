import 'dart:io' show File, Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_config_model.dart';
import 'force_update_service.dart';
import 'supabase_service.dart';

/// Centralized state and execution engine for In-App Force Update and native APK downloads.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

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

  CancelToken? _cancelToken;

  /// Performs version comparison against remote `app_config` record.
  /// Safe across Web, Android, and iOS.
  Future<bool> checkForUpdate() async {
    if (kIsWeb) {
      _isUpdateRequired = false;
      notifyListeners();
      return false;
    }

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch remote release config
      final config = await SupabaseService().getAppConfig();
      _currentConfig = config;

      if (config == null) {
        _isUpdateRequired = false;
        _isChecking = false;
        notifyListeners();
        return false;
      }

      // 2. Read local package info
      final packageInfo = await PackageInfo.fromPlatform();
      _installedVersion = packageInfo.version;

      final localVersion = ForceUpdateService.parseVersion(_installedVersion);
      final minVersion = ForceUpdateService.parseVersion(config.minRequiredVersion);
      final latestVersion = ForceUpdateService.parseVersion(config.latestVersion);

      if (localVersion == null) {
        debugPrint('[AppUpdateService] Could not parse installed version: $_installedVersion');
        _isUpdateRequired = false;
        _isChecking = false;
        notifyListeners();
        return false;
      }

      bool requiresUpdate = false;

      // Check min required version rule
      if (minVersion != null && localVersion < minVersion) {
        requiresUpdate = true;
      }

      // Check force update flag rule
      if (config.forceUpdate) {
        if (latestVersion != null) {
          if (localVersion < latestVersion) {
            requiresUpdate = true;
          }
        } else if (minVersion != null) {
          if (localVersion < minVersion) {
            requiresUpdate = true;
          }
        } else {
          requiresUpdate = true;
        }
      }

      _isUpdateRequired = requiresUpdate;
      debugPrint(
        '[AppUpdateService] Check: installed=$localVersion, min=$minVersion, latest=$latestVersion, '
        'forceFlag=${config.forceUpdate} -> required=$requiresUpdate',
      );

      _isChecking = false;
      notifyListeners();
      return requiresUpdate;
    } catch (e, st) {
      debugPrint('[AppUpdateService] Error checking for update: $e\n$st');
      _isChecking = false;
      _isUpdateRequired = false;
      notifyListeners();
      return false;
    }
  }

  /// Downloads the APK directly from [apkUrl] with live byte & percentage tracking.
  Future<void> downloadAndInstallApk({String? apkUrl}) async {
    if (kIsWeb || !Platform.isAndroid) {
      _errorMessage = 'In-app APK installation is supported on Android devices.';
      notifyListeners();
      return;
    }

    final targetUrl = apkUrl ?? _currentConfig?.apkUrl;
    if (targetUrl == null || targetUrl.trim().isEmpty) {
      _errorMessage = 'No valid APK download URL provided.';
      notifyListeners();
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
      // Use internal cache directory to comply with FileProvider and scoped storage
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/mahletesemay_update.apk';

      // Remove any stale update file
      final existingFile = File(savePath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      final dio = Dio();
      await dio.download(
        targetUrl,
        savePath,
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

      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
        throw Exception('Downloaded APK file is empty or missing.');
      }

      _downloadedApkPath = savePath;
      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();

      // Immediately trigger installation
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

    if (_downloadedApkPath == null || !File(_downloadedApkPath!).existsSync()) {
      _errorMessage = 'APK file not found. Please tap Update Now again.';
      notifyListeners();
      return;
    }

    try {
      // Android 8.0+ (API 26+) requires REQUEST_INSTALL_PACKAGES permission
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        debugPrint('[AppUpdateService] REQUEST_INSTALL_PACKAGES not granted. Requesting...');
        final reqStatus = await Permission.requestInstallPackages.request();
        if (!reqStatus.isGranted) {
          debugPrint('[AppUpdateService] Install unknown apps permission denied by user.');
          _installPermissionRequired = true;
          _errorMessage = 'Please enable "Install unknown apps" permission to install the update.';
          notifyListeners();
          return;
        }
      }

      _installPermissionRequired = false;
      _errorMessage = null;
      notifyListeners();

      debugPrint('[AppUpdateService] Launching native package installer for: $_downloadedApkPath');
      final result = await OpenFile.open(
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
    }
  }

  /// Opens the system app settings to allow the user to toggle "Install unknown apps".
  Future<void> openInstallSettings() async {
    await openAppSettings();
  }

  /// Bypasses the lock screen for the current session (used for Admin or Debug).
  void bypassForAdminOrDebug() {
    _isUpdateRequired = false;
    notifyListeners();
  }
}
