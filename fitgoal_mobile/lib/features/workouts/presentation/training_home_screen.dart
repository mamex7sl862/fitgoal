import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../coach/presentation/meal_planner_screen.dart';
import '../../navigation/providers/navigation_provider.dart';
import '../data/workout_repository.dart';
import 'active_workout_screen.dart';

class TrainingHomeScreen extends ConsumerWidget {
  const TrainingHomeScreen({super.key});

  static const _request = WorkoutRequest(
    daysPerWeek: 4,
    availableEquipment: [
      'BARBELL',
      'DUMBBELL',
      'BODYWEIGHT',
      'CABLE',
      'MACHINE',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ref.watch(weeklyRoutineProvider(_request));
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final today = DateTime.now();
    final completedWorkoutDays = routine.maybeWhen(
      data: (days) =>
          days.isEmpty ? <int>{} : days.first.completedPlanDaysInWeek.toSet(),
      orElse: () => <int>{},
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101210),
        title: const Text(
          'FITGOAL',
          style: TextStyle(
            color: Color(0xFFFF7043),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF7043),
        onRefresh: () async {
          ref.invalidate(weeklyRoutineProvider(_request));
          ref.invalidate(activeWorkoutProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              DateFormat('EEEE, MMMM d').format(today),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ready to move?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),
            activeWorkout.when(
              loading: () => const _LoadingCard(),
              error: (error, stack) => _ErrorCard(
                message:
                    'Could not check for an active workout: ${_friendlyError(error)}',
                onRetry: () => ref.invalidate(activeWorkoutProvider),
              ),
              data: (session) => session == null
                  ? _StartWorkoutCard(
                      routine: routine,
                      weekday: today.weekday - 1,
                      completedDays: completedWorkoutDays,
                      progressKnown: routine.hasValue,
                      onStart: (exercises, dayIndex, trainingWeek) =>
                          _openWorkout(
                            context,
                            ref,
                            exercises,
                            trainingWeek: trainingWeek,
                            planDayIndex: dayIndex,
                          ),
                      onBrowsePlan: () =>
                          ref.read(navigationIndexProvider.notifier).state = 1,
                    )
                  : _ResumeWorkoutCard(
                      session: session,
                      onResume: () => _openWorkout(context, ref, const []),
                    ),
            ),
            const SizedBox(height: 18),
            routine.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => _ErrorCard(
                message:
                    _friendlyError(error).contains('set up your fitness goal')
                    ? 'Set up your fitness goal to get a personalized training plan.'
                    : 'Could not load your plan: ${_friendlyError(error)}',
                onRetry: () => ref.invalidate(weeklyRoutineProvider(_request)),
              ),
              data: (days) => _WeeklyProgressCard(
                days: days,
                completedDays: completedWorkoutDays,
                onViewPlan: () =>
                    ref.read(navigationIndexProvider.notifier).state = 1,
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: const Color(0xFF1B1D1F),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFFFF7043),
                ),
                title: const Text(
                  'Meal plan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('See today’s meals and nutrition'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MealPlannerScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyError(Object error) {
    if (error is DioException) {
      final response = error.response?.data;
      if (response is Map && response['message'] is String) {
        return response['message'] as String;
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return 'Your session has expired. Please sign in again.';
      }
      if ((error.response?.statusCode ?? 0) >= 500) {
        return 'The service is temporarily unavailable. Please try again.';
      }
      return error.message ?? 'Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  static Future<void> _openWorkout(
    BuildContext context,
    WidgetRef ref,
    List<RoutineExercise> exercises, {
    int? trainingWeek,
    int? planDayIndex,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(
          initialExercises: exercises,
          trainingWeek: trainingWeek,
          planDayIndex: planDayIndex,
        ),
      ),
    );
    ref
      ..invalidate(activeWorkoutProvider)
      ..invalidate(workoutHistoryProvider)
      ..invalidate(workoutCalorieProgressProvider)
      ..invalidate(workoutCalorieHistoryProvider)
      ..invalidate(weeklyRoutineProvider(_request));
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.days,
    required this.completedDays,
    required this.onViewPlan,
  });

  final List<RoutineDay> days;
  final Set<int> completedDays;
  final VoidCallback onViewPlan;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final plan = days.first;
    final planned = plan.requiredSessionsPerWeek;
    final completed = completedDays.length;
    final progress = planned <= 0 ? 0.0 : (completed / planned).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This week',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Week ${plan.trainingWeek}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed of $planned workouts done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (completed >= planned && planned > 0)
                const Icon(Icons.check_circle, color: Color(0xFFFF7043)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              color: const Color(0xFFFF7043),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completed >= planned && planned > 0
                ? 'Weekly goal complete. Great work!'
                : 'Keep going at your own pace.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewPlan,
              child: const Text('View workout plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartWorkoutCard extends StatelessWidget {
  const _StartWorkoutCard({
    required this.routine,
    required this.weekday,
    required this.completedDays,
    required this.progressKnown,
    required this.onStart,
    required this.onBrowsePlan,
  });

  final AsyncValue<List<RoutineDay>> routine;
  final int weekday;
  final Set<int> completedDays;
  final bool progressKnown;
  final void Function(
    List<RoutineExercise> exercises,
    int dayIndex,
    int trainingWeek,
  )
  onStart;
  final VoidCallback onBrowsePlan;

  @override
  Widget build(BuildContext context) {
    final days = routine.valueOrNull;
    final workoutIndex = days == null
        ? weekday
        : progressKnown
        ? nextPlannedWorkoutIndex(days, completedDays)
        : weekday;
    final weeklyPlanComplete =
        days != null && progressKnown && workoutIndex == null;
    final todaysWorkout = days != null && workoutIndex != null
        ? days[workoutIndex]
        : null;
    final isRestDay = todaysWorkout?.isRestDay ?? true;
    final isNextSession = workoutIndex != null && workoutIndex != weekday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34231E), Color(0xFF211C1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFF7043)),
              const SizedBox(width: 8),
              Text(
                weeklyPlanComplete
                    ? 'WEEKLY PLAN COMPLETE'
                    : isRestDay
                    ? 'MAKE IT YOUR DAY'
                    : isNextSession
                    ? 'NEXT UP'
                    : 'TODAY’S SESSION',
                style: const TextStyle(
                  color: Color(0xFFFFB199),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            routine.isLoading
                ? 'Preparing your plan…'
                : weeklyPlanComplete
                ? 'All planned sessions completed'
                : todaysWorkout?.dayTitle.split(': ').last ?? 'Start a workout',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            weeklyPlanComplete
                ? 'Choose another session from your weekly plan.'
                : isRestDay
                ? 'Pick a session or build one from the exercise library.'
                : '${todaysWorkout!.exercises.length} exercises · Log every set as you go',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: todaysWorkout == null
                  ? weeklyPlanComplete
                        ? onBrowsePlan
                        : null
                  : isRestDay
                  ? onBrowsePlan
                  : todaysWorkout.exercises.isEmpty
                  ? null
                  : () => onStart(
                      todaysWorkout.exercises,
                      workoutIndex!,
                      days!.first.trainingWeek,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                weeklyPlanComplete
                    ? 'VIEW PLAN'
                    : isRestDay
                    ? 'CHOOSE A WORKOUT'
                    : isNextSession
                    ? 'START NEXT SESSION'
                    : 'START WORKOUT',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeWorkoutCard extends StatelessWidget {
  const _ResumeWorkoutCard({required this.session, required this.onResume});

  final WorkoutSession session;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final completedSets = session.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.sets.length,
    );
    final exerciseCount = session.exercises.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A201D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: .45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORKOUT IN PROGRESS',
            style: TextStyle(
              color: Color(0xFFFFB199),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$exerciseCount exercises · $completedSets sets logged',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('RESUME WORKOUT'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(child: CircularProgressIndicator(color: Color(0xFFFF7043))),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF261C19),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.white70)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ),
    );
  }
}
