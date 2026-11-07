import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitgoal_mobile/core/api_client.dart';

import 'goal_model.dart';

class GoalRepository {
  final Dio _dio;

  GoalRepository(this._dio);

  Future<GoalResponse?> loadSavedGoal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/goals/current');
      final responseData = response.data;
      if (responseData == null) {
        throw const FormatException('The saved plan response was empty.');
      }

      final savedGoal = GoalResponse.fromJson(responseData);
      final cachedGoal = _loadCachedGoal(prefs);
      final goal = _restoreLegacyFields(savedGoal, cachedGoal);
      final userId = goal.userId.isNotEmpty
          ? goal.userId
          : prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(
          'calculatedGoal_$userId',
          jsonEncode(goal.toJson()),
        );
      }
      return goal;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode < 500 && statusCode != 404) {
        final data = error.response?.data;
        final message = data is Map
            ? data['message']?.toString()
            : error.message;
        throw Exception(message ?? 'Failed to load your saved fitness plan.');
      }
      return _loadCachedGoal(prefs);
    }
  }

  GoalResponse _restoreLegacyFields(
    GoalResponse savedGoal,
    GoalResponse? cachedGoal,
  ) {
    if (cachedGoal == null || cachedGoal.userId != savedGoal.userId) {
      return savedGoal;
    }

    return GoalResponse(
      id: savedGoal.id,
      userId: savedGoal.userId,
      age: savedGoal.age > 0 ? savedGoal.age : cachedGoal.age,
      gender: savedGoal.gender.isNotEmpty
          ? savedGoal.gender
          : cachedGoal.gender,
      heightCm: savedGoal.heightCm > 0
          ? savedGoal.heightCm
          : cachedGoal.heightCm,
      fitnessLevel: savedGoal.fitnessLevel.isNotEmpty
          ? savedGoal.fitnessLevel
          : cachedGoal.fitnessLevel,
      weightKg: savedGoal.weightKg > 0
          ? savedGoal.weightKg
          : cachedGoal.weightKg,
      activityLevel: savedGoal.activityLevel.isNotEmpty
          ? savedGoal.activityLevel
          : cachedGoal.activityLevel,
      goal: savedGoal.goal.isNotEmpty ? savedGoal.goal : cachedGoal.goal,
      bmr: savedGoal.bmr > 0 ? savedGoal.bmr : cachedGoal.bmr,
      tdee: savedGoal.tdee > 0 ? savedGoal.tdee : cachedGoal.tdee,
      targetCalories: savedGoal.targetCalories > 0
          ? savedGoal.targetCalories
          : cachedGoal.targetCalories,
      proteinGrams: savedGoal.proteinGrams > 0
          ? savedGoal.proteinGrams
          : cachedGoal.proteinGrams,
      carbsGrams: savedGoal.carbsGrams > 0
          ? savedGoal.carbsGrams
          : cachedGoal.carbsGrams,
      fatsGrams: savedGoal.fatsGrams > 0
          ? savedGoal.fatsGrams
          : cachedGoal.fatsGrams,
    );
  }

  GoalResponse? _loadCachedGoal(SharedPreferences prefs) {
    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) return null;
    final savedGoal = prefs.getString('calculatedGoal_$userId');
    if (savedGoal == null) return null;

    final decoded = jsonDecode(savedGoal);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved goal data is invalid.');
    }
    return GoalResponse.fromJson(decoded);
  }

  Future<GoalResponse> createOrUpdateGoal({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String fitnessLevel,
    required String goal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please sign in again.');
      }

      final response = await _dio.post(
        '/goals/set-goal',
        data: {
          'primaryGoal': goal,
          'fitnessLevel': fitnessLevel,
          'currentWeightKg': weightKg,
          'age': age,
          'heightCm': heightCm,
          'gender': gender.toLowerCase(),
          'activityLevel': activityLevel.toLowerCase(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final goalResponse = GoalResponse.fromJson(response.data);
      final userId = goalResponse.userId.isNotEmpty
          ? goalResponse.userId
          : prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(
          'calculatedGoal_$userId',
          jsonEncode(goalResponse.toJson()),
        );
      }

      return goalResponse;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map
          ? data['message']?.toString() ??
                'Failed to process goal calculations.'
          : 'Failed to process goal calculations.';
      throw Exception(message);
    }
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return GoalRepository(dio);
});
