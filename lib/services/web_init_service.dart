import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/supabase_config.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

/// Manages asynchronous service initialization for the web platform.
///
/// On web, we skip mobile-only services (FlutterNativeSplash, FcmService) but
/// still need Supabase, Firebase, and the timezone/notification layer since
/// providers reference them at construction time.
class WebInitService {
  WebInitService._();
  static final WebInitService instance = WebInitService._();

  final Completer<void> _ready = Completer<void>();

  /// Completes once all required services are initialized.
  Future<void> get ready => _ready.future;

  /// Whether initialization has completed.
  bool get isReady => _ready.isCompleted;

  /// Kicks off all web service initialization concurrently.
  /// Safe to call only once; subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_ready.isCompleted) return;

    try {
      try {
        await dotenv.load();
      } catch (_) {}

      // Initialize Supabase, Firebase, and notification layer concurrently with timeout guard.
      await Future.wait([
        Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        ),
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        NotificationService.initialize(),
      ]).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('WebInitService: initialization timed out, continuing startup');
          return [];
        },
      );

      _ready.complete();
    } catch (e, st) {
      debugPrint('WebInitService: initialization failed: $e\n$st');
      if (!_ready.isCompleted) {
        _ready.complete(); // Complete anyway so the app doesn't hang.
      }
    }
  }
}
