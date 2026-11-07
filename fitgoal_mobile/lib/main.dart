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
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1769E0),
          secondary: Color(0xFF55A8FA),
          surface: Color(0xFFFFFFFF),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFF10264A),
          onSurface: Color(0xFF10264A),
          error: Color(0xFFFF6B6B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7FC),
          foregroundColor: Color(0xFF10264A),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF10264A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x14244477)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEAF2FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8E5F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1769E0), width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1769E0),
            foregroundColor: const Color(0xFFFFFFFF),
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF0B2C77),
          contentTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          indicatorColor: Color(0xFFDCEBFF),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1769E0),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: const BorderSide(color: Color(0xFF9AB0CE)),
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
