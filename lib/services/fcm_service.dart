import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final SupabaseService _supabaseService = SupabaseService();
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions for FCM
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM authorization status: ${settings.authorizationStatus}');

      // Get initial device token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Device Token: $token');
        await _saveTokenToSupabase(token);
      }

      // Listen for token refreshments
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveTokenToSupabase(newToken);
      });

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground FCM message: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('Error initializing FCM service: $e');
    }
  }

  static Future<void> updateUserToken(String? userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token, userId: userId);
      }
    } catch (e) {
      debugPrint('Error updating user FCM token: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token, {String? userId}) async {
    try {
      Map<String, dynamic> deviceInfo = {};
      if (Platform.isAndroid) {
        final android = await _deviceInfoPlugin.androidInfo;
        deviceInfo = {
          'id': android.id,
          'brand': android.brand,
          'model': android.model,
          'os': 'Android ${android.version.release}',
        };
      } else if (Platform.isIOS) {
        final ios = await _deviceInfoPlugin.iosInfo;
        deviceInfo = {
          'id': ios.identifierForVendor ?? 'unknown',
          'model': ios.utsname.machine,
          'os': 'iOS ${ios.systemVersion}',
        };
      }

      await _supabaseService.saveUserFcmToken(
        token: token,
        userId: userId,
        deviceInfo: deviceInfo,
      );
    } catch (e) {
      debugPrint('Error getting device info for FCM sync: $e');
    }
  }
}
