import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';

int? _jsonInt(Object? value, {required String field}) {
  if (value == null) return null;
  final number = value is num ? value : num.tryParse(value.toString());
  if (number == null || number % 1 != 0) {
    throw FormatException('Expected an integer for "$field".');
  }
  return number.toInt();
}

double? _jsonDouble(Object? value, {required String field}) {
  if (value == null) return null;
  final number = value is num ? value : num.tryParse(value.toString());
  if (number == null || !number.isFinite) {
    throw FormatException('Expected a number for "$field".');
  }
  return number.toDouble();
}

@immutable
class WorkoutRequest {
  const WorkoutRequest({
    this.daysPerWeek = 4,
    this.availableEquipment = const [],
  });

  final int daysPerWeek;
  final List<String> availableEquipment;

  @override
  bool operator ==(Object other) =>
      other is WorkoutRequest &&
      other.daysPerWeek == daysPerWeek &&
      listEquals(other.availableEquipment, availableEquipment);

  @override
  int get hashCode =>
      Object.hash(daysPerWeek, Object.hashAll(availableEquipment));
}

class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.category,
    required this.equipmentRequired,
    required this.instructions,
    this.gifUrl,
    this.sets = 3,
    this.reps = 10,
    this.recommendedWeightKg,
    this.recommendationReason,
    this.previousSets = const [],
    this.isCustomPlanExercise = false,
    this.customPlanExerciseId,
  });

  final String id;
  final String name;
  final String targetMuscle;
  final String category;
  final List<String> equipmentRequired;
  final String instructions;
  final String? gifUrl;
  final int sets;
  final int reps;
  final double? recommendedWeightKg;
  final String? recommendationReason;
  final List<LoggedSet> previousSets;
  final bool isCustomPlanExercise;
  final String? customPlanExerciseId;

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final previousSets = json['previousSets'];
    return RoutineExercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      targetMuscle: json['targetMuscle']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      equipmentRequired: (json['equipmentRequired'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      instructions: json['instructions']?.toString() ?? '',
      gifUrl: json['gifUrl']?.toString(),
      sets: _jsonInt(json['sets'], field: 'sets') ?? 3,
      reps: _jsonInt(json['reps'], field: 'reps') ?? 10,
      recommendedWeightKg: _jsonDouble(
        json['recommendedWeightKg'],
        field: 'recommendedWeightKg',
      ),
      recommendationReason: json['recommendationReason']?.toString(),
      previousSets: (previousSets as List? ?? [])
          .map(
            (item) =>
                LoggedSet.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      isCustomPlanExercise: json['isCustomPlanExercise'] == true,
      customPlanExerciseId: json['customPlanExerciseId']?.toString(),
    );
  }
}

class RoutineDay {
  const RoutineDay({
    required this.dayTitle,
    required this.isRestDay,
    required this.exercises,
    this.trainingLevel = 'INTERMEDIATE',
    this.primaryGoal = '',
    this.planGuidance = '',
    this.trainingWeek = 1,
    this.completedSessionsInWeek = 0,
    this.requiredSessionsPerWeek = 4,
    this.completedPlanDaysInWeek = const [],
  });

  final String dayTitle;
  final bool isRestDay;
  final List<RoutineExercise> exercises;
  final String trainingLevel;
  final String primaryGoal;
  final String planGuidance;
  final int trainingWeek;
  final int completedSessionsInWeek;
  final int requiredSessionsPerWeek;
  final List<int> completedPlanDaysInWeek;

