import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio;
  Future<String?>? _refreshFuture;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.startsWith('/auth/')) {
      handler.next(options);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('accessToken');
    if (token != null && token.isNotEmpty && _expiresSoon(token)) {
      try {
        token = await _refreshAccessTokenOnce();
        if (token == null) {
          await _clearSession();
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Your session expired. Please sign in again.',
            ),
          );
          return;
        }
      } on DioException catch (error) {
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          await _clearSession();
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Your session expired. Please sign in again.',
            ),
          );
          return;
        }
        handler.reject(error);
        return;
      }
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final request = err.requestOptions;
    // Treat both 401 and 403 as a potentially expired token worth refreshing.
    // The backend returns 401 for missing/invalid tokens and 403 for forbidden.
    final statusCode = response?.statusCode;
    final isExpiredToken =
        (statusCode == 401 || statusCode == 403) &&
        !request.path.startsWith('/auth/') &&
        request.extra['authRetry'] != true;

    if (!isExpiredToken) {
      handler.next(err);
      return;
    }

    try {
      final token = await _refreshAccessTokenOnce();
      if (token == null) {
        await _clearSession();
        response?.data = {
          'code': 'SESSION_EXPIRED',
          'message': 'Your session expired. Please sign in again.',
        };
        handler.next(err);
        return;
      }

      request
        ..headers['Authorization'] = 'Bearer $token'
        ..extra['authRetry'] = true;
      final retryResponse = await _dio.fetch<dynamic>(request);
      handler.resolve(retryResponse);
    } on DioException catch (refreshError) {
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        await _clearSession();
        response?.data = {
          'code': 'SESSION_EXPIRED',
          'message': 'Your session expired. Please sign in again.',
        };
      }
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessTokenOnce() async {
    final currentRefresh = _refreshFuture;
    if (currentRefresh != null) return currentRefresh;

    final refresh = _refreshAccessToken();
    _refreshFuture = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshFuture, refresh)) {
        _refreshFuture = null;
      }
    }
  }

  bool _expiresSoon(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return true;

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map || payload['exp'] is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );
      return !expiresAt.isAfter(
        DateTime.now().add(const Duration(seconds: 15)),
      );
    } on FormatException {
      return true;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response =
        await Dio(
          BaseOptions(
            baseUrl: _dio.options.baseUrl,
            connectTimeout: _dio.options.connectTimeout,
            receiveTimeout: _dio.options.receiveTimeout,
            headers: const {'Content-Type': 'application/json'},
          ),
        ).post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
    final token = response.data?['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'The server did not return a refreshed access token.',
      );
    }
    await prefs.setString('accessToken', token);
    return token;
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
  }
}

class AccessTokenHeaderInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.startsWith('/auth/')) {
      handler.next(options);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

final dioProvider = Provider<Dio>((ref) {
  const String baseUrl = 'https://fitgoal-api-30nv.onrender.com/api';

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(dio));
  dio.interceptors.add(AccessTokenHeaderInterceptor());
  return dio;
});
