import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cache/app_cache.dart';
import 'core/config/env.dart';
import 'core/services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Path URLs (not /#/...) so email links can return to /auth/callback.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Start waking the API right away (a free host sleeps when idle) while
  // everything else initialises. Failure is fine; real requests retry.
  unawaited(
    Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    )).get<dynamic>('${AppConfig.apiBaseUrl}/health').then((_) {}, onError: (_) {}),
  );

  await AppCache.init();
  await SoundService.instance.load();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await loadSavedThemeMode();

  runApp(const ProviderScope(child: IlmModeApp()));
}
