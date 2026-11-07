import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goal_model.dart';
import '../data/goal_repository.dart';

class GoalState {
  final bool isLoading;
  final bool isRestoring;
  final String? errorMessage;
  final GoalResponse? calculatedGoal;

  GoalState({
    this.isLoading = false,
    this.isRestoring = false,
    this.errorMessage,
    this.calculatedGoal,
  });

  GoalState copyWith({
    bool? isLoading,
    bool? isRestoring,
    String? errorMessage,
    GoalResponse? calculatedGoal,
  }) {
    return GoalState(
      isLoading: isLoading ?? this.isLoading,
      isRestoring: isRestoring ?? this.isRestoring,
      errorMessage: errorMessage,
      calculatedGoal: calculatedGoal ?? this.calculatedGoal,
    );
  }
}

class GoalController extends StateNotifier<GoalState> {
  final GoalRepository _repository;

  GoalController(this._repository) : super(GoalState(isRestoring: true)) {
    _restoreSavedGoal();
  }

  Future<void> _restoreSavedGoal() async {
    try {
      final savedGoal = await _repository.loadSavedGoal();
      state = state.copyWith(
        isRestoring: false,
        calculatedGoal:
            state.calculatedGoal ?? (state.isLoading ? null : savedGoal),
      );
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> submitGoal({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String fitnessLevel,
    required String goal,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.createOrUpdateGoal(
        age: age,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        activityLevel: activityLevel,
        fitnessLevel: fitnessLevel,
        goal: goal,
      );
      state = state.copyWith(isLoading: false, calculatedGoal: result);
      return true; // Success
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false; // Failed
    }
  }
}

// Global Goal Controller Provider
final goalControllerProvider = StateNotifierProvider<GoalController, GoalState>(
  (ref) {
    final repository = ref.watch(goalRepositoryProvider);
    return GoalController(repository);
  },
);
