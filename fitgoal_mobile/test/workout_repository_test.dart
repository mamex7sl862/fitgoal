import 'package:flutter_test/flutter_test.dart';
import 'package:fitgoal_mobile/features/workouts/data/workout_repository.dart';

void main() {
  test('routine day retains the coach fitness level', () {
    final day = RoutineDay.fromJson({
      'dayTitle': 'Day 1: Push',
      'isRestDay': false,
      'trainingLevel': 'ADVANCED',
      'primaryGoal': 'MUSCLE_GAIN',
      'planGuidance': 'Progress gradually.',
      'trainingWeek': 3,
      'completedSessionsInWeek': 2,
      'requiredSessionsPerWeek': 4,
      'completedPlanDaysInWeek': [0, 2],
      'exercises': [],
    });

    expect(day.trainingLevel, 'ADVANCED');
    expect(day.primaryGoal, 'MUSCLE_GAIN');
    expect(day.planGuidance, 'Progress gradually.');
    expect(day.trainingWeek, 3);
    expect(day.completedSessionsInWeek, 2);
    expect(day.requiredSessionsPerWeek, 4);
    expect(day.completedPlanDaysInWeek, [0, 2]);
  });

  test('routine exercise retains its saved custom plan marker', () {
    final exercise = RoutineExercise.fromJson({
      'id': 'exercise-1',
      'name': 'Lateral raise',
      'targetMuscle': 'Shoulders',
      'category': 'ISOLATION',
      'equipmentRequired': ['DUMBBELL'],
      'instructions': 'Raise the weights to the side.',
      'sets': 3,
      'reps': 12,
      'isCustomPlanExercise': true,
      'customPlanExerciseId': 'plan-exercise-1',
    });

    expect(exercise.isCustomPlanExercise, isTrue);
    expect(exercise.customPlanExerciseId, 'plan-exercise-1');
    expect(exercise.sets, 3);
    expect(exercise.reps, 12);
  });

  test('parses daily workout calorie progress', () {
    final progress = WorkoutCalorieProgress.fromJson({
      'todayCalories': 120,
      'weekCalories': 450,
      'allTimeCalories': 1200,
      'completedWorkouts': 8,
      'dailyCalories': [
        {'date': '2026-11-05T00:00:00.000Z', 'calories': 120},
      ],
    });

    expect(progress.todayCalories, 120);
    expect(progress.weekCalories, 450);
    expect(progress.allTimeCalories, 1200);
    expect(progress.completedWorkouts, 8);
    expect(progress.dailyCalories.single.calories, 120);
  });

  test('parses workout calorie history linked to completed exercises', () {
    final entry = WorkoutCalorieHistoryEntry.fromJson({
      'id': 'log-id',
      'completedAt': '2026-11-06T09:00:00.000Z',
      'durationMins': 45,
      'caloriesBurned': 210,
      'totalVolumeKg': '1250.5',
      'session': {
        'exercises': [
          {
            'exercise': {'name': 'Squat'},
          },
          {
            'exercise': {'name': 'Bench press'},
          },
        ],
      },
    });

    expect(entry.caloriesBurned, 210);
    expect(entry.totalVolumeKg, 1250.5);
    expect(entry.exerciseNames, ['Squat', 'Bench press']);
  });

  test('parses completed workout calories and coach messages', () {
    final completion = WorkoutCompletion.fromJson({
      'caloriesBurned': 125,
      'levelPromotion': {'message': 'New training level unlocked.'},
      'levelCheckMessage': null,
    });

    expect(completion.caloriesBurned, 125);
    expect(completion.levelPromotionMessage, 'New training level unlocked.');
  });

  test('maps completed workouts to matching plan days in the current week', () {
    final routine = [
      RoutineDay(
        dayTitle: 'Day 1: Push',
        isRestDay: false,
        exercises: [
          RoutineExercise(
            id: 'push-press',
            name: 'Press',
            targetMuscle: 'Chest',
            category: 'COMPOUND',
            equipmentRequired: const [],
            instructions: '',
          ),
        ],
      ),
      const RoutineDay(
        dayTitle: 'Day 2: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      const RoutineDay(
        dayTitle: 'Day 3: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      const RoutineDay(
        dayTitle: 'Day 4: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      const RoutineDay(
        dayTitle: 'Day 5: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      const RoutineDay(
        dayTitle: 'Day 6: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      RoutineDay(
        dayTitle: 'Day 7: Legs',
        isRestDay: false,
        exercises: [
          RoutineExercise(
            id: 'sunday-squat',
            name: 'Squat',
            targetMuscle: 'Legs',
            category: 'COMPOUND',
            equipmentRequired: const [],
            instructions: '',
          ),
        ],
      ),
    ];
    final history = [
      WorkoutHistoryEntry.fromJson({
        'id': 'day-one-finished-thursday',
        'startedAt': '2026-11-05T09:00:00.000Z',
        'endedAt': '2026-11-05T10:00:00.000Z',
        'exercises': [
          {
            'id': 'session-exercise',
            'targetSets': 1,
            'targetReps': 8,
            'exercise': {
              'id': 'push-press',
              'name': 'Press',
              'targetMuscle': 'Chest',
              'category': 'COMPOUND',
              'equipmentRequired': [],
              'instructions': '',
            },
            'sets': [],
          },
        ],
      }),
      WorkoutHistoryEntry.fromJson({
        'id': 'sunday',
        'startedAt': '2026-11-08T09:00:00.000Z',
        'endedAt': '2026-11-08T10:00:00.000Z',
        'exercises': [],
      }),
      WorkoutHistoryEntry.fromJson({
        'id': 'last-week',
        'startedAt': '2026-11-01T09:00:00.000Z',
        'endedAt': '2026-11-01T10:00:00.000Z',
        'exercises': [],
      }),
    ];

    expect(
      completedPlanDaysInCurrentWeek(
        routine,
        history,
        now: DateTime(2026, 11, 5, 12),
      ),
      {0, 6},
    );
  });

  test('selects the next unfinished training day and skips rest days', () {
    final routine = [
      RoutineDay(
        dayTitle: 'Day 1: Push',
        isRestDay: false,
        exercises: [
          RoutineExercise(
            id: 'press',
            name: 'Press',
            targetMuscle: 'Chest',
            category: 'COMPOUND',
            equipmentRequired: const [],
            instructions: '',
          ),
        ],
      ),
      const RoutineDay(
        dayTitle: 'Day 2: Recovery',
        isRestDay: true,
        exercises: [],
      ),
      RoutineDay(
        dayTitle: 'Day 3: Legs',
        isRestDay: false,
        exercises: [
          RoutineExercise(
            id: 'squat',
            name: 'Squat',
            targetMuscle: 'Legs',
            category: 'COMPOUND',
            equipmentRequired: const [],
            instructions: '',
          ),
        ],
      ),
    ];

    expect(nextPlannedWorkoutIndex(routine, {0}), 2);
    expect(nextPlannedWorkoutIndex(routine, {0, 2}), isNull);
  });

  group('workout JSON models', () {
    test('parses Prisma decimal strings in saved sets', () {
      final set = LoggedSet.fromJson({
        'setNumber': 1,
        'weightKg': '15',
        'reps': 10,
        'rpe': '8.0',
        'completed': true,
      });

      expect(set.weightKg, 15);
      expect(set.rpe, 8);
      expect(set.reps, 10);
    });

    test('parses saved workout session containing decimal strings', () {
      final session = WorkoutSession.fromJson({
        'id': 'session-id',
        'startedAt': '2026-11-04T10:00:00.000Z',
        'exercises': [
          {
            'id': 'workout-exercise-id',
            'targetSets': 3,
            'targetReps': 10,
            'exercise': {
              'id': 'exercise-id',
              'name': 'Bench press',
              'targetMuscle': 'Chest',
              'category': 'STRENGTH',
              'equipmentRequired': ['BARBELL'],
              'instructions': '',
              'recommendedWeightKg': '12.5',
            },
            'sets': [
              {
                'setNumber': 1,
                'weightKg': '15.5',
                'reps': 10,
                'rpe': '8.0',
                'completed': true,
              },
            ],
          },
        ],
      });

      expect(session.exercises.single.exercise.recommendedWeightKg, 12.5);
      expect(session.exercises.single.sets.single.weightKg, 15.5);
      expect(session.exercises.single.sets.single.rpe, 8);
    });

    test('parses completed workout history and calculates volume', () {
      final workout = WorkoutHistoryEntry.fromJson({
        'id': 'session-id',
        'startedAt': '2026-11-04T10:00:00.000Z',
        'endedAt': '2026-11-04T10:45:00.000Z',
        'exercises': [
          {
            'id': 'workout-exercise-id',
            'targetSets': 1,
            'targetReps': 8,
            'exercise': {
              'id': 'exercise-id',
              'name': 'Squat',
              'targetMuscle': 'Legs',
              'category': 'STRENGTH',
              'equipmentRequired': ['BARBELL'],
              'instructions': '',
            },
            'sets': [
              {'setNumber': 1, 'weightKg': '50', 'reps': 8, 'completed': true},
            ],
          },
        ],
      });

      expect(workout.durationMins, 45);
      expect(workout.totalVolumeKg, 400);
      expect(workout.exercises.single.exercise.name, 'Squat');
    });
  });
}
