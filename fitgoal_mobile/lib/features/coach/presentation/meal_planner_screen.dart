import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/logger_repository.dart';
import '../data/meal_plan_repository.dart';
import '../providers/goal_controller.dart';

class MealPlannerScreen extends ConsumerStatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  ConsumerState<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends ConsumerState<MealPlannerScreen> {
  final Set<String> _updatingMeals = {};

  Future<void> _setEaten(
    PlannedMeal meal, {
    required bool eaten,
    _MealIntake? intake,
  }) async {
    setState(() => _updatingMeals.add(meal.id));
    try {
      await ref
          .read(mealPlanRepositoryProvider)
          .setEaten(
            mealId: meal.id,
            eaten: eaten,
            calories: intake?.calories,
            protein: intake?.protein,
            carbs: intake?.carbs,
            fats: intake?.fats,
          );
      ref
        ..invalidate(dailyMealPlanProvider)
        ..invalidate(dailySummaryProvider)
        ..invalidate(mealHistoryProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update meal: ${_friendlyError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingMeals.remove(meal.id));
    }
  }

  Future<void> _editIntake(PlannedMeal meal) async {
    final intake = await _showIntakeDialog(meal);
    if (intake == null || !mounted) return;
    await _setEaten(meal, eaten: true, intake: intake);
  }

  Future<_MealIntake?> _showIntakeDialog(PlannedMeal meal) async {
    final calories = TextEditingController(
      text: (meal.eaten ? meal.consumedCalories : meal.calories).toString(),
    );
    final protein = TextEditingController(
      text: (meal.eaten ? meal.consumedProtein : meal.protein)
          .round()
          .toString(),
    );
    final carbs = TextEditingController(
      text: (meal.eaten ? meal.consumedCarbs : meal.carbs).round().toString(),
    );
    final fats = TextEditingController(
      text: (meal.eaten ? meal.consumedFats : meal.fats).round().toString(),
    );
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<_MealIntake>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('What did you eat?'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the amount you actually consumed. Use 0 for anything you skipped.',
                  ),
                  const SizedBox(height: 12),
                  _intakeField(calories, 'Calories (kcal)'),
                  _intakeField(protein, 'Protein (g)'),
                  _intakeField(carbs, 'Carbohydrates (g)'),
                  _intakeField(fats, 'Fat (g)'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _MealIntake(
                    calories: int.parse(calories.text),
                    protein: int.parse(protein.text),
                    carbs: int.parse(carbs.text),
                    fats: int.parse(fats.text),
                  ),
                );
              },
              child: const Text('Save intake'),
            ),
          ],
        ),
      );
    } finally {
      calories.dispose();
      protein.dispose();
      carbs.dispose();
      fats.dispose();
    }
  }

  Widget _intakeField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final amount = int.tryParse(value ?? '');
          if (amount == null || amount < 0 || amount > 10000) {
            return 'Enter a whole number from 0 to 10000';
          }
          return null;
        },
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final response = error.response?.data;
      if (response is Map && response['message'] is String) {
        return response['message'] as String;
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return 'Your session has expired. Please sign in again.';
      }
      return error.message ?? 'Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(dailyMealPlanProvider);
    final goal = ref.watch(goalControllerProvider).calculatedGoal;

    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: const Text('Today’s Meal Plan'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFF7043),
      ),
      body: plan.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7043)),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _friendlyError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(dailyMealPlanProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (dailyPlan) => RefreshIndicator(
          color: const Color(0xFFFF7043),
          onRefresh: () async => ref.invalidate(dailyMealPlanProvider),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(dailyPlan.planDate.toLocal()),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _DailyTargetsCard(
                plan: dailyPlan,
                proteinTarget: goal?.proteinGrams ?? 0,
                carbsTarget: goal?.carbsGrams ?? 0,
                fatsTarget: goal?.fatsGrams ?? 0,
              ),
              const SizedBox(height: 22),
              const Text(
                'YOUR MEALS',
                style: TextStyle(
                  color: Color(0xFFFFB199),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...dailyPlan.meals.map(
                (meal) => _MealCard(
                  meal: meal,
                  isUpdating: _updatingMeals.contains(meal.id),
                  onLogIntake: () => _editIntake(meal),
                  onUndo: () => _setEaten(meal, eaten: false),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Meal ideas and per-meal macros are estimates based on your saved daily targets. Review ingredients for allergies or dietary needs, and consult a qualified professional for medical nutrition advice.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const _MealHistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealIntake {
  const _MealIntake({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fats;
}

class _MealHistorySection extends ConsumerWidget {
  const _MealHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(mealHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEAL HISTORY',
          style: TextStyle(
            color: Color(0xFFFFB199),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        history.when(
          loading: () =>
              const LinearProgressIndicator(color: Color(0xFFFF7043)),
          error: (error, stack) => Text(
            'Could not load meal history: ${error.toString().replaceFirst('Exception: ', '')}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Text(
                'Meals you mark as eaten will appear here.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              );
            }
            final grouped = <DateTime, List<MealHistoryEntry>>{};
            for (final entry in entries) {
              final date = entry.loggedAt.toLocal();
              final key = DateTime(date.year, date.month, date.day);
              grouped.putIfAbsent(key, () => []).add(entry);
            }
            final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
            return Column(
              children: dates.map((date) {
                final meals = grouped[date]!;
                final calories = meals.fold<int>(
                  0,
                  (total, meal) => total + meal.calories,
                );
                return Card(
                  color: const Color(0xFF1B1D1F),
                  child: ExpansionTile(
                    title: Text(
                      DateFormat('EEE, MMM d').format(date),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '$calories kcal · ${meals.length} meals',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    children: meals
                        .map(
                          (meal) => ListTile(
                            dense: true,
                            title: Text(
                              meal.name,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              '${DateFormat('h:mm a').format(meal.loggedAt.toLocal())} · P ${meal.protein}g · C ${meal.carbs}g · F ${meal.fats}g',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Text(
                              '${meal.calories} kcal',
                              style: const TextStyle(
                                color: Color(0xFFFF7043),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DailyTargetsCard extends StatelessWidget {
  const _DailyTargetsCard({
    required this.plan,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatsTarget,
  });

  final DailyMealPlan plan;
  final double proteinTarget;
  final double carbsTarget;
  final double fatsTarget;

  @override
  Widget build(BuildContext context) {
    final progress = plan.targetCalories == 0
        ? 0.0
        : (plan.eatenCalories / plan.targetCalories).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plan.eatenCalories} / ${plan.targetCalories} kcal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MacroTotal(
                name: 'Protein',
                eaten: plan.eatenProtein,
                target: proteinTarget,
              ),
              _MacroTotal(
                name: 'Carbs',
                eaten: plan.eatenCarbs,
                target: carbsTarget,
              ),
              _MacroTotal(
                name: 'Fat',
                eaten: plan.eatenFats,
                target: fatsTarget,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Log what you actually ate to update your daily food totals.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MacroTotal extends StatelessWidget {
  const _MacroTotal({
    required this.name,
    required this.eaten,
    required this.target,
  });

  final String name;
  final double eaten;
  final double target;

  @override
  Widget build(BuildContext context) => Text(
    '$name ${eaten.round()} / ${target}g',
    style: const TextStyle(color: Colors.white70, fontSize: 12),
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.isUpdating,
    required this.onLogIntake,
    required this.onUndo,
  });

  final PlannedMeal meal;
  final bool isUpdating;
  final VoidCallback onLogIntake;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final type = meal.type.toLowerCase();
    final label = type.isEmpty
        ? 'Meal'
        : '${type[0].toUpperCase()}${type.substring(1)}';
    return Card(
      color: const Color(0xFF1B1D1F),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey(meal.id),
        iconColor: const Color(0xFFFF7043),
        collapsedIconColor: Colors.white54,
        title: Text(
          meal.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          meal.eaten
              ? '$label · Ate ${meal.consumedCalories} kcal · P ${meal.consumedProtein.round()}g  C ${meal.consumedCarbs.round()}g  F ${meal.consumedFats.round()}g'
              : '$label · Planned ${meal.calories} kcal · P ${meal.protein.round()}g  C ${meal.carbs.round()}g  F ${meal.fats.round()}g',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              meal.recipe,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUpdating ? null : onLogIntake,
                  icon: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                  label: Text(meal.eaten ? 'Edit amount' : 'Log amount eaten'),
                ),
              ),
              if (meal.eaten) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Undo eaten',
                  onPressed: isUpdating ? null : onUndo,
                  icon: const Icon(Icons.undo_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
