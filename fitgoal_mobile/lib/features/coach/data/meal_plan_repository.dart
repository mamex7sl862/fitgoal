import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.type,
    required this.title,
    required this.recipe,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.eaten,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFats,
  });

  final String id;
  final String type;
  final String title;
  final String recipe;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final bool eaten;
  final int consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFats;

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    final log = json['mealLog'] is Map
        ? Map<String, dynamic>.from(json['mealLog'] as Map)
        : null;
    return PlannedMeal(
      id: json['id']?.toString() ?? '',
      type: json['mealType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      recipe: json['recipe']?.toString() ?? '',
      calories: _number(json['calories']).round(),
      protein: _number(json['protein']),
      carbs: _number(json['carbs']),
      fats: _number(json['fats']),
      eaten: log != null,
      consumedCalories: _number(log?['calories'] ?? json['calories']).round(),
      consumedProtein: _number(log?['protein'] ?? json['protein']),
      consumedCarbs: _number(log?['carbs'] ?? json['carbs']),
      consumedFats: _number(log?['fats'] ?? json['fats']),
    );
  }
}

class DailyMealPlan {
  const DailyMealPlan({
    required this.name,
    required this.planDate,
    required this.targetCalories,
    required this.meals,
  });

  final String name;
  final DateTime planDate;
  final int targetCalories;
  final List<PlannedMeal> meals;

  int get eatenCalories => meals
      .where((meal) => meal.eaten)
      .fold(0, (total, meal) => total + meal.consumedCalories);

  double get eatenProtein => meals
      .where((meal) => meal.eaten)
      .fold(0, (total, meal) => total + meal.consumedProtein);

  double get eatenCarbs => meals
      .where((meal) => meal.eaten)
      .fold(0, (total, meal) => total + meal.consumedCarbs);

  double get eatenFats => meals
      .where((meal) => meal.eaten)
      .fold(0, (total, meal) => total + meal.consumedFats);

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) => DailyMealPlan(
    name: json['name']?.toString() ?? 'Daily meal plan',
    planDate: DateTime.parse(json['planDate'].toString()),
    targetCalories: _number(json['targetKcal']).round(),
    meals: (json['meals'] as List? ?? [])
        .map(
          (item) =>
              PlannedMeal.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class MealPlanRepository {
  MealPlanRepository(this._dio);

  final Dio _dio;

  Future<DailyMealPlan> fetchToday() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _dio.get<Map<String, dynamic>>(
      '/meals/today',
      queryParameters: {'date': today},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('The meal plan response was empty.');
    }
    return DailyMealPlan.fromJson(data);
  }

  Future<void> setEaten({
    required String mealId,
    required bool eaten,
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
  }) async {
    await _dio.patch(
      '/meals/$mealId',
      data: {
        'eaten': eaten,
        'calories': ?calories,
        'protein': ?protein,
        'carbs': ?carbs,
        'fats': ?fats,
      },
    );
  }
}

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(ref.watch(dioProvider));
});

final dailyMealPlanProvider = FutureProvider.autoDispose<DailyMealPlan>((ref) {
  return ref.watch(mealPlanRepositoryProvider).fetchToday();
});
