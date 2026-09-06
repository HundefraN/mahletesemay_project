import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/providers/language_provider.dart';
import 'package:mahlete_semay_project/providers/notification_settings_provider.dart';
import 'package:mahlete_semay_project/providers/service_reminder_provider.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';
import 'package:mahlete_semay_project/screens/settings/service_reminder_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localizations_delegate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'managers/download_manager.dart';
import 'providers/theme_provider.dart';
import 'providers/song_provider.dart';
import 'providers/vocal_progress_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/splash_wrapper.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/pitch_service.dart';
import 'services/supabase_service.dart';
import 'utils/app_themes.dart';
import 'utils/constants.dart';
import 'dart:async';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/foundation.dart';
import 'screens/reminders/alarm_overlay_screen.dart';
import 'services/alarm_service.dart';
import 'services/background_sync_service.dart';
import 'utils/timeago_utils.dart';
import 'services/web_init_service.dart';
import 'utils/web_scroll_behavior.dart';
import 'screens/update/app_update_wrapper.dart';
import 'services/app_update_service.dart';
import 'services/crash_report_service.dart';
import 'services/usage_analytics_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Synchronous, instant — safe before any async work.
  setupTimeAgoLocales();
  CrashReportService.install();

  if (kIsWeb) {
    // ── Web: skip all mobile-only overhead ───────────────────────────────────
    // No FlutterNativeSplash, no NotificationService, no FcmService.
    // Just initialize Supabase + Firebase (required by providers) and go.
    await WebInitService.instance.initialize();
    unawaited(UsageAnalyticsService.instance.recordVisit());
    runApp(const MyApp());
  } else {
    // ── Mobile: keep the existing blocking flow ─────────────────────────────
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    try {
      await dotenv.load();
    } catch (_) {
      // .env file is optional
    }

    // Initialize core client backends and alarm/notification channels swiftly
    await Future.wait([
      Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      ),
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      NotificationService.initialize().timeout(const Duration(milliseconds: 2000), onTimeout: () {}),
      AlarmService.initialize().timeout(const Duration(milliseconds: 2000), onTimeout: () {}),
    ]);

    // Must be registered before runApp so killed-state FCM can spawn the isolate.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Non-blocking background workers & push notifications
    FcmService.initialize();
    unawaited(BackgroundSyncService.initialize());
    unawaited(UsageAnalyticsService.instance.recordVisit());

    // Local version + last known release, so an already-updated device never
    // flashes the lock screen while the first network check is in flight.
    try {
      await AppUpdateService.instance.hydrate();
    } catch (e, st) {
      debugPrint('[main] AppUpdateService.hydrate failed: $e\n$st');
    }

    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(create: (_) => VocalProgressProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DownloadManager()),
        ChangeNotifierProvider(create: (_) => SetlistProvider()),
        ChangeNotifierProvider(create: (_) => PitchService()),
        // Both providers re-apply their notification schedules on creation so
        // reminders survive reinstalls, reboots and timezone changes.
        ChangeNotifierProvider(
          create: (_) => ServiceReminderProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationSettingsProvider()..refresh(),
        ),
        ChangeNotifierProxyProvider2<SongProvider, AuthProvider, StatsProvider>(
          create: (context) => StatsProvider(
              Provider.of<SongProvider>(context, listen: false),
              Provider.of<AuthProvider>(context, listen: false)),
          update: (context, songProvider, authProvider, previous) =>
              StatsProvider(songProvider, authProvider),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return NotificationCoordinator(
            child: ScrollConfiguration(
              behavior: kIsWeb ? WebScrollBehavior() : const MaterialScrollBehavior(),
              child: MaterialApp(
              title: 'Mahlete Semay',
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: scaffoldMessengerKey,
              debugShowCheckedModeBanner: false,
              theme: AppThemes.lightTheme,
              darkTheme: AppThemes.darkTheme,
              themeMode:
                  themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              locale: languageProvider.currentLocale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FallbackMaterialLocalizationsDelegate(),
                FallbackCupertinoLocalizationsDelegate(),
              ],
              home: const SplashWrapper(),
              builder: (context, child) {
                return GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: RepairModeWrapper(
                    child: AppUpdateWrapper(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Connects the notification layer to the widget tree: routes taps once a
/// navigator exists, and re-checks notification access whenever the app is
/// brought back to the foreground.
class NotificationCoordinator extends StatefulWidget {
  const NotificationCoordinator({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationCoordinator> createState() =>
      _NotificationCoordinatorState();
}

class _NotificationCoordinatorState extends State<NotificationCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<ServiceAlarmMetadata>? _alarmSubscription;
  bool _isAlarmOverlayShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Routing needs a mounted navigator, so taps are only handled from the
    // first frame onwards. A tap that cold-starts the app is replayed by
    // NotificationService as soon as the handler is registered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.setTapHandler(_handleNotificationTap);
      FcmService.setTapHandler(_handleNotificationTap);
      _checkActiveRingingAlarm();
    });

    if (!kIsWeb) {
      _alarmSubscription = AlarmService.onAlarmRinging.listen((meta) {
        final navigator = navigatorKey.currentState;
        if (navigator != null && navigator.mounted && !_isAlarmOverlayShowing) {
          _isAlarmOverlayShowing = true;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => AlarmOverlayScreen(metadata: meta),
            ),
          ).then((_) {
            _isAlarmOverlayShowing = false;
          });
        }
      });
    }
  }

  Future<void> _checkActiveRingingAlarm() async {
    if (kIsWeb || _isAlarmOverlayShowing) return;
    try {
      final activeAlarm = await AlarmService.getCurrentlyRingingAlarm();
      if (activeAlarm != null) {
        final navigator = navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          _isAlarmOverlayShowing = true;
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => AlarmOverlayScreen(metadata: activeAlarm),
            ),
          );
          _isAlarmOverlayShowing = false;
        }
      }
    } catch (e) {
      debugPrint('NotificationCoordinator: error checking active alarm: $e');
    }
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Notification access may have been changed in system settings while the
    // app was in the background. Also check for remote app updates and active alarms.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationSettingsProvider>().refreshPermission();
      AppUpdateService.instance.onAppResumed();
      unawaited(UsageAnalyticsService.instance.recordVisit());
      _checkActiveRingingAlarm();
    }
  }

  Future<void> _handleNotificationTap(NotificationPayload payload) async {
    // Delay slightly so cold-start route transitions complete cleanly before navigating.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;

    switch (payload.kind) {
      case NotificationKind.dailyPractice:
      case NotificationKind.practiceContinuation:
      case NotificationKind.test:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(initialTab: HomePageTab.lyrics),
          ),
          (route) => false,
        );
      case NotificationKind.newContent:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(initialTab: HomePageTab.lyrics),
          ),
          (route) => false,
        );
      case NotificationKind.forceUpdate:
        unawaited(AppUpdateService.instance.checkForUpdate());
      case NotificationKind.serviceReminder:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        navigator.push(
          MaterialPageRoute(builder: (_) => const ServiceReminderScreen()),
        );
      case NotificationKind.serviceAlarmOverlay:
        final reminderId = payload.reference ?? 'reminder';
        final meta = ServiceAlarmMetadata(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          reminderId: reminderId,
          title: 'Worship Service Alarm',
          body: 'Your scheduled worship service is starting now.',
          serviceDateTime: DateTime.now(),
        );
        navigator.push(
          MaterialPageRoute(
            builder: (_) => AlarmOverlayScreen(metadata: meta),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wraps the entire app and listens to repair mode status.
class RepairModeWrapper extends StatelessWidget {
  final Widget child;
  const RepairModeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    
    final l10n = AppLocalizations.of(context);
    
    return StreamBuilder<bool>(
      stream: SupabaseService().getRepairModeStream(),
      initialData: SupabaseService().lastKnownRepairMode,
      builder: (context, snapshot) {
        final isRepairMode = snapshot.data ?? false;
        
        // If not in repair mode, or if user is an admin, show the app normally
        if (!isRepairMode || authProvider.isAdmin) {
          return child;
        }

        // Show Maintenance Screen
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_circle_rounded, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    l10n?.underMaintenance ?? 'We are under maintenance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.maintenanceDesc ??
                        'The Mahlete Semay app is currently in repair mode. We are working hard to bring it back online shortly. Thank you for your patience!',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
