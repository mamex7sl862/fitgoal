import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/data/logger_repository.dart';
import '../../coach/providers/goal_controller.dart';
import '../data/workout_repository.dart';
import 'exercise_demo_screen.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    required this.initialExercises,
    this.trainingWeek,
    this.planDayIndex,
    super.key,
  });

  final List<RoutineExercise> initialExercises;
  final int? trainingWeek;
  final int? planDayIndex;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  static const _backgroundColor = Color(0xFF101210);
  static const _surfaceColor = Color(0xFF1B201C);
  static const _accentColor = Color(0xFFFF7043);

  WorkoutSession? _session;
  final Map<String, _SetInput> _inputs = {};
  final Map<String, Future<ExerciseHistory>> _history = {};
  final Set<String> _savingSets = {};
  final Set<String> _editingSets = {};
  bool _isLoading = true;
  bool _isFinishing = false;
  String? _errorMessage;
  Timer? _restTimer;
  int _restSeconds = 0;

  int get _plannedSetCount =>
      _session?.exercises.fold<int>(
        0,
        (total, exercise) => total + exercise.targetSets,
      ) ??
      0;

  int get _completedSetCount =>
      _session?.exercises.fold<int>(
        0,
        (total, exercise) => total + exercise.sets.length,
      ) ??
      0;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeSession() async {
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final active = await repository.fetchActiveSession();
      final session =
          active ??
          await repository.startSession(
            widget.initialExercises,
            trainingWeek: widget.trainingWeek,
            planDayIndex: widget.planDayIndex,
          );
      if (!mounted) return;
      setState(() {
        _session = session;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  _SetInput _inputFor(SessionExercise exercise, int setNumber) {
    final key = '${exercise.id}-$setNumber';
    return _inputs.putIfAbsent(key, () {
      final suggested = exercise.exercise.recommendedWeightKg;
      return _SetInput(
        weight: suggested == null ? '' : suggested.toStringAsFixed(1),
        reps: exercise.targetReps.toString(),
        rpe: '',
      );
    });
  }

  Future<ExerciseHistory> _historyFor(String exerciseId) {
    return _history.putIfAbsent(
      exerciseId,
      () =>
          ref.read(workoutRepositoryProvider).fetchExerciseHistory(exerciseId),
    );
  }

  Future<void> _logSet(SessionExercise exercise, int setNumber) async {
    final key = '${exercise.id}-$setNumber';
    final input = _inputFor(exercise, setNumber);
    final weight = double.tryParse(input.weight.text.trim());
    final reps = int.tryParse(input.reps.text.trim());
    final rpeText = input.rpe.text.trim();
    final rpe = rpeText.isEmpty ? null : double.tryParse(rpeText);
    if (weight == null ||
        weight < 0 ||
        reps == null ||
        reps < 1 ||
        (rpeText.isNotEmpty && (rpe == null || rpe < 1 || rpe > 10))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid weight, reps, and optional RPE (1-10).'),
        ),
      );
      return;
    }

    setState(() => _savingSets.add(key));
    try {
      final loggedSet = await ref
          .read(workoutRepositoryProvider)
          .logSet(
            sessionId: _session!.id,
            workoutExerciseId: exercise.id,
            setNumber: setNumber,
            weightKg: weight,
            reps: reps,
            rpe: rpe,
          );
      if (!mounted) return;
      final current = _session!;
      final updatedExercises = current.exercises.map((item) {
        if (item.id != exercise.id) return item;
        final updatedSets = [
          ...item.sets.where((set) => set.setNumber != loggedSet.setNumber),
          loggedSet,
        ]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
        return SessionExercise(
          id: item.id,
          exercise: item.exercise,
          targetSets: item.targetSets,
          targetReps: item.targetReps,
          sets: updatedSets,
        );
      }).toList();
      setState(() {
        _session = WorkoutSession(
          id: current.id,
          startedAt: current.startedAt,
          exercises: updatedExercises,
        );
        _editingSets.remove(key);
        _savingSets.remove(key);
      });
      _startRestTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingSets.remove(key));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save set: $error')));
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSeconds = 90);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSeconds <= 1) {
        timer.cancel();
        setState(() => _restSeconds = 0);
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  Future<void> _completeWorkout() async {
    setState(() => _isFinishing = true);
    try {
      final completion = await ref
          .read(workoutRepositoryProvider)
          .completeSession(_session!.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      ref
        ..invalidate(weeklyRoutineProvider)
        ..invalidate(workoutHistoryProvider)
        ..invalidate(workoutCalorieProgressProvider)
        ..invalidate(dailySummaryProvider)
        ..invalidate(goalControllerProvider);
      Navigator.pop(context);
      final completionMessage =
          completion.levelPromotionMessage ??
          completion.levelCheckMessage ??
          'Workout saved to your history.';
      final calorieMessage = completion.caloriesBurned == null
          ? ''
          : 'Estimated ${completion.caloriesBurned} kcal burned. ';
      final message = '$calorieMessage$completionMessage';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finish workout: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout session',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'STAY CONSISTENT',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        foregroundColor: Colors.white,
        backgroundColor: _backgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7043)),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      _buildWorkoutOverview(),
                      _buildLevelProgress(),
                      _buildRestTimer(),
                      const SizedBox(height: 14),
                      if (_session!.exercises.isNotEmpty)
                        _buildGuidedWorkoutButton(),
                      ..._session!.exercises.asMap().entries.map(
                        (entry) => _buildExercise(entry.value, entry.key),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isFinishing ? null : _completeWorkout,
                        icon: _isFinishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Finish workout'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _accentColor,
                          foregroundColor: const Color(0xFF07120A),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWorkoutOverview() {
    final exercises = _session!.exercises;
    final progress = _plannedSetCount == 0
        ? 0.0
        : (_completedSetCount / _plannedSetCount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF33241F), Color(0xFF241D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accentColor.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.bolt, color: _accentColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOU’RE IN THE ZONE',
                      style: TextStyle(
                        color: Color(0xFFFFB199),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercises.length} exercises planned',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SESSION PROGRESS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .9,
                  ),
                ),
              ),
              Text(
                '$_completedSetCount / $_plannedSetCount sets',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              color: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgress() {
    final level = ref
        .watch(goalControllerProvider)
        .calculatedGoal
        ?.fitnessLevel
        .toUpperCase();
    const levels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];
    final currentIndex = levels.indexOf(level ?? '');
    if (currentIndex < 0) return const SizedBox.shrink();

    final currentLevel = _levelLabel(levels[currentIndex]);
    final nextLevel = currentIndex < levels.length - 1
        ? _levelLabel(levels[currentIndex + 1])
        : null;
    final milestone = switch (level) {
      'BEGINNER' => '12 qualifying workouts over at least 3 weeks',
      'INTERMEDIATE' => '20 qualifying workouts over at least 5 weeks',
      _ => 'You’ve reached the highest training level',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR FITNESS JOURNEY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentLevel.toUpperCase(),
                  style: const TextStyle(
                    color: _accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(levels.length * 2 - 1, (index) {
              if (index.isOdd) {
                final completed = index ~/ 2 < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: completed ? _accentColor : Colors.white12,
                  ),
                );
              }
              final levelIndex = index ~/ 2;
              final completed = levelIndex < currentIndex;
              final current = levelIndex == currentIndex;
              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: completed || current
                          ? _accentColor
                          : const Color(0xFF2A302B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : current
                          ? Icons.bolt
                          : Icons.lock_outline,
                      size: 17,
                      color: completed || current
                          ? const Color(0xFF07120A)
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _levelLabel(levels[levelIndex]),
                    style: TextStyle(
                      color: current ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            nextLevel == null ? milestone : 'Next up: $nextLevel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (nextLevel != null) ...[
            const SizedBox(height: 4),
            Text(
              milestone,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'Complete at least 75% of planned sets in each workout to qualify.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _levelLabel(String level) =>
      level[0] + level.substring(1).toLowerCase();

  Widget _buildGuidedWorkoutButton() {
    final exercises = _session!.exercises;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDemoScreen(
                exercise: exercises.first.exercise,
                targetReps: exercises.first.targetReps,
                workoutQueue: exercises,
                sessionId: _session!.id,
              ),
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: Text('Start guided workout (${exercises.length} exercises)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _accentColor,
            side: BorderSide(color: _accentColor.withValues(alpha: .45)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimer() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: _accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _restSeconds == 0
                  ? 'Rest timer ready'
                  : 'Rest: ${(_restSeconds ~/ 60).toString().padLeft(2, '0')}:${(_restSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _startRestTimer,
            child: const Text('Start 90s'),
          ),
          if (_restSeconds > 0)
            IconButton(
              tooltip: 'Stop rest timer',
              onPressed: () {
                _restTimer?.cancel();
                setState(() => _restSeconds = 0);
              },
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
    );
  }

  Widget _buildExercise(SessionExercise exercise, int exerciseIndex) {
    final history = _historyFor(exercise.exercise.id);
    final mediaUrl = ref
        .read(workoutRepositoryProvider)
        .mediaUrlFor(exercise.exercise);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'EXERCISE ${(exerciseIndex + 1).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    mediaUrl,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFF272E28),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accentColor,
                              ),
                            ),
                          ),
                    errorBuilder: (_, _, _) => Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFF272E28),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exercise.exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Open animation and spoken rep guide',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExerciseDemoScreen(exercise: exercise.exercise),
                    ),
                  ),
                  icon: const Icon(
                    Icons.volume_up_outlined,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _exerciseTag('${exercise.targetSets} sets'),
                const SizedBox(width: 7),
                _exerciseTag('${exercise.targetReps} reps'),
                const Spacer(),
                Text(
                  '${exercise.sets.length}/${exercise.targetSets} DONE',
                  style: const TextStyle(
                    color: Color(0xFFFFB199),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            FutureBuilder<ExerciseHistory>(
              future: history,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Previous stats unavailable: ${snapshot.error}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  );
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator(color: _accentColor);
                }
                final value = snapshot.data!;
                final previous = value.previousSets.isEmpty
                    ? 'No previous completed session'
                    : value.previousSets
                          .map(
                            (set) =>
                                '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps} reps',
                          )
                          .join('  ·  ');
                return Text(
                  '$previous\n${value.recommendationReason}${value.recommendedWeightKg == null ? '' : ' Suggested: ${value.recommendedWeightKg!.toStringAsFixed(1)} kg'}',
                  style: const TextStyle(
                    color: Color(0xFFFFB199),
                    fontSize: 12,
                    height: 1.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                dividerThickness: .5,
                headingRowHeight: 34,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 64,
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Set')),
                  DataColumn(label: Text('Weight kg')),
                  DataColumn(label: Text('Reps')),
                  DataColumn(label: Text('RPE')),
                  DataColumn(label: Text('')),
                ],
                rows: List.generate(exercise.targetSets, (index) {
                  final setNumber = index + 1;
                  final matchingSets = exercise.sets
                      .where((set) => set.setNumber == setNumber)
                      .toList();
                  final existing = matchingSets.isEmpty
                      ? null
                      : matchingSets.first;
                  final key = '${exercise.id}-$setNumber';
                  if (existing != null && !_editingSets.contains(key)) {
                    return DataRow(
                      cells: [
                        DataCell(Text('$setNumber ✓')),
                        DataCell(Text(existing.weightKg.toStringAsFixed(1))),
                        DataCell(Text('${existing.reps}')),
                        DataCell(Text(existing.rpe?.toStringAsFixed(1) ?? '—')),
                        DataCell(
                          IconButton(
                            tooltip: 'Edit logged set',
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: _accentColor,
                            ),
                            onPressed: () {
                              final input = _inputFor(exercise, setNumber);
                              input.weight.text = existing.weightKg
                                  .toStringAsFixed(1);
                              input.reps.text = existing.reps.toString();
                              input.rpe.text =
                                  existing.rpe?.toStringAsFixed(1) ?? '';
                              setState(() => _editingSets.add(key));
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  final input = _inputFor(exercise, setNumber);
                  return DataRow(
                    cells: [
                      DataCell(Text('$setNumber')),
                      DataCell(_numberField(input.weight, decimal: true)),
                      DataCell(_numberField(input.reps)),
                      DataCell(_numberField(input.rpe, decimal: true)),
                      DataCell(
                        IconButton(
                          tooltip: 'Log completed set',
                          onPressed: _savingSets.contains(key)
                              ? null
                              : () => _logSet(exercise, setNumber),
                          icon: _savingSets.contains(key)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: _accentColor,
                                ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    bool decimal = false,
  }) {
    return SizedBox(
      width: decimal ? 70 : 56,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}

class _SetInput {
  _SetInput({required String weight, required String reps, required String rpe})
    : weight = TextEditingController(text: weight),
      reps = TextEditingController(text: reps),
      rpe = TextEditingController(text: rpe);

  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController rpe;

  void dispose() {
    weight.dispose();
    reps.dispose();
    rpe.dispose();
  }
}
