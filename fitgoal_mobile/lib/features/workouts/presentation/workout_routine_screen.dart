import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/data/goal_model.dart';
import '../../coach/providers/goal_controller.dart';
import '../data/workout_repository.dart';
import 'active_workout_screen.dart';
import 'exercise_library_screen.dart';

class WorkoutRoutineScreen extends ConsumerStatefulWidget {
  const WorkoutRoutineScreen({super.key});

  @override
  ConsumerState<WorkoutRoutineScreen> createState() =>
      _WorkoutRoutineScreenState();
}

class _WorkoutRoutineScreenState extends ConsumerState<WorkoutRoutineScreen> {
  static const _equipmentOptions = [
    'BARBELL',
    'DUMBBELL',
    'BODYWEIGHT',
    'CABLE',
    'MACHINE',
  ];

  int _daysPerWeek = 4;
  final Set<String> _availableEquipment = Set.from(_equipmentOptions);

  WorkoutRequest get _workoutRequest => WorkoutRequest(
    daysPerWeek: _daysPerWeek,
    availableEquipment: _availableEquipment.toList(),
  );

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(goalControllerProvider).calculatedGoal;
    final calorieProgress = ref.watch(workoutCalorieProgressProvider);
    final routineAsync = ref.watch(weeklyRoutineProvider(_workoutRequest));
    final completedDays = routineAsync.maybeWhen(
      data: (routine) => routine.isEmpty
          ? <int>{}
          : routine.first.completedPlanDaysInWeek.toSet(),
      orElse: () => <int>{},
    );
    final trainingLevel = routineAsync.maybeWhen(
      data: (routine) => routine.isEmpty ? null : routine.first.trainingLevel,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: const Text('Your Weekly Workout Plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFFF7043),
        actions: [
          IconButton(
            tooltip: 'Exercise library',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPlanOptions(trainingLevel: trainingLevel),
          Expanded(
            child: routineAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF7043)),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load routine: $error',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (routine) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: routine.isEmpty ? 0 : routine.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildPlanGuidance(routine.first, goal: goal);
                  }
                  if (index == 1) {
                    final plannedDays = {
                      for (
                        var dayIndex = 0;
                        dayIndex < routine.length;
                        dayIndex++
                      )
                        if (!routine[dayIndex].isRestDay) dayIndex,
                    };
                    final completedPlannedDays = completedDays
                        .intersection(plannedDays)
                        .length;
                    return _buildProgressCard(
                      completedDays: completedPlannedDays,
                      plannedDays: plannedDays.length,
                      calorieProgress: calorieProgress,
                      trainingWeek: routine.first.trainingWeek,
                    );
                  }
                  final dayIndex = index - 2;
                  return _buildDay(
                    context,
                    routine[dayIndex],
                    completed: completedDays.contains(dayIndex),
                    dayIndex: dayIndex,
                    trainingWeek: routine.first.trainingWeek,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required int completedDays,
    required int plannedDays,
    required AsyncValue<WorkoutCalorieProgress> calorieProgress,
    required int trainingWeek,
  }) {
    final progress = plannedDays == 0
        ? 0.0
        : (completedDays / plannedDays).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR WEEKLY PROGRESS',
            style: TextStyle(
              color: Color(0xFFFFB199),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Training week $trainingWeek',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completedDays of $plannedDays workouts completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFFF7043),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              color: const Color(0xFFFF7043),
            ),
          ),
          const SizedBox(height: 10),
          calorieProgress.when(
            loading: () => const Text(
              'Loading calorie progress…',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            error: (error, stack) => Text(
              'Could not load calorie progress: $error',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            data: (value) => Text(
              '${value.weekCalories} kcal estimated over the last 7 days',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanGuidance(RoutineDay day, {GoalResponse? goal}) {
    final title = switch (day.primaryGoal) {
      'FAT_LOSS' => 'Fat-loss training focus',
      'MUSCLE_GAIN' => 'Muscle-gain training focus',
      'STRENGTH' => 'Strength training focus',
      'MAINTENANCE' => 'Maintenance training focus',
      _ => 'Your training focus',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A201D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFB199),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (day.planGuidance.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              day.planGuidance,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (goal != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _goalMetric(
                  'Daily target',
                  '${goal.targetCalories.round()} kcal',
                ),
                _goalMetric('Protein', '${goal.proteinGrams.round()} g'),
                _goalMetric(
                  'Profile',
                  '${goal.age} yrs · ${goal.heightCm.round()} cm · ${goal.weightKg.toStringAsFixed(1)} kg',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _goalMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOptions({String? trainingLevel}) {
    final maxDays = switch (trainingLevel) {
      null || 'BEGINNER' => 4,
      'ADVANCED' => 6,
      _ => 5,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Training days per week',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DropdownButton<int>(
                value: _daysPerWeek,
                dropdownColor: const Color(0xFF1B1D1F),
                style: const TextStyle(color: Color(0xFFFF7043)),
                items: List.generate(
                  maxDays - 1,
                  (index) => DropdownMenuItem(
                    value: index + 2,
                    child: Text('${index + 2}'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setState(() => _daysPerWeek = value);
                },
              ),
            ],
          ),
          if (trainingLevel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Coach level: ${_displayName(trainingLevel)}',
              style: const TextStyle(
                color: Color(0xFFFF7043),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trainingLevel == 'BEGINNER'
                  ? 'Your coach will consider an upgrade after 12 well-logged workouts over at least 3 weeks.'
                  : trainingLevel == 'INTERMEDIATE'
                  ? 'Your coach will consider an upgrade after 20 well-logged workouts over at least 5 weeks.'
                  : 'Advanced is the highest training level.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Equipment available',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: _equipmentOptions.map((equipment) {
              final selected = _availableEquipment.contains(equipment);
              return FilterChip(
                label: Text(_displayName(equipment)),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _availableEquipment.add(equipment);
                  } else {
                    _availableEquipment.remove(equipment);
                  }
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDay(
    BuildContext context,
    RoutineDay day, {
    required bool completed,
    required int dayIndex,
    required int trainingWeek,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: !day.isRestDay,
          iconColor: const Color(0xFFFF7043),
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  day.dayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (completed)
                const Icon(Icons.check_circle, color: Color(0xFFFF7043)),
            ],
          ),
          subtitle: Text(
            completed
                ? 'Workout completed'
                : day.isRestDay
                ? 'Rest and recovery'
                : '${day.exercises.length} exercises',
            style: const TextStyle(color: Color(0xFFFF7043), fontSize: 12),
          ),
          children: [
            if (!day.isRestDay && day.exercises.isNotEmpty)
              ...day.exercises.map(_buildExerciseTile),
            if (!day.isRestDay)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => _addExercisesToDay(day, dayIndex),
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise to this day'),
                ),
              ),
            if (!day.isRestDay && day.exercises.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openWorkout(
                      day.exercises,
                      trainingWeek: trainingWeek,
                      planDayIndex: dayIndex,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start this workout'),
                  ),
                ),
              ),
            if (!day.isRestDay && day.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'No exercises match your equipment filters yet. Add one from the exercise library or change the filters.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExercisesToDay(RoutineDay day, int dayIndex) async {
    final defaultSets = day.exercises.isNotEmpty
        ? day.exercises.first.sets
        : switch (day.trainingLevel) {
            'BEGINNER' => 2,
            'ADVANCED' => 4,
            _ => 3,
          };
    final defaultReps = day.primaryGoal == 'STRENGTH'
        ? 5
        : day.trainingLevel == 'BEGINNER' && day.primaryGoal == 'MUSCLE_GAIN'
        ? 8
        : 10;

    final selectedExercises = await Navigator.push<List<RoutineExercise>>(
      context,
      MaterialPageRoute<List<RoutineExercise>>(
        builder: (_) => ExerciseLibraryScreen(
          planDaySelection: true,
          defaultSets: defaultSets,
          defaultReps: defaultReps,
          existingExerciseIds: day.exercises
              .map((exercise) => exercise.id)
              .toSet(),
        ),
      ),
    );
    if (!mounted || selectedExercises == null || selectedExercises.isEmpty) {
      return;
    }

    try {
      final addedCount = await ref
          .read(workoutRepositoryProvider)
          .addExercisesToPlanDay(
            daysPerWeek: _daysPerWeek,
            dayIndex: dayIndex,
            exercises: selectedExercises,
          );
      if (!mounted) return;
      ref.invalidate(weeklyRoutineProvider(_workoutRequest));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount == 0
                ? 'Those exercises are already saved to this workout day.'
                : 'Added $addedCount ${addedCount == 1 ? 'exercise' : 'exercises'} to ${day.dayTitle}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add exercises: $error')),
      );
    }
  }

  Future<void> _openWorkout(
    List<RoutineExercise> exercises, {
    int? trainingWeek,
    int? planDayIndex,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(
          initialExercises: exercises,
          trainingWeek: trainingWeek,
          planDayIndex: planDayIndex,
        ),
      ),
    );
    if (!mounted) return;
    ref
      ..invalidate(workoutHistoryProvider)
      ..invalidate(workoutCalorieProgressProvider)
      ..invalidate(workoutCalorieHistoryProvider)
      ..invalidate(weeklyRoutineProvider(_workoutRequest));
  }

  Widget _buildExerciseTile(RoutineExercise exercise) {
    final previousSummary = exercise.previousSets.isEmpty
        ? 'No previous session'
        : 'Previous: ${exercise.previousSets.map((set) => '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps}').join(', ')}';
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF2C2C2C),
        child: Icon(Icons.fitness_center, color: Color(0xFFFF7043), size: 20),
      ),
      title: Text(
        exercise.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${exercise.isCustomPlanExercise ? 'Added to plan · ' : ''}${exercise.targetMuscle} · $previousSummary',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: Text(
        '${exercise.sets} × ${exercise.reps}',
        style: const TextStyle(
          color: Color(0xFFFF7043),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _displayName(String value) =>
      value[0] + value.substring(1).toLowerCase();
}
