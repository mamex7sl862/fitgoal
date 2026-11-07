import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitgoal_mobile/features/coach/data/logger_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends only the habit field being changed, including false', () async {
    SharedPreferences.setMockInitialValues({'accessToken': 'test-token'});
    Map<String, dynamic>? sentData;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentData = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            handler.resolve(
              Response(requestOptions: options, data: <String, dynamic>{}),
            );
          },
        ),
      );
    final repository = LoggerRepository(dio);

    await repository.updateHabits(workoutCompleted: false);

    expect(sentData, {'workoutCompleted': false});
  });

  test('parses a saved meal history entry', () {
    final entry = MealHistoryEntry.fromJson({
      'id': 'meal-log',
      'name': 'Breakfast',
      'calories': 420,
      'protein': 28,
      'carbs': 45,
      'fats': 12,
      'loggedAt': '2026-11-06T08:30:00.000Z',
    });

    expect(entry.name, 'Breakfast');
    expect(entry.calories, 420);
    expect(entry.protein, 28);
    expect(entry.carbs, 45);
    expect(entry.fats, 12);
    expect(entry.loggedAt, DateTime.parse('2026-11-06T08:30:00.000Z'));
  });
}