  factory RoutineDay.fromJson(Map<String, dynamic> json) {
    return RoutineDay(
      dayTitle: json['dayTitle']?.toString() ?? '',
      isRestDay: json['isRestDay'] == true,
      trainingLevel: json['trainingLevel']?.toString() ?? 'INTERMEDIATE',
      primaryGoal: json['primaryGoal']?.toString() ?? '',
      planGuidance: json['planGuidance']?.toString() ?? '',
      trainingWeek: _jsonInt(json['trainingWeek'], field: 'trainingWeek') ?? 1,
      completedSessionsInWeek:
          _jsonInt(
            json['completedSessionsInWeek'],
            field: 'completedSessionsInWeek',
          ) ??
          0,
      requiredSessionsPerWeek:
          _jsonInt(
            json['requiredSessionsPerWeek'],
            field: 'requiredSessionsPerWeek',
          ) ??
          4,
      completedPlanDaysInWeek: (json['completedPlanDaysInWeek'] as List? ?? [])
          .map((index) => _jsonInt(index, field: 'completedPlanDaysInWeek'))
          .whereType<int>()
          .toList(),
      exercises: (json['exercises'] as List? ?? [])
          .map(
            (item) => RoutineExercise.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
    required this.nextCursor,
  });

  final List<RoutineExercise> items;
  final int page;
  final bool hasMore;
  final int total;
  final String? nextCursor;

  factory ExercisePage.fromJson(Map<String, dynamic> json) => ExercisePage(
    items: (json['items'] as List? ?? [])
        .map(
          (item) =>
              RoutineExercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    page: _jsonInt(json['page'], field: 'page') ?? 1,
    hasMore: json['hasMore'] == true,
    total: _jsonInt(json['total'], field: 'total') ?? 0,
    nextCursor: json['nextCursor']?.toString(),
  );
}

class LoggedSet {
  const LoggedSet({
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.completed = true,
  });

  final int setNumber;
  final double weightKg;
  final int reps;
  final double? rpe;
  final bool completed;

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    setNumber: _jsonInt(json['setNumber'], field: 'setNumber') ?? 0,
    weightKg: _jsonDouble(json['weightKg'], field: 'weightKg') ?? 0,
    reps: _jsonInt(json['reps'], field: 'reps') ?? 0,
    rpe: _jsonDouble(json['rpe'], field: 'rpe'),
    completed: json['completed'] != false,
  );
}

class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.exercise,
    required this.targetSets,
    required this.targetReps,
    required this.sets,
  });

  final String id;
  final RoutineExercise exercise;
  final int targetSets;
  final int targetReps;
  final List<LoggedSet> sets;

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        id: json['id']?.toString() ?? '',
        exercise: RoutineExercise.fromJson(
          Map<String, dynamic>.from(json['exercise'] as Map),
        ),
        targetSets: _jsonInt(json['targetSets'], field: 'targetSets') ?? 3,
        targetReps: _jsonInt(json['targetReps'], field: 'targetReps') ?? 10,
        sets: (json['sets'] as List? ?? [])
            .map(
              (item) =>
                  LoggedSet.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.exercises,
  });

  final String id;
  final DateTime startedAt;
  final List<SessionExercise> exercises;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id']?.toString() ?? '',
    startedAt:
        DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
        DateTime.now(),
    exercises: (json['exercises'] as List? ?? [])
        .map(
          (item) =>
              SessionExercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class WorkoutCompletion {
  const WorkoutCompletion({
    this.levelPromotionMessage,
    this.levelCheckMessage,
    this.caloriesBurned,
  });

  final String? levelPromotionMessage;
  final String? levelCheckMessage;
  final int? caloriesBurned;

  factory WorkoutCompletion.fromJson(Map<String, dynamic> json) {
    final promotion = json['levelPromotion'];
    return WorkoutCompletion(
      levelPromotionMessage: promotion is Map
          ? promotion['message']?.toString()
          : null,
      levelCheckMessage: json['levelCheckMessage']?.toString(),
      caloriesBurned: _jsonInt(json['caloriesBurned'], field: 'caloriesBurned'),
    );
  }
}

class DailyWorkoutCalories {
  const DailyWorkoutCalories({required this.date, required this.calories});

  final DateTime date;
  final int calories;

  factory DailyWorkoutCalories.fromJson(Map<String, dynamic> json) =>
      DailyWorkoutCalories(
        date: DateTime.parse(json['date'].toString()),
        calories: _jsonInt(json['calories'], field: 'calories') ?? 0,
      );
}

class WorkoutCalorieProgress {
  const WorkoutCalorieProgress({
    required this.todayCalories,
    required this.weekCalories,
    required this.allTimeCalories,
    required this.completedWorkouts,
    required this.dailyCalories,
  });

  final int todayCalories;
  final int weekCalories;
  final int allTimeCalories;
  final int completedWorkouts;
  final List<DailyWorkoutCalories> dailyCalories;

  factory WorkoutCalorieProgress.fromJson(
    Map<String, dynamic> json,
  ) => WorkoutCalorieProgress(
    todayCalories: _jsonInt(json['todayCalories'], field: 'todayCalories') ?? 0,
    weekCalories: _jsonInt(json['weekCalories'], field: 'weekCalories') ?? 0,
    allTimeCalories:
        _jsonInt(json['allTimeCalories'], field: 'allTimeCalories') ?? 0,
    completedWorkouts:
        _jsonInt(json['completedWorkouts'], field: 'completedWorkouts') ?? 0,
    dailyCalories: (json['dailyCalories'] as List? ?? [])
        .map(
          (item) => DailyWorkoutCalories.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
  );
}

class WorkoutCalorieHistoryEntry {
  const WorkoutCalorieHistoryEntry({
    required this.id,
    required this.completedAt,
    required this.durationMins,
    required this.caloriesBurned,
    required this.totalVolumeKg,
    required this.exerciseNames,
  });

  final String id;
  final DateTime completedAt;
  final int durationMins;
  final int caloriesBurned;
  final double totalVolumeKg;
  final List<String> exerciseNames;

  factory WorkoutCalorieHistoryEntry.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    final exercises = session is Map ? session['exercises'] as List? ?? [] : [];
    return WorkoutCalorieHistoryEntry(
      id: json['id']?.toString() ?? '',
      completedAt: DateTime.parse(json['completedAt'].toString()),
      durationMins: _jsonInt(json['durationMins'], field: 'durationMins') ?? 0,
      caloriesBurned:
          _jsonInt(json['caloriesBurned'], field: 'caloriesBurned') ?? 0,
      totalVolumeKg:
          _jsonDouble(json['totalVolumeKg'], field: 'totalVolumeKg') ?? 0,
      exerciseNames: exercises
          .whereType<Map>()
          .map((item) {
            final exercise = item['exercise'];
            return exercise is Map ? exercise['name']?.toString() ?? '' : '';
          })
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }
}

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationMins,
    required this.exercises,
    required this.totalVolumeKg,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMins;
  final List<SessionExercise> exercises;
  final double totalVolumeKg;

  factory WorkoutHistoryEntry.fromJson(Map<String, dynamic> json) {
    final startedAt =
        DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
        DateTime.now();
    final endedAt = DateTime.tryParse(json['endedAt']?.toString() ?? '');
    final exercises = (json['exercises'] as List? ?? [])
        .map(
          (item) =>
              SessionExercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final totalVolumeKg = exercises.fold<double>(
      0,
      (total, exercise) =>
          total +
          exercise.sets.fold<double>(
            0,
            (exerciseTotal, set) => exerciseTotal + set.weightKg * set.reps,
          ),
    );

    return WorkoutHistoryEntry(
      id: json['id']?.toString() ?? '',
      startedAt: startedAt,
      endedAt: endedAt,
      durationMins:
          _jsonInt(json['durationMins'], field: 'durationMins') ??
          (endedAt == null ? 0 : endedAt.difference(startedAt).inMinutes),
      exercises: exercises,
      totalVolumeKg:
          _jsonDouble(json['totalVolumeKg'], field: 'totalVolumeKg') ??
          totalVolumeKg,
    );
  }
}

class ExerciseHistory {
  const ExerciseHistory({
    required this.previousSets,
    required this.recommendedWeightKg,
    required this.recommendationReason,
  });

  final List<LoggedSet> previousSets;
  final double? recommendedWeightKg;
  final String recommendationReason;

  factory ExerciseHistory.fromJson(Map<String, dynamic> json) =>
      ExerciseHistory(
        previousSets: (json['previousSets'] as List? ?? [])
            .map(
              (item) =>
                  LoggedSet.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        recommendedWeightKg: _jsonDouble(
          json['recommendedWeightKg'],
          field: 'recommendedWeightKg',
        ),
        recommendationReason: json['recommendationReason']?.toString() ?? '',
      );
}

Set<int> completedPlanDaysInCurrentWeek(
  List<RoutineDay> routine,
  List<WorkoutHistoryEntry> history, {
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));
  final completedDays = <int>{};
  final plannedDays = <int, Set<String>>{
    for (var index = 0; index < routine.length; index++)
      if (!routine[index].isRestDay)
        index: routine[index].exercises.map((exercise) => exercise.id).toSet(),
  };

  for (final workout in history) {
    final completedAt = (workout.endedAt ?? workout.startedAt).toLocal();
    final workoutDate = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );
    if (!workoutDate.isBefore(weekStart) && !workoutDate.isAfter(weekEnd)) {
      final sessionExercises = workout.exercises
          .map((exercise) => exercise.exercise.id)
          .toSet();
      final weekday = workoutDate.weekday - 1;
      final candidates =
          plannedDays.entries
              .where((entry) => !completedDays.contains(entry.key))
              .map((entry) {
                final overlap = entry.value
                    .intersection(sessionExercises)
                    .length;
                return (dayIndex: entry.key, overlap: overlap);
              })
              .toList()
            ..sort((a, b) {
              final overlapOrder = b.overlap.compareTo(a.overlap);
              if (overlapOrder != 0) return overlapOrder;
              return (a.dayIndex - weekday).abs().compareTo(
                (b.dayIndex - weekday).abs(),
              );
            });

      if (candidates.isNotEmpty && candidates.first.overlap > 0) {
        completedDays.add(candidates.first.dayIndex);
      } else if (plannedDays.containsKey(weekday) &&
          !completedDays.contains(weekday)) {
        completedDays.add(weekday);
      }
    }
  }

  return completedDays;
}

int? nextPlannedWorkoutIndex(
  List<RoutineDay> routine,
  Set<int> completedDays, {
  DateTime? now,
}) {
  // Start from today's weekday (0=Mon … 6=Sun) and search forward,
  // then wrap around so the closest upcoming session is shown first.
  final todayIndex = ((now ?? DateTime.now()).weekday - 1) % 7;
  final length = routine.length;

  for (var offset = 0; offset < length; offset++) {
    final index = (todayIndex + offset) % length;
    final day = routine[index];
    if (!day.isRestDay &&
        day.exercises.isNotEmpty &&
        !completedDays.contains(index)) {
      return index;
    }
  }
  return null; // all training days completed this week
}

List<WorkoutHistoryEntry> workoutsCompletedOnDate(
  List<WorkoutHistoryEntry> history, {
  DateTime? date,
}) {
  final localDate = (date ?? DateTime.now()).toLocal();
  return history.where((workout) {
    final completedAt = (workout.endedAt ?? workout.startedAt).toLocal();
    return completedAt.year == localDate.year &&
        completedAt.month == localDate.month &&
        completedAt.day == localDate.day;
  }).toList();
}

class WorkoutRepository {
  WorkoutRepository(this._dio);

  final Dio _dio;

  String mediaUrlFor(RoutineExercise exercise) =>
      '${_dio.options.baseUrl}/animated-exercises/${Uri.encodeComponent(exercise.id)}/media';

  Future<Options> _authorizedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<RoutineDay>> fetchWeeklyRoutine(WorkoutRequest request) async {
    final response = await _dio.post(
      '/workouts/generate',
      data: {
        'daysPerWeek': request.daysPerWeek,
        'availableEquipment': request.availableEquipment,
      },
      options: await _authorizedOptions(),
    );
    final responseData = Map<String, dynamic>.from(response.data as Map);
    final fitnessLevel =
        responseData['fitnessLevel']?.toString() ?? 'INTERMEDIATE';
    final primaryGoal = responseData['primaryGoal']?.toString() ?? '';
    final planGuidance = responseData['planGuidance']?.toString() ?? '';
    final trainingWeek =
        _jsonInt(responseData['trainingWeek'], field: 'trainingWeek') ?? 1;
    final completedSessionsInWeek =
        _jsonInt(
          responseData['completedSessionsInWeek'],
          field: 'completedSessionsInWeek',
        ) ??
        0;
    final requiredSessionsPerWeek =
        _jsonInt(
          responseData['requiredSessionsPerWeek'],
          field: 'requiredSessionsPerWeek',
        ) ??
        request.daysPerWeek;
    return (responseData['weeklyRoutine'] as List)
        .map(
          (item) => RoutineDay.fromJson({
            ...Map<String, dynamic>.from(item as Map),
            'trainingLevel': fitnessLevel,
            'primaryGoal': primaryGoal,
            'planGuidance': planGuidance,
            'trainingWeek': trainingWeek,
            'completedSessionsInWeek': completedSessionsInWeek,
            'requiredSessionsPerWeek': requiredSessionsPerWeek,
          }),
        )
        .toList();
  }

  Future<int> addExercisesToPlanDay({
    required int daysPerWeek,
    required int dayIndex,
    required List<RoutineExercise> exercises,
  }) async {
    final response = await _dio.post(
      '/workouts/plan/day-exercises',
      data: {
        'daysPerWeek': daysPerWeek,
        'dayIndex': dayIndex,
        'exercises': exercises
            .map(
              (exercise) => {
                'exerciseId': exercise.id,
                'targetSets': exercise.sets,
                'targetReps': exercise.reps,
              },
            )
            .toList(),
      },
      options: await _authorizedOptions(),
    );
    final responseData = Map<String, dynamic>.from(response.data as Map);
    return _jsonInt(responseData['addedCount'], field: 'addedCount') ?? 0;
  }

  Future<void> removeCustomPlanExercise(String customPlanExerciseId) async {
    await _dio.delete(
      '/workouts/plan/day-exercises/$customPlanExerciseId',
      options: await _authorizedOptions(),
    );
  }

  Future<ExercisePage> searchExercises({
    required String search,
    required List<String> muscles,
    required List<String> equipment,
    String? cursor,
    int pageSize = 30,
  }) async {
    final response = await _dio.get(
      '/animated-exercises',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (muscles.isNotEmpty) 'muscle': muscles.join(','),
        if (equipment.isNotEmpty) 'equipment': equipment.join(','),
        'cursor': ?cursor,
        'pageSize': pageSize > 25 ? 25 : pageSize,
      },
      options: await _authorizedOptions(),
    );
    return ExercisePage.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ExerciseHistory> fetchExerciseHistory(String exerciseId) async {
    final response = await _dio.get(
      '/workouts/exercises/$exerciseId/history',
      options: await _authorizedOptions(),
    );
    return ExerciseHistory.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<WorkoutSession> startSession(
    List<RoutineExercise> exercises, {
    int? trainingWeek,
    int? planDayIndex,
  }) async {
    final response = await _dio.post(
      '/workouts/sessions',
      data: {
        'exercises': exercises
            .map(
              (exercise) => {
                'exerciseId': exercise.id,
                'targetSets': exercise.sets,
                'targetReps': exercise.reps,
              },
            )
            .toList(),
        'trainingWeek': ?trainingWeek,
        'planDayIndex': ?planDayIndex,
      },
      options: await _authorizedOptions(),
    );
    return WorkoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<WorkoutSession?> fetchActiveSession() async {
    final response = await _dio.get(
      '/workouts/sessions/active',
      options: await _authorizedOptions(),
    );
    final session = response.data['session'];
    return session == null
        ? null
        : WorkoutSession.fromJson(Map<String, dynamic>.from(session as Map));
  }

  Future<List<WorkoutHistoryEntry>> fetchWorkoutHistory() async {
    final response = await _dio.get(
      '/workouts/sessions/history',
      options: await _authorizedOptions(),
    );
    return (response.data as List)
        .map(
          (item) => WorkoutHistoryEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<WorkoutCalorieProgress> fetchWorkoutCalorieProgress() async {
    final response = await _dio.get(
      '/workouts/progress',
      options: await _authorizedOptions(),
    );
    return WorkoutCalorieProgress.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<WorkoutCalorieHistoryEntry>> fetchWorkoutCalorieHistory() async {
    final response = await _dio.get(
      '/workouts/progress/history',
      options: await _authorizedOptions(),
    );
    return (response.data as List)
        .map(
          (item) => WorkoutCalorieHistoryEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<LoggedSet> logSet({
    required String sessionId,
    required String workoutExerciseId,
    required int setNumber,
    required double weightKg,
    required int reps,
    double? rpe,
  }) async {
    final response = await _dio.post(
      '/workouts/sessions/$sessionId/exercises/$workoutExerciseId/sets',
      data: {
        'setNumber': setNumber,
        'weightKg': weightKg,
        'reps': reps,
        'rpe': rpe,
        'completed': true,
      },
      options: await _authorizedOptions(),
    );
    return LoggedSet.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<WorkoutCompletion> completeSession(String sessionId) async {
    final response = await _dio.patch(
      '/workouts/sessions/$sessionId/complete',
      options: await _authorizedOptions(),
    );
    return WorkoutCompletion.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(dioProvider));
});

final weeklyRoutineProvider =
    FutureProvider.family<List<RoutineDay>, WorkoutRequest>((ref, request) {
      return ref.watch(workoutRepositoryProvider).fetchWeeklyRoutine(request);
    });

final activeWorkoutProvider = FutureProvider<WorkoutSession?>((ref) {
  return ref.watch(workoutRepositoryProvider).fetchActiveSession();
});

final workoutHistoryProvider = FutureProvider<List<WorkoutHistoryEntry>>((ref) {
  return ref.watch(workoutRepositoryProvider).fetchWorkoutHistory();
});

final workoutCalorieProgressProvider =
    FutureProvider.autoDispose<WorkoutCalorieProgress>((ref) {
      return ref.watch(workoutRepositoryProvider).fetchWorkoutCalorieProgress();
    });

final workoutCalorieHistoryProvider =
    FutureProvider.autoDispose<List<WorkoutCalorieHistoryEntry>>((ref) {
      return ref.watch(workoutRepositoryProvider).fetchWorkoutCalorieHistory();
    });
