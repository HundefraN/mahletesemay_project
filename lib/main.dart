import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/providers/language_provider.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/song_provider.dart';
import 'providers/vocal_progress_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/splash_wrapper.dart';
import 'services/notification_service.dart';
import 'utils/app_themes.dart';
import 'widgets/network_aware.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onNotificationTap(String? payload) {
  if (payload == 'vocal_exercises') {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 1)),
          (route) => false,
    );
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize(onSelectNotification: onNotificationTap);

  FlutterNativeSplash.remove();
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

            home: const NetworkAware(child: SplashWrapper()),
          );
        },
      ),
    );
  }
}