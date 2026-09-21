import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    // A sleeping free host can take ~1 minute to wake; don't give up on it.
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      handler.next(options);
    },
  ));

  // Retry reads that fail because the server is waking up or the network blipped.
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) async {
      final options = e.requestOptions;
      final retries = (options.extra['retries'] as int?) ?? 0;
      final transient = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
      if (options.method == 'GET' && transient && retries < 2) {
        await Future<void>.delayed(Duration(milliseconds: 800 * (retries + 1)));
        options.extra['retries'] = retries + 1;
        try {
          return handler.resolve(await dio.fetch<dynamic>(options));
        } on DioException catch (err) {
          return handler.next(err);
        }
      }
      handler.next(e);
    },
  ));

  return dio;
});

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
