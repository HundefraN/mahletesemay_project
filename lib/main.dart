import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/providers/language_provider.dart';
import 'package:mahlete_semay_project/providers/service_reminder_provider.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'managers/download_manager.dart';
import 'providers/theme_provider.dart';
import 'providers/song_provider.dart';
import 'providers/vocal_progress_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/splash_wrapper.dart';
import 'services/notification_service.dart';
import 'services/pitch_service.dart';
import 'utils/app_themes.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'utils/constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onNotificationTap(String? payload) {
  if (payload == notificationPayloadVocalExercises) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: HomePageTab.exercises)),
          (route) => false,
    );
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  await NotificationService.initialize(onSelectNotification: onNotificationTap);

  runApp(const MyApp());
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
        ChangeNotifierProvider(create: (_) => ServiceReminderProvider()),
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
          return MaterialApp(
            title: 'Mahlete Semay',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode:
            themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: languageProvider.currentLocale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('am', ''),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashWrapper(),
          );
        },
      ),
    );
  }
}