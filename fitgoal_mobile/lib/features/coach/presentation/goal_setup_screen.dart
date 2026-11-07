import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/goal_controller.dart';

class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _gender = 'MALE';
  String _activityLevel = 'MODERATE';
  String _fitnessLevel = 'BEGINNER';
  String _fitnessGoal = 'FAT_LOSS';

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(goalControllerProvider.notifier)
          .submitGoal(
            age: int.parse(_ageController.text.trim()),
            gender: _gender,
            heightCm: double.parse(_heightController.text.trim()),
            weightKg: double.parse(_weightController.text.trim()),
            activityLevel: _activityLevel,
            fitnessLevel: _fitnessLevel,
            goal: _fitnessGoal,
          );

      // Fix for async gap context checking
      if (!mounted) return;

      if (success) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'TDEE & Macro calculations computed successfully! 🎉',
            ),
            backgroundColor: Color(0xFFFF7043),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single clean state watcher
    final state = ref.watch(goalControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: const Text('Smart Coach Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFFF7043),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'We will calculate your baseline TDEE and custom macro targets.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Error Banner if calculation fails
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Gender Selection
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Male')),
                      selected: _gender == 'MALE',
                      selectedColor: const Color(0xFFFF7043),
                      backgroundColor: const Color(0xFF1B1D1F),
                      labelStyle: TextStyle(
                        color: _gender == 'MALE' ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _gender = 'MALE');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Female')),
                      selected: _gender == 'FEMALE',
                      selectedColor: const Color(0xFFFF7043),
                      backgroundColor: const Color(0xFF1B1D1F),
                      labelStyle: TextStyle(
                        color: _gender == 'FEMALE'
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _gender = 'FEMALE');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Age, Height, Weight Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Age', 'yr'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Height', 'cm'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Weight', 'kg'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Activity Level Dropdown
              const Text(
                'Activity Level',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _activityLevel,
                dropdownColor: const Color(0xFF1B1D1F),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1B1D1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'SEDENTARY',
                    child: Text('Sedentary (Little or no exercise)'),
                  ),
                  DropdownMenuItem(
                    value: 'LIGHT',
                    child: Text('Light (1-3 days/week)'),
                  ),
                  DropdownMenuItem(
                    value: 'MODERATE',
                    child: Text('Moderate (3-5 days/week)'),
                  ),
                  DropdownMenuItem(
                    value: 'VERY_ACTIVE',
                    child: Text('Very Active (6-7 days/week)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _activityLevel = val);
                },
              ),
              const SizedBox(height: 28),

              const Text(
                'Your training experience',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your coach will tailor your weekly exercises to this level and adjust it as you progress.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'].map((level) {
                  final selected = _fitnessLevel == level;
                  return ChoiceChip(
                    label: Text(_levelLabel(level)),
                    selected: selected,
                    selectedColor: const Color(0xFFFF7043),
                    backgroundColor: const Color(0xFF1B1D1F),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _fitnessLevel = level),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Primary Fitness Goal
              const Text(
                'Primary Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildGoalOption(
                'FAT_LOSS',
                'Fat Loss',
                'Maintain calorie deficit & high protein',
                Icons.local_fire_department,
              ),
              const SizedBox(height: 8),
              _buildGoalOption(
                'MAINTENANCE',
                'Maintain Weight',
                'Keep current weight & optimize stamina',
                Icons.balance,
              ),
              const SizedBox(height: 8),
              _buildGoalOption(
                'MUSCLE_GAIN',
                'Muscle Gain',
                'Surplus calories to maximize hypertrophy',
                Icons.fitness_center,
              ),
              const SizedBox(height: 8),
              _buildGoalOption(
                'STRENGTH',
                'Build Strength',
                'Compound-focused training and gradual progression',
                Icons.bolt,
              ),
              const SizedBox(height: 32),

              // Generate Target Plan Button
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Calculate My Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String suffix) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: Colors.white70),
      suffixStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1B1D1F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _levelLabel(String level) =>
      level[0] + level.substring(1).toLowerCase();

  Widget _buildGoalOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _fitnessGoal == value;
    return GestureDetector(
      onTap: () => setState(() => _fitnessGoal = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7043) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF7043) : Colors.white54,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
