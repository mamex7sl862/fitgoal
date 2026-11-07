import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_repository.dart';
import 'active_workout_screen.dart';
import 'exercise_demo_screen.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({
    this.planDaySelection = false,
    this.defaultSets = 3,
    this.defaultReps = 10,
    this.existingExerciseIds = const {},
    super.key,
  });

  final bool planDaySelection;
  final int defaultSets;
  final int defaultReps;
  final Set<String> existingExerciseIds;

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  static const _equipmentOptions = [
    'BARBELL',
    'DUMBBELL',
    'BODYWEIGHT',
    'CABLE',
    'MACHINE',
  ];
  static const _muscleOptions = [
    'Chest',
    'Back',
    'Shoulders',
    'Upper Arms',
    'Lower Arms',
    'Upper Legs',
    'Lower Legs',
    'Waist',
    'Neck',
    'Cardio',
  ];
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _selectedEquipment = {};
  final Set<String> _selectedMuscles = {};
  final Map<String, RoutineExercise> _selectedExercises = {};
  final List<RoutineExercise> _exercises = [];
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _hasMore = true;
  int _total = 0;
  String? _nextCursor;
  int _requestVersion = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300 &&
        !_isLoading &&
        _hasMore) {
      _load();
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if ((!reset && _isLoading) || (!reset && !_hasMore)) return;
    final requestVersion = reset ? ++_requestVersion : _requestVersion;
    final requestedCursor = reset ? null : _nextCursor;
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _nextCursor = null;
        _hasMore = true;
        _exercises.clear();
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final result = await ref
          .read(workoutRepositoryProvider)
          .searchExercises(
            search: _searchController.text,
            muscles: _selectedMuscles.toList(),
            equipment: _selectedEquipment.toList(),
            cursor: requestedCursor,
            pageSize: 25,
          );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (reset) _exercises.clear();
        _exercises.addAll(result.items);
        _nextCursor = result.nextCursor;
        _hasMore = result.hasMore;
        _total = result.total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101112),
      appBar: AppBar(
        title: const Text('Exercise Library'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFF7043),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _scheduleSearch(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    _load(reset: true);
                  },
                  icon: const Icon(Icons.clear),
                ),
                filled: true,
                fillColor: const Color(0xFF1B1D1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _buildFilters(
            title: 'Muscle groups',
            options: _muscleOptions,
            selected: _selectedMuscles,
            onChanged: (value, selected) =>
                _toggleFilter(_selectedMuscles, value, selected),
          ),
          _buildFilters(
            title: 'Equipment',
            options: _equipmentOptions,
            selected: _selectedEquipment,
            onChanged: (value, selected) =>
                _toggleFilter(_selectedEquipment, value, selected),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_total exercises',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: _exercises.isEmpty && _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF7043)),
                  )
                : _exercises.isEmpty
                ? const Center(
                    child: Text(
                      'No exercises match these filters.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _exercises.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _exercises.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7043),
                            ),
                          ),
                        );
                      }
                      final exercise = _exercises[index];
                      final alreadyInPlan = widget.existingExerciseIds.contains(
                        exercise.id,
                      );
                      final selected =
                          alreadyInPlan ||
                          _selectedExercises.containsKey(exercise.id);
                      final mediaUrl = ref
                          .read(workoutRepositoryProvider)
                          .mediaUrlFor(exercise);
                      return Card(
                        color: const Color(0xFF1B1D1F),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  mediaUrl,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                      ? child
                                      : const SizedBox(
                                          width: 76,
                                          height: 76,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFFF7043),
                                            ),
                                          ),
                                        ),
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 76,
                                    height: 76,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                title: Text(
                                  exercise.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  alreadyInPlan
                                      ? 'Already in this day’s plan'
                                      : '${exercise.targetMuscle} · ${exercise.equipmentRequired.map(_displayName).join(', ')}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ExerciseDemoScreen(exercise: exercise),
                                  ),
                                ),
                              ),
                            ),
                            Checkbox(
                              value: selected,
                              activeColor: const Color(0xFFFF7043),
                              checkColor: Colors.black,
                              onChanged: alreadyInPlan
                                  ? null
                                  : (checked) => setState(() {
                                      if (checked == true) {
                                        _selectedExercises[exercise
                                            .id] = RoutineExercise(
                                          id: exercise.id,
                                          name: exercise.name,
                                          targetMuscle: exercise.targetMuscle,
                                          category: exercise.category,
                                          equipmentRequired:
                                              exercise.equipmentRequired,
                                          instructions: exercise.instructions,
                                          gifUrl: exercise.gifUrl,
                                          sets: widget.defaultSets,
                                          reps: widget.defaultReps,
                                        );
                                      } else {
                                        _selectedExercises.remove(exercise.id);
                                      }
                                    }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _selectedExercises.isEmpty
                ? null
                : widget.planDaySelection
                ? () =>
                      Navigator.pop(context, _selectedExercises.values.toList())
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(
                        initialExercises: _selectedExercises.values.toList(),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              widget.planDaySelection
                  ? 'Add ${_selectedExercises.length} to this day'
                  : 'Start workout (${_selectedExercises.length})',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters({
    required String title,
    required List<String> options,
    required Set<String> selected,
    required void Function(String value, bool selected) onChanged,
  }) {
    return SizedBox(
      height: 74,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: Text(
              '$title: ',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(_displayName(option)),
                selected: selected.contains(option),
                onSelected: (value) => onChanged(option, value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilter(Set<String> filters, String value, bool selected) {
    setState(() {
      if (selected) {
        filters.add(value);
      } else {
        filters.remove(value);
      }
    });
    _load(reset: true);
  }

  String _displayName(String value) =>
      value.isEmpty ? value : value[0] + value.substring(1).toLowerCase();
}
