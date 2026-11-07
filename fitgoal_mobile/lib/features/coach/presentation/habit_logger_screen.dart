import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/logger_repository.dart';
import '../../workouts/data/workout_repository.dart';

class HabitLoggerScreen extends ConsumerStatefulWidget {
  const HabitLoggerScreen({super.key});

  @override
  ConsumerState<HabitLoggerScreen> createState() => _HabitLoggerScreenState();
}

class _HabitLoggerScreenState extends ConsumerState<HabitLoggerScreen> {
  // Meal input controllers
  final _mealNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();

  @override
  void dispose() {
    _mealNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  // Add meal dialog
  void _addMealDialog() {
    _mealNameController.clear();
    _caloriesController.clear();
    _proteinController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D1F),
        title: const Text(
          'Log Meal / Food Item',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _mealNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Food Name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Calories (kcal)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Protein (g)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = _mealNameController.text.trim();
              final calories = int.tryParse(_caloriesController.text.trim());
              final protein = int.tryParse(_proteinController.text.trim());

              if (name.isEmpty ||
                  calories == null ||
                  protein == null ||
                  calories <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a food name and valid calorie and protein values.',
                    ),
                  ),
                );
                return;
              }

              // Post to backend repository
              final repo = ref.read(loggerRepositoryProvider);
              await repo.logMeal(
                name: name,
                calories: calories,
                protein: protein,
              );

              // Refresh provider data
              ref
                ..invalidate(dailySummaryProvider)
                ..invalidate(mealHistoryProvider);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Add Meal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dailySummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: const Text('Daily Habit & Calorie Logger'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFFF7043),
      ),
      body: summaryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7043)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Failed to load daily summary: $err',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (summary) {
          final meals = summary.meals;
          final habit = summary.habit;

          // Calculate total calories from backend records
          final totalCalories = meals.fold<int>(
            0,
            (sum, meal) => sum + (meal['calories'] as int? ?? 0),
          );

          // Calculate total protein from backend records
          final totalProtein = meals.fold<int>(
            0,
            (sum, meal) => sum + (meal['protein'] as int? ?? 0),
          );

          final waterLogged = habit['waterGoalMet'] ?? false;
          final workoutCompleted = habit['workoutCompleted'] ?? false;
          final sleepTargetMet = habit['sleepGoalMet'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Daily Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1D1F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF7043).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryMetric(
                        'Calories Consumed',
                        '$totalCalories kcal',
                        Colors.lightBlueAccent,
                      ),
                      Container(height: 40, width: 1, color: Colors.white24),
                      _buildSummaryMetric(
                        'Protein Logged',
                        '${totalProtein}g',
                        const Color(0xFFFF5252),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const _WorkoutProgressSection(),

                const SizedBox(height: 28),

                // Daily Habits
                const Text(
                  'Daily Habits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _buildHabitTile(
                  'Drink 3.5 Liters of Water',
                  Icons.water_drop,
                  waterLogged,
                  (value) => _updateHabit(
                    () => ref
                        .read(loggerRepositoryProvider)
                        .updateHabits(waterGoalMet: value),
                  ),
                ),

                _buildHabitTile(
                  'Complete Scheduled Workout',
                  Icons.fitness_center,
                  workoutCompleted,
                  (value) => _updateHabit(
                    () => ref
                        .read(loggerRepositoryProvider)
                        .updateHabits(workoutCompleted: value),
                  ),
                ),

                _buildHabitTile(
                  '7+ Hours Quality Sleep',
                  Icons.nightlight_round,
                  sleepTargetMet,
                  (value) => _updateHabit(
                    () => ref
                        .read(loggerRepositoryProvider)
                        .updateHabits(sleepGoalMet: value),
                  ),
                ),

                const SizedBox(height: 28),

                // Meals Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Meals",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addMealDialog,
                      icon: const Icon(Icons.add, color: Color(0xFFFF7043)),
                      label: const Text(
                        'Log Meal',
                        style: TextStyle(
                          color: Color(0xFFFF7043),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Meals List
                meals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No meals logged yet today. Tap "Log Meal" to add one!',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: meals.length,
                        itemBuilder: (context, index) {
                          final meal = meals[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1D1F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.restaurant,
                                        color: Color(0xFFFF7043),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          meal['name'] as String? ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${meal['calories']} kcal',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${meal['protein']}g protein',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Summary Metric Widget
  Widget _buildSummaryMetric(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _updateHabit(Future<void> Function() update) async {
    try {
      await update();
      if (mounted) ref.invalidate(dailySummaryProvider);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save habit: $message')));
    }
  }

  Widget _buildHabitTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          secondary: Icon(icon, color: const Color(0xFFFF7043)),
          activeColor: const Color(0xFFFF7043),
          checkColor: Colors.black,
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _WorkoutProgressSection extends ConsumerWidget {
  const _WorkoutProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(workoutCalorieProgressProvider);
    final history = ref.watch(workoutCalorieHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Workout Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        progress.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF7043)),
          ),
          error: (error, stack) => _WorkoutProgressError(
            message: 'Could not load workout progress: $error',
            onRetry: () => ref.invalidate(workoutCalorieProgressProvider),
          ),
          data: (value) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D1F),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _WorkoutMetric(
                  label: 'Workouts',
                  value: '${value.completedWorkouts}',
                ),
                _WorkoutMetric(
                  label: 'This week',
                  value: '${value.weekCalories} kcal',
                ),
                _WorkoutMetric(
                  label: 'All time',
                  value: '${value.allTimeCalories} kcal',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Recent Workouts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF7043)),
          ),
          error: (error, stack) => _WorkoutProgressError(
            message: 'Could not load workout history: $error',
            onRetry: () => ref.invalidate(workoutCalorieHistoryProvider),
          ),
          data: (entries) => entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Completed workouts will appear here.',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: entries.take(5).map((entry) {
                    final exerciseSummary = entry.exerciseNames.isEmpty
                        ? 'Workout'
                        : entry.exerciseNames.take(3).join(', ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1D1F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            color: Color(0xFFFF7043),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEE, MMM d · h:mm a')
                                      .format(entry.completedAt.toLocal()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$exerciseSummary · ${entry.durationMins} min',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.caloriesBurned} kcal',
                            style: const TextStyle(
                              color: Color(0xFFFFB199),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _WorkoutMetric extends StatelessWidget {
  const _WorkoutMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFB199),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ),
  );
}

class _WorkoutProgressError extends StatelessWidget {
  const _WorkoutProgressError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
      IconButton(
        tooltip: 'Retry',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, color: Color(0xFFFF7043)),
      ),
    ],
  );
}
