import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request Microphone permission with a clear rationale dialog when permanently denied.
  static Future<bool> requestMicrophone(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      final l10n = AppLocalizations.of(context);
      await _showPermissionSettingsDialog(
        context: context,
        title: l10n?.micPermissionTitle ?? 'Microphone Permission Required',
        description: l10n?.micPermissionDesc ??
            'Mahlete Semay requires microphone access for the Vocal Range Finder and Pitch Trainer to detect and analyze your pitch.',
      );
    }
    return false;
  }

  /// Request Notification permission with SDK checks and clear rationale dialog.
  static Future<bool> requestNotification(BuildContext context) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        if (exactAlarmStatus.isDenied) {
          await Permission.scheduleExactAlarm.request();
        }
      }
      // On Android < 33, POST_NOTIFICATIONS is not needed
      if (androidInfo.version.sdkInt < 33) {
        return true;
      }
    }

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      final l10n = AppLocalizations.of(context);
      await _showPermissionSettingsDialog(
        context: context,
        title: l10n?.notifPermissionTitle ?? 'Notification Permission Required',
        description: l10n?.notifPermissionDesc ??
            'Enable notifications to receive daily vocal workout reminders and service alerts on schedule.',
      );
    }
    return false;
  }

  /// Request Photo/Gallery permission depending on platform and Android version.
  static Future<bool> requestPhotoAccess(BuildContext context) async {
    Permission targetPermission = Permission.photos;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        targetPermission = Permission.storage;
      }
    }

    final status = await targetPermission.status;
    if (status.isGranted) return true;

    final result = await targetPermission.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      await _showPermissionSettingsDialog(
        context: context,
        title: AppLocalizations.of(context)?.photosPermissionTitle ?? 'Photo Library Permission Required',
        description:
            'Photo library access is needed to choose and customize artist and album cover images.',
      );
    }
    return false;
  }

  /// Request Camera permission with clear rationale.
  static Future<bool> requestCameraAccess(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      await _showPermissionSettingsDialog(
        context: context,
        title: AppLocalizations.of(context)?.cameraPermissionTitle ?? 'Camera Permission Required',
        description:
            'Camera access is required to take photo covers for artists and albums.',
      );
    }
    return false;
  }

  /// Request Audio file access permission depending on Android version.
  static Future<bool> requestAudioAccess(BuildContext context) async {
    if (Platform.isIOS) return true; // iOS uses system file picker UI without explicit permission

    Permission targetPermission = Permission.audio;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 33) {
      targetPermission = Permission.storage;
    }

    final status = await targetPermission.status;
    if (status.isGranted) return true;

    final result = await targetPermission.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      await _showPermissionSettingsDialog(
        context: context,
        title: AppLocalizations.of(context)?.audioAccessTitle ?? 'Audio Access Required',
        description:
            'Audio access permission is required to import custom backing tracks for vocal practice.',
      );
    }
    return false;
  }

  /// Helper to display a standardized Settings dialog when permissions are permanently denied.
  static Future<void> _showPermissionSettingsDialog({
    required BuildContext context,
    required String title,
    required String description,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(AppLocalizations.of(context)?.openSettings ?? 'Open Settings'),
          ),
        ],
      ),
    );
  }
}
