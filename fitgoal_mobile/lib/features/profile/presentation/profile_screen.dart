import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coach/presentation/habit_logger_screen.dart';
import '../../coach/presentation/meal_planner_screen.dart';
import '../../workouts/presentation/exercise_library_screen.dart';
import '../../workouts/presentation/workout_routine_screen.dart';
import 'reminder_settings_screen.dart';
import 'security_settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1769E0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar & Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFF1769E0),
                    child: Icon(Icons.person, size: 36, color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'FitGoal Member',
                          style: TextStyle(
                            color: Color(0xFF10264A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'member@fitgoal.app',
                          style: TextStyle(color: Color(0xFF73839B), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Quick access',
              style: TextStyle(
                color: Color(0xFF10264A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingTile(
              icon: Icons.fitness_center_outlined,
              title: 'Workout plans',
              subtitle: 'Your weekly schedule and training level',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutRoutineScreen(),
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.restaurant_menu_outlined,
              title: 'Meal plan',
              subtitle: 'Today’s meals and nutrition targets',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MealPlannerScreen(),
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.menu_book_outlined,
              title: 'Exercise library',
              subtitle: 'Find exercises and build a session',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ExerciseLibraryScreen(),
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.insights_outlined,
              title: 'Daily progress',
              subtitle: 'Review your habits and calorie log',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const HabitLoggerScreen(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Settings Section Header
            const Text(
              'Preferences',
              style: TextStyle(
                color: Color(0xFF10264A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Settings Options
            _buildSettingTile(
              icon: Icons.track_changes,
              title: 'Update Smart Goals',
              subtitle: 'Recalculate TDEE and macro targets',
              onTap: () {
                Navigator.pushNamed(context, '/goal-setup');
              },
            ),
            _buildSettingTile(
              icon: Icons.notifications_outlined,
              title: 'Reminders & Notifications',
              subtitle: 'Workout and water tracking alerts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReminderSettingsScreen(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.lock_outline,
              title: 'Privacy & Security',
              subtitle: 'Manage account credentials',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SecuritySettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252)
                    .withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFFF5252),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFF5252)),
                ),
                elevation: 0,
              ),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Log Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF1769E0)),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF10264A),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF73839B), fontSize: 12),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFFD5E0F0),
            size: 16,
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
