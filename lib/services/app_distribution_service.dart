import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';
import 'supabase_service.dart';

class AppDistributionException implements Exception {
  const AppDistributionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Resolves the published Android APK and either downloads it (web) or
/// shares the actual installer file with another device.
class AppDistributionService {
  AppDistributionService._();
  static final AppDistributionService instance = AppDistributionService._();

  static const String apkFileName = 'MahleteSemay.apk';
  static const String apkMimeType = 'application/vnd.android.package-archive';
  static const String _prefCachedSharePath = 'share_apk_local_path';
  static const String _prefCachedShareUrl = 'share_apk_source_url';

  String? _cachedApkUrl;

  Future<String?> resolveApkUrl() async {
    final fromMemory = _cachedApkUrl ?? AppUpdateService.instance.currentConfig?.apkUrl;
    if (fromMemory != null && fromMemory.trim().isNotEmpty) {
      _cachedApkUrl = fromMemory.trim();
      return _cachedApkUrl;
    }

    final config = await SupabaseService().getAppConfig();
    final url = config?.apkUrl?.trim();
    if (url != null && url.isNotEmpty) {
      _cachedApkUrl = url;
    }
    return _cachedApkUrl;
  }

  /// Opens the published APK so the browser can save it on this device.
  Future<void> downloadAndroidApp() async {
    final url = await resolveApkUrl();
    if (url == null) {
      throw const AppDistributionException('unavailable');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const AppDistributionException('unavailable');
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) {
      throw const AppDistributionException('unavailable');
    }
  }

  /// Shares the published APK file so it can be sent to another phone.
  Future<void> shareAndroidApp({
    VoidCallback? onPrepared,
    void Function(double progress)? onProgress,
  }) async {
    final url = await resolveApkUrl();
    if (url == null) {
      throw const AppDistributionException('unavailable');
    }

    if (kIsWeb) {
      await _shareOnWeb(url, onPrepared: onPrepared);
      return;
    }

    final path = await _localApkPathForShare(url, onProgress: onProgress);
    onPrepared?.call();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            mimeType: apkMimeType,
            name: apkFileName,
          ),
        ],
        text: 'Mahlete Semay',
        subject: 'Mahlete Semay',
        fileNameOverrides: [apkFileName],
      ),
    );
  }

  Future<void> _shareOnWeb(String url, {VoidCallback? onPrepared}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        onPrepared?.call();
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                response.bodyBytes,
                mimeType: apkMimeType,
                name: apkFileName,
              ),
            ],
            text: 'Mahlete Semay',
            subject: 'Mahlete Semay',
            fileNameOverrides: [apkFileName],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('[AppDistribution] Web file share failed, falling back to URL: $e');
    }

    onPrepared?.call();
    await SharePlus.instance.share(
      ShareParams(
        text: 'Mahlete Semay — $url',
        subject: 'Mahlete Semay',
      ),
    );
  }

  Future<String> _localApkPathForShare(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final existingUpdatePath = AppUpdateService.instance.downloadedApkPath;
    if (existingUpdatePath != null &&
        existingUpdatePath.isNotEmpty &&
        await _hasLocalFile(existingUpdatePath)) {
      return existingUpdatePath;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedPath = prefs.getString(_prefCachedSharePath);
    final cachedUrl = prefs.getString(_prefCachedShareUrl);
    if (cachedPath != null &&
        cachedUrl == url &&
        await _hasLocalFile(cachedPath)) {
      return cachedPath;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$apkFileName';
    await Dio().download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    if (!await _hasLocalFile(path)) {
      throw const AppDistributionException('unavailable');
    }

    await prefs.setString(_prefCachedSharePath, path);
    await prefs.setString(_prefCachedShareUrl, url);
    return path;
  }

  Future<bool> _hasLocalFile(String path) async {
    try {
      return await XFile(path).length() > 0;
    } catch (_) {
      return false;
    }
  }
}
