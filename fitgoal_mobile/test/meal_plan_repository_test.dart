import 'package:fitgoal_mobile/features/coach/data/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses daily plan meals and counts only eaten meals', () {
    final plan = DailyMealPlan.fromJson({
      'name': 'Personalized daily meal plan',
      'planDate': '2026-11-06T00:00:00.000Z',
      'targetKcal': 2000,
      'meals': [
        {
          'id': 'breakfast',
          'mealType': 'BREAKFAST',
          'title': 'Yogurt and oats',
          'recipe': 'Mix and serve.',
          'calories': 500,
          'protein': '30.0',
          'carbs': '60.0',
          'fats': '12.0',
          'mealLog': {
            'id': 'meal-log',
            'calories': 250,
            'protein': 15,
            'carbs': 30,
            'fats': 6,
          },
        },
        {
          'id': 'lunch',
          'mealType': 'LUNCH',
          'title': 'Chicken bowl',
          'recipe': 'Cook and serve.',
          'calories': 600,
          'protein': '40.0',
          'carbs': '70.0',
          'fats': '15.0',
          'mealLog': null,
        },
      ],
    });

    expect(plan.targetCalories, 2000);
    expect(plan.meals.first.eaten, isTrue);
    expect(plan.meals.last.eaten, isFalse);
    expect(plan.eatenCalories, 250);
    expect(plan.eatenProtein, 15);
    expect(plan.eatenCarbs, 30);
    expect(plan.eatenFats, 6);
  });

  test(
    'uses planned macros when a legacy eaten log has no recorded intake',
    () {
      final meal = PlannedMeal.fromJson({
        'id': 'breakfast',
        'mealType': 'BREAKFAST',
        'title': 'Yogurt and oats',
        'recipe': 'Mix and serve.',
        'calories': 500,
        'protein': '30.0',
        'carbs': '60.0',
        'fats': '12.0',
        'mealLog': {'id': 'legacy-log'},
      });

      expect(meal.eaten, isTrue);
      expect(meal.consumedCalories, 500);
      expect(meal.consumedProtein, 30);
      expect(meal.consumedCarbs, 60);
      expect(meal.consumedFats, 12);
    },
  );
}
