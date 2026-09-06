import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../firebase_options.dart';
import '../utils/constants.dart';
import 'app_update_service.dart';
import 'background_sync_service.dart';
import 'notification_service.dart';
import 'push_payload.dart';
import 'supabase_service.dart';

/// Must be a top-level function: FCM runs this in a separate isolate when the
/// app is in the background or killed. Firebase + Supabase must be created
/// again here — they do not exist in this isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
    'FCM background message ${message.messageId} '
    'type=${message.data['type']} silent=${message.data['silent']}',
  );

  try {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('FCM background: Firebase init notice ($e)');
    }

    try {
      await dotenv.load();
    } catch (_) {
      // Compile-time / hardcoded Supabase fallbacks still apply.
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    } catch (e) {
      debugPrint('FCM background: Supabase init notice ($e)');
    }

    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('FCM background: NotificationService init notice ($e)');
    }

    await FcmService.handleIncomingMessage(message, fromBackground: true);
  } catch (e, stack) {
    debugPrint('FCM background handler error: $e\n$stack');
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final SupabaseService _supabaseService = SupabaseService();
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static void Function(NotificationPayload payload)? _tapHandler;
  static bool _handlersBound = false;

  /// Routes a push tap through the same navigator path as local notifications.
  static void setTapHandler(void Function(NotificationPayload payload) handler) {
    _tapHandler = handler;
  }

  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        _messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToSupabase(newToken);
        });
        return;
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      if (!_handlersBound) {
        _handlersBound = true;

        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('FCM Token refreshed: $newToken');
          _saveTokenToSupabase(newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint(
            'FCM foreground message ${message.messageId} '
            'title=${message.notification?.title}',
          );
          handleIncomingMessage(message, fromBackground: false);
        });

        FirebaseMessaging.onMessageOpenedApp.listen(_dispatchTap);

        final initial = await _messaging.getInitialMessage();
        if (initial != null) {
          _dispatchTap(initial);
        }
      }

      _syncInitialToken();
    } catch (e) {
      debugPrint('Error initializing FCM service: $e');
    }
  }

  /// Syncs the SQLite cache for every incoming push. Shows a local
  /// notification only when the payload is visible and the OS did not
  /// already display one (foreground, or data-only).
  static Future<void> handleIncomingMessage(
    RemoteMessage message, {
    required bool fromBackground,
  }) async {
    final payload = PushPayload.fromRemoteMessage(message);

    if (payload.isForceUpdate) {
      if (fromBackground) {
        return;
      }

      try {
        await AppUpdateService.instance.applyPartialRemoteConfig(
          latestVersion: payload.latestVersion,
          minRequiredVersion: payload.minRequiredVersion,
          apkUrl: payload.apkUrl,
          forceUpdate: payload.forceUpdate,
        );
      } catch (e) {
        debugPrint('FCM: apply force-update config failed ($e)');
      }

      // Foreground FCM alerts are disabled, so show a local tray reminder.
      final title = payload.title;
      if (title != null && title.isNotEmpty) {
        await NotificationService.showForceUpdateNotification(
          title: title,
          body: payload.body ?? '',
        );
      }
      return;
    }

    await BackgroundSyncService.performBackgroundSync(
      showNotifications: false,
    );

    if (payload.isSilentSync) {
      return;
    }

    final osDisplayedNotification =
        fromBackground && message.notification != null;
    if (osDisplayedNotification) {
      return;
    }

    final title = payload.title;
    final body = payload.body;
    if (title == null || title.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alertsEnabled = prefs.getBool(prefNewContentAlertsEnabled) ?? true;
    if (!alertsEnabled) {
      return;
    }

    await NotificationService.showNewContentNotification(
      title: title,
      body: body ?? '',
      songId: payload.reference,
    );
  }

  static void _dispatchTap(RemoteMessage message) {
    final payload = PushPayload.fromRemoteMessage(message).toNotificationPayload();
    final handler = _tapHandler;
    if (handler != null) {
      handler(payload);
      return;
    }
    NotificationService.handleRemoteTap(payload);
  }

  static void _syncInitialToken() {
    Future.microtask(() async {
      try {
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

        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Device Token: $token');
          await _saveTokenToSupabase(token);
        }
      } catch (e) {
        debugPrint('Error syncing FCM initial token: $e');
      }
    });
  }

  /// Explicitly requests notification permission and syncs FCM token on user action (Web & Mobile).
  static Future<bool> requestPermissionAndSyncToken({String? userId}) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (isAuthorized) {
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveTokenToSupabase(token, userId: userId);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting FCM permission: $e');
      return false;
    }
  }

  static Future<void> updateUserToken(String? userId) async {
    try {
      if (kIsWeb) {
        final settings = await _messaging.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          return;
        }
      }
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
      if (kIsWeb) {
        final web = await _deviceInfoPlugin.webBrowserInfo;
        deviceInfo = {
          'id': 'web_${web.userAgent?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch}',
          'brand': web.browserName.name,
          'model': web.platform ?? 'Web Browser',
          'os': 'Web',
        };
      } else if (Platform.isAndroid) {
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
