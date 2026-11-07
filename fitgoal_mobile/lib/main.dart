import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import all feature screens
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/coach/presentation/goal_setup_screen.dart';
import 'features/coach/presentation/macro_dashboard_screen.dart';
import 'features/coach/presentation/meal_planner_screen.dart';
import 'features/workouts/presentation/workout_routine_screen.dart';
import 'features/coach/presentation/habit_logger_screen.dart';
import 'features/navigation/presentation/main_navigation_screen.dart';
import 'features/profile/presentation/profile_screen.dart';

void main() {
  runApp(const ProviderScope(child: FitGoalApp()));
}

class FitGoalApp extends StatelessWidget {
  const FitGoalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitGoal Smart Coach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101112),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF7043),
          secondary: Color(0xFFFFA06A),
          surface: Color(0xFF1B1D1F),
          error: Color(0xFFFF6B6B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101112),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B1D1F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x14FFFFFF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1D1F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF292B2D),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFFF7043),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/goal-setup': (context) => const GoalSetupScreen(),
        '/macro-dashboard': (context) => const MacroDashboardScreen(),
        '/meal-planner': (context) => const MealPlannerScreen(),
        '/workout-routine': (context) => const WorkoutRoutineScreen(),
        '/habit-logger': (context) => const HabitLoggerScreen(),
        '/home': (context) => const MainNavigationScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/': (context) => const SplashScreen(),
      },
    );
  }
}
