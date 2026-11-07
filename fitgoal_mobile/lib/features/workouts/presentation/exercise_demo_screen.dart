import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/workout_repository.dart';

class ExerciseDemoScreen extends ConsumerStatefulWidget {
  const ExerciseDemoScreen({
    required this.exercise,
    this.targetReps,
    this.workoutQueue,
    this.sessionId,
    this.queueIndex = 0,
    this.autoStart = false,
    super.key,
  });

  final RoutineExercise exercise;
  final int? targetReps;
  final List<SessionExercise>? workoutQueue;
  final String? sessionId;
  final int queueIndex;
  final bool autoStart;

  @override
  ConsumerState<ExerciseDemoScreen> createState() => _ExerciseDemoScreenState();
}

class _ExerciseDemoScreenState extends ConsumerState<ExerciseDemoScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _weightController = TextEditingController();
  late List<SessionExercise>? _workoutQueue;
  late int _targetReps;
  int _spokenReps = 0;
  bool _isSavingSet = false;
  bool _isAwaitingSetConfirmation = false;
  bool _isCounting = false;
  bool _isConfigured = false;
  bool _isAdvancing = false;
  bool _isCountdownActive = false;
  bool _speechWarningShown = false;
  int? _countdown;
  int _mediaRetry = 0;

  @override
  void initState() {
    super.initState();
    _workoutQueue = widget.workoutQueue == null
        ? null
        : List<SessionExercise>.of(widget.workoutQueue!);
    _targetReps = widget.targetReps ?? widget.exercise.reps;
    final recommendedWeight =
        _currentSessionExercise?.exercise.recommendedWeightKg;
    _weightController.text = recommendedWeight?.toStringAsFixed(1) ?? '0';
    _configureTts();
  }

  SessionExercise? get _currentSessionExercise {
    final queue = _workoutQueue;
    if (queue == null || widget.queueIndex >= queue.length) return null;
    return queue[widget.queueIndex];
  }

  int get _completedSetCount =>
      _currentSessionExercise?.sets.where((set) => set.completed).length ?? 0;

  bool get _allSetsLogged {
    final exercise = _currentSessionExercise;
    return exercise != null && _completedSetCount >= exercise.targetSets;
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      if (mounted) {
        setState(() => _isConfigured = true);
        if (widget.autoStart) unawaited(_startCountdown());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isConfigured = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voice guide unavailable; you can still start and follow the visual rep timer. $error',
            ),
          ),
        );
        if (widget.autoStart) unawaited(_startCountdown());
      }
    }
  }

  Future<void> _speakPhrase(String phrase) async {
    try {
      await _tts.speak(phrase).timeout(const Duration(seconds: 2));
    } catch (error) {
      if (!mounted || _speechWarningShown) return;
      _speechWarningShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voice guide did not respond; the visual timer will continue. $error',
          ),
        ),
      );
    }
  }

  Future<void> _stopSpeech() async {
    try {
      await _tts.stop().timeout(const Duration(seconds: 1));
    } catch (error) {
      if (!mounted || _speechWarningShown) return;
      _speechWarningShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop the voice guide: $error')),
      );
    }
  }

  Future<void> _startCounting() async {
    if (_isCounting ||
        _isCountdownActive ||
        _isAwaitingSetConfirmation ||
        _allSetsLogged ||
        !_isConfigured) {
      return;
    }
    setState(() {
      _isCounting = true;
      _spokenReps = 0;
    });

    try {
      unawaited(_speakPhrase('Starting. $_targetReps repetitions.'));
      for (var rep = 1; rep <= _targetReps && mounted; rep++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_isCounting) break;
        unawaited(_speakPhrase('$rep'));
        if (!mounted || !_isCounting) break;
        if (mounted) setState(() => _spokenReps = rep);
      }
      if (_isCounting &&
          _spokenReps >= _targetReps &&
          widget.workoutQueue != null) {
        setState(() {
          _isCounting = false;
          _isAwaitingSetConfirmation = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not speak repetition count: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  Future<void> _logGuidedSet() async {
    final sessionId = widget.sessionId;
    final exercise = _currentSessionExercise;
    if (sessionId == null ||
        exercise == null ||
        !_isAwaitingSetConfirmation ||
        _isSavingSet) {
      return;
    }

    final weightKg = double.tryParse(_weightController.text.trim());
    if (weightKg == null || !weightKg.isFinite || weightKg < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid set weight in kilograms.')),
      );
      return;
    }

    final setNumber = _completedSetCount + 1;
    setState(() => _isSavingSet = true);
    try {
      final loggedSet = await ref
          .read(workoutRepositoryProvider)
          .logSet(
            sessionId: sessionId,
            workoutExerciseId: exercise.id,
            setNumber: setNumber,
            weightKg: weightKg,
            reps: _spokenReps,
          );
      if (!mounted) return;

      final updatedQueue = List<SessionExercise>.of(_workoutQueue!);
      updatedQueue[widget.queueIndex] = SessionExercise(
        id: exercise.id,
        exercise: exercise.exercise,
        targetSets: exercise.targetSets,
        targetReps: exercise.targetReps,
        sets: [...exercise.sets, loggedSet]
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
      );
      setState(() {
        _workoutQueue = updatedQueue;
        _isSavingSet = false;
        _isAwaitingSetConfirmation = false;
      });

      if (_completedSetCount >= exercise.targetSets) {
        await _advanceExercise();
      } else {
        await _startCountdown();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingSet = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this set: $error')),
      );
    }
  }

  Future<void> _stopCounting() async {
    setState(() => _isCounting = false);
    await _stopSpeech();
  }

  Future<void> _startCountdown() async {
    if (!_isConfigured || _isCounting || _isCountdownActive || _isAdvancing) {
      return;
    }

    setState(() {
      _isCountdownActive = true;
      _countdown = 3;
    });

    try {
      for (var count = 3; count > 0; count--) {
        if (!mounted || !_isCountdownActive) return;
        setState(() => _countdown = count);
        unawaited(_speakPhrase('$count'));
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (!mounted || !_isCountdownActive) return;
      setState(() {
        _isCountdownActive = false;
        _countdown = null;
      });
      await _startCounting();
    } catch (error) {
      if (!mounted) return;
      final wasCancelled = !_isCountdownActive;
      setState(() {
        _isCountdownActive = false;
        _countdown = null;
      });
      if (!wasCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start the countdown: $error')),
        );
      }
    }
  }

  Future<void> _cancelCountdown() async {
    setState(() {
      _isCountdownActive = false;
      _countdown = null;
    });
    await _stopSpeech();
  }

  Future<void> _advanceExercise() async {
    final queue = _workoutQueue;
    if (queue == null || _isAdvancing) return;

    await _navigateToExercise(widget.queueIndex + 1);
  }

  Future<void> _goBackExercise() async {
    if (widget.queueIndex <= 0 || _isAdvancing) return;
    await _navigateToExercise(widget.queueIndex - 1);
  }

  Future<void> _navigateToExercise(int index) async {
    final queue = _workoutQueue;
    if (queue == null) return;

    _isAdvancing = true;
    setState(() {
      _isCounting = false;
      _isCountdownActive = false;
      _countdown = null;
    });
    await _stopSpeech();
    if (!mounted) return;

    if (index >= queue.length) {
      Navigator.of(context).pop();
      return;
    }
    if (index < 0) return;

    final nextExercise = queue[index];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExerciseDemoScreen(
          exercise: nextExercise.exercise,
          targetReps: nextExercise.targetReps,
          workoutQueue: queue,
          sessionId: widget.sessionId,
          queueIndex: index,
          autoStart:
              queue[index].sets.where((set) => set.completed).length <
              queue[index].targetSets,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    unawaited(_stopSpeech());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final mediaUrl = ref.read(workoutRepositoryProvider).mediaUrlFor(exercise);
    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: Text(exercise.name),
        foregroundColor: const Color(0xFFFF7043),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFF1B1D1F)),
                    child: Image.network(
                      '$mediaUrl?retry=$_mediaRetry',
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF7043),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Animation is temporarily unavailable.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _mediaRetry++),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Animation and exercise data provided by ExerciseDB.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Text(
            exercise.targetMuscle,
            style: const TextStyle(color: Color(0xFFFF7043), fontSize: 16),
          ),
          if (exercise.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              exercise.instructions,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isCounting || _isCountdownActive || _targetReps <= 1
                    ? null
                    : () => setState(() => _targetReps--),
                icon: const Icon(Icons.remove_circle_outline),
                color: const Color(0xFFFF7043),
              ),
              Text(
                '$_targetReps reps',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              IconButton(
                onPressed: _isCounting || _isCountdownActive
                    ? null
                    : () => setState(() => _targetReps++),
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFFF7043),
              ),
            ],
          ),
          Text(
            'Spoken count: $_spokenReps / $_targetReps',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (_countdown != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF2A201D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'NEXT EXERCISE STARTING',
                    style: TextStyle(
                      color: Color(0xFFFFB199),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_workoutQueue != null) ...[
            const SizedBox(height: 12),
            Text(
              'Set ${_completedSetCount + 1} of ${_currentSessionExercise?.targetSets ?? 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              enabled: !_isCounting && !_isCountdownActive && !_isSavingSet,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Weight used',
                suffixText: 'kg',
                filled: true,
                fillColor: const Color(0xFF1B1D1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_isAwaitingSetConfirmation) ...[
              const SizedBox(height: 8),
              const Text(
                'Rep guide complete. Confirm the set only if you completed it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
          if (_workoutQueue != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (widget.queueIndex + 1) / _workoutQueue!.length,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFFFF7043),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Exercise ${widget.queueIndex + 1} of ${_workoutQueue!.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Previous exercise',
                  onPressed: widget.queueIndex == 0 || _isAdvancing
                      ? null
                      : _goBackExercise,
                  icon: const Icon(Icons.skip_previous_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7043),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_isConfigured || _isAdvancing || _isSavingSet
                        || _allSetsLogged
                        ? null
                        : _isCountdownActive
                        ? _cancelCountdown
                        : _isAwaitingSetConfirmation
                        ? _logGuidedSet
                        : _isCounting
                        ? _stopCounting
                        : _startCounting,
                    icon: Icon(
                      _isSavingSet
                          ? Icons.hourglass_top_rounded
                          : _isAwaitingSetConfirmation
                          ? Icons.check_rounded
                          : _isCountdownActive
                          ? Icons.close_rounded
                          : _isCounting
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _isSavingSet
                          ? 'Saving…'
                          : _allSetsLogged
                          ? 'All sets logged'
                          : _isAwaitingSetConfirmation
                          ? 'Log completed set'
                          : _isCountdownActive
                          ? 'Cancel'
                          : _isCounting
                          ? 'Stop'
                          : 'Start',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isAdvancing || _isSavingSet
                      ? null
                      : _advanceExercise,
                  icon: Icon(
                    widget.queueIndex == _workoutQueue!.length - 1
                        ? Icons.done_rounded
                        : Icons.skip_next_rounded,
                  ),
                  label: Text(
                    widget.queueIndex == _workoutQueue!.length - 1
                        ? 'Finish'
                        : 'Skip',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7043),
                    side: const BorderSide(color: Color(0xFFFF7043)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !_isConfigured
                    ? null
                    : _isCounting
                    ? _stopCounting
                    : _startCounting,
                icon: Icon(
                  _isCounting ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_isCounting ? 'Stop rep guide' : 'Start rep guide'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'The voice is a timed guide. It does not detect or verify your movements.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
