import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/goal_controller.dart';

class MacroDashboardScreen extends ConsumerWidget {
  const MacroDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalState = ref.watch(goalControllerProvider);
    final goal = goalState.calculatedGoal;

    if (goal == null) {
      if (goalState.isRestoring) {
        return const Scaffold(
          backgroundColor: Color(0xFFF4F7FC),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF1769E0)),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          title: const Text('Your Fitness Targets'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  goalState.errorMessage ?? 'No calculated goals found. Please complete your Smart Coach Setup first.',
                  style: const TextStyle(color: Color(0xFF536987), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (goalState.errorMessage == null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/goal-setup'),
                    child: const Text('Set up your fitness plan'),
                  ),
                ] else if (goalState.errorMessage!.contains(
                  'Please sign in again',
                )) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    ),
                    child: const Text('Sign in again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Smart Coach Plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1769E0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily Calorie Target Hero Card
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1769E0), Color(0xFF55A8FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1769E0).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'DAILY CALORIE TARGET',
                    style: TextStyle(
                      color: Color(0xFF10264A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${goal.targetCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 42,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Goal: ${goal.goal.replaceAll('_', ' ')}',
                    style: const TextStyle(
                      color: Color(0xFF10264A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Metabolism Breakdown Row (BMR & TDEE)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Basal Metabolic Rate',
                    '${goal.bmr.toStringAsFixed(0)} kcal',
                    'BMR (At Rest)',
                    Icons.nightlight_round,
                    Color(0xFF1769E0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Total Energy Expenditure',
                    '${goal.tdee.toStringAsFixed(0)} kcal',
                    'TDEE (Active)',
                    Icons.bolt,
                    Color(0xFF2580E8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Macronutrient Targets Section
            const Text(
              'Daily Macronutrients',
              style: TextStyle(
                color: Color(0xFF10264A),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Protein Card
            _buildMacroCard(
              'Protein',
              '${goal.proteinGrams.toStringAsFixed(0)}g',
              '40% of intake',
              const Color(0xFFFF5252),
              Icons.fitness_center,
            ),
            const SizedBox(height: 12),

            // Carbohydrates Card
            _buildMacroCard(
              'Carbohydrates',
              '${goal.carbsGrams.toStringAsFixed(0)}g',
              '40% of intake',
              const Color(0xFFFFD700),
              Icons.grain,
            ),
            const SizedBox(height: 12),

            // Fats Card
            _buildMacroCard(
              'Fats',
              '${goal.fatsGrams.toStringAsFixed(0)}g',
              '20% of intake',
              const Color(0xFF1769E0),
              Icons.water_drop,
            ),
            const SizedBox(height: 32),

            // Meal plans are generated from the client's saved nutrition targets.
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/meal-planner');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769E0),
                foregroundColor: Color(0xFFFFFFFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Today’s Meal Plan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF10264A),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF73839B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(
    String title,
    String grams,
    String percentage,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF10264A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  percentage,
                  style: const TextStyle(color: Color(0xFF73839B), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            grams,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
