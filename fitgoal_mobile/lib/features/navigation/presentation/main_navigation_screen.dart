import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/presentation/habit_logger_screen.dart';
import '../providers/navigation_provider.dart';
import '../../workouts/presentation/training_home_screen.dart';
import '../../workouts/presentation/workout_routine_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static const List<Widget> _screens = [
    TrainingHomeScreen(),
    WorkoutRoutineScreen(),
    HabitLoggerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref
        .watch(navigationIndexProvider)
        .clamp(0, _screens.length - 1)
        .toInt();

    const destinations = [
      (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
      (
        icon: Icons.fitness_center_outlined,
        selected: Icons.fitness_center,
        label: 'Train',
      ),
      (
        icon: Icons.insights_outlined,
        selected: Icons.insights,
        label: 'Progress',
      ),
      (
        icon: Icons.person_outline,
        selected: Icons.person,
        label: 'Profile',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5EDF8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2C77).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _NavigationDestination(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => ref
                        .read(navigationIndexProvider.notifier)
                        .state = index,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selected, String label}) destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCEBFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selected : destination.icon,
              color: selected
                  ? const Color(0xFF1769E0)
                  : const Color(0xFF73839B),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF0B2C77)
                    : const Color(0xFF73839B),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
