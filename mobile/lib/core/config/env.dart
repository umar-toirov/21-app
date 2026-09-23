import 'package:flutter/foundation.dart';

class AppConfig {
  static const appName = 'Habit Zone';

  static const _apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/v1',
  );

  /// On web, use same-origin `/v1` only when served through the local proxy
  /// (ports 8090/8100). Otherwise use API_BASE_URL from env (Chrome dev mode).
  static String get apiBaseUrl {
    if (kIsWeb) {
      final base = Uri.base;
      final port = base.hasPort ? base.port : (base.scheme == 'https' ? 443 : 80);
      if (port == 8090 || port == 8100) {
        return '${base.origin}/v1';
      }
    }
    return _apiBaseUrlDefine;
  }

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  /// Mobile deep link for Supabase OAuth return.
  static const authCallbackPath = '/auth/callback';
}
