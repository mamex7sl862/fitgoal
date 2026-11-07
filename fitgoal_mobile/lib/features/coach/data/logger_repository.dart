import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';

class DailySummary {
  final List<dynamic> meals;
  final Map<String, dynamic> habit;

  DailySummary({required this.meals, required this.habit});

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(meals: json['meals'] ?? [], habit: json['habit'] ?? {});
  }
}

class MealHistoryEntry {
  const MealHistoryEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.loggedAt,
  });

  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final DateTime loggedAt;

  factory MealHistoryEntry.fromJson(Map<String, dynamic> json) {
    int number(Object? value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return MealHistoryEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Meal',
      calories: number(json['calories']),
      protein: number(json['protein']),
      carbs: number(json['carbs']),
      fats: number(json['fats']),
      loggedAt: DateTime.parse(json['loggedAt'].toString()),
    );
  }
}

class LoggerRepository {
  final Dio _dio;

  LoggerRepository(this._dio);

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<DailySummary> fetchDailySummary() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    final response = await _dio.get(
      '/logger/daily-summary',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return DailySummary.fromJson(response.data);
  }

  Future<List<MealHistoryEntry>> fetchMealHistory() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    final response = await _dio.get<List<dynamic>>(
      '/logger/history',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              MealHistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> logMeal({
    required String name,
    required int calories,
    int protein = 0,
    int carbs = 0,
    int fats = 0,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    await _dio.post(
      '/logger/meals',
      data: {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> updateHabits({
    bool? waterGoalMet,
    bool? workoutCompleted,
    bool? sleepGoalMet,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    final updates = <String, bool>{};
    if (waterGoalMet != null) updates['waterGoalMet'] = waterGoalMet;
    if (workoutCompleted != null) {
      updates['workoutCompleted'] = workoutCompleted;
    }
    if (sleepGoalMet != null) updates['sleepGoalMet'] = sleepGoalMet;

    await _dio.put(
      '/logger/habits',
      data: updates,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}

final loggerRepositoryProvider = Provider<LoggerRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LoggerRepository(dio);
});

final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>((
  ref,
) async {
  final repo = ref.watch(loggerRepositoryProvider);
  return repo.fetchDailySummary();
});

final mealHistoryProvider = FutureProvider.autoDispose<List<MealHistoryEntry>>((
  ref,
) {
  return ref.watch(loggerRepositoryProvider).fetchMealHistory();
});
