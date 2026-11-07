import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitgoal_mobile/core/api_client.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  // 1. LOGIN
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      // Save tokens to local storage
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'accessToken',
        response.data['accessToken'].toString(),
      );

      await prefs.setString(
        'refreshToken',
        response.data['refreshToken'].toString(),
      );

      await prefs.setString('userId', response.data['userId'].toString());

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message'] ??
                'Login failed. Please check your credentials.'
          : 'Login failed. Please check your credentials.';

      throw Exception(message);
    }
  }

  // 2. SIGN UP
  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      // Save tokens to local storage
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'accessToken',
        response.data['accessToken'].toString(),
      );

      await prefs.setString(
        'refreshToken',
        response.data['refreshToken'].toString(),
      );

      await prefs.setString('userId', response.data['userId'].toString());

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['message'] ?? 'Signup failed. Please try again.'
          : 'Signup failed. Please try again.';

      throw Exception(message);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/account/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map && responseData['message'] is String
          ? responseData['message'] as String
          : 'Unable to change your password. Please try again.';
      throw Exception(message);
    }
  }

  // 3. LOGOUT
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

// Provide AuthRepository globally via Riverpod
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});
