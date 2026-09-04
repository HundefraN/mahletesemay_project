import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Supabase project URL (reads from .env SUPABASE_URL or compile-time env or fallback)
  static String get url {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    }
    return const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://onsvnudakxkrqazrufar.supabase.co');
  }

  /// Supabase Anon/Public Key (reads from .env SUPABASE_ANON_KEY or compile-time env or fallback)
  static String get anonKey {
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (envKey != null && envKey.isNotEmpty) return envKey;
    }
    return const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uc3ZudWRha3hrcnFhenJ1ZmFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwNzYzNzQsImV4cCI6MjEwMjY1MjM3NH0.1U-gR05Ojn0FiHcmK8J4TOyloFw7dbHrQ0Y31bA8os4');
  }
}
