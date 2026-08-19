import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Supabase project URL (reads from .env SUPABASE_URL or compile-time env or fallback)
  static String get url {
    return dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://xyzcompany.supabase.co');
  }

  /// Supabase Anon/Public Key (reads from .env SUPABASE_ANON_KEY or compile-time env or fallback)
  static String get anonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_anon_key_placeholder');
  }
}
