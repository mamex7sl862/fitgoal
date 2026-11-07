import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reminder_notification_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  static const _workoutEnabledKey = 'workoutReminderEnabled';
  static const _waterEnabledKey = 'waterReminderEnabled';
  static const _workoutHourKey = 'workoutReminderHour';
  static const _workoutMinuteKey = 'workoutReminderMinute';
  static const _waterHourKey = 'waterReminderHour';
  static const _waterMinuteKey = 'waterReminderMinute';

  bool _isLoading = true;
  bool _workoutEnabled = false;
  bool _waterEnabled = false;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _waterTime = const TimeOfDay(hour: 10, minute: 0);
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await ReminderNotificationService.instance.initialize();
      final workoutTime = TimeOfDay(
        hour: prefs.getInt(_workoutHourKey) ?? 18,
        minute: prefs.getInt(_workoutMinuteKey) ?? 0,
      );
      final waterTime = TimeOfDay(
        hour: prefs.getInt(_waterHourKey) ?? 10,
        minute: prefs.getInt(_waterMinuteKey) ?? 0,
      );
      final workoutEnabled = prefs.getBool(_workoutEnabledKey) ?? false;
      final waterEnabled = prefs.getBool(_waterEnabledKey) ?? false;

      if (workoutEnabled) {
        await ReminderNotificationService.instance.scheduleWorkoutReminder(
          hour: workoutTime.hour,
          minute: workoutTime.minute,
        );
      }
      if (waterEnabled) {
        await ReminderNotificationService.instance.scheduleWaterReminder(
          hour: waterTime.hour,
          minute: waterTime.minute,
        );
      }

      if (!mounted) return;
      setState(() {
        _workoutEnabled = workoutEnabled;
        _waterEnabled = waterEnabled;
        _workoutTime = workoutTime;
        _waterTime = waterTime;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load reminder settings: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _setReminderEnabled({
    required bool isWorkout,
    required bool enabled,
  }) async {
    final service = ReminderNotificationService.instance;
    final previousValue = isWorkout ? _workoutEnabled : _waterEnabled;

    try {
      if (enabled && !await service.requestPermission()) {
        _showMessage(
          kIsWeb
              ? 'Allow browser notifications for FitGoal to enable reminders.'
              : 'Allow notifications in your device settings to enable reminders.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (isWorkout) {
        if (enabled) {
          await service.scheduleWorkoutReminder(
            hour: _workoutTime.hour,
            minute: _workoutTime.minute,
          );
        } else {
          await service.cancelWorkoutReminder();
        }
        await prefs.setBool(_workoutEnabledKey, enabled);
      } else {
        if (enabled) {
          await service.scheduleWaterReminder(
            hour: _waterTime.hour,
            minute: _waterTime.minute,
          );
        } else {
          await service.cancelWaterReminder();
        }
        await prefs.setBool(_waterEnabledKey, enabled);
      }

      if (!mounted) return;
      setState(() {
        if (isWorkout) {
          _workoutEnabled = enabled;
        } else {
          _waterEnabled = enabled;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isWorkout) {
          _workoutEnabled = previousValue;
        } else {
          _waterEnabled = previousValue;
        }
      });
      _showMessage('Could not update reminder: $error');
    }
  }

  Future<void> _chooseTime({required bool isWorkout}) async {
    final currentTime = isWorkout ? _workoutTime : _waterTime;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (selectedTime == null || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (isWorkout) {
        await prefs.setInt(_workoutHourKey, selectedTime.hour);
        await prefs.setInt(_workoutMinuteKey, selectedTime.minute);
        if (_workoutEnabled) {
          await ReminderNotificationService.instance.scheduleWorkoutReminder(
            hour: selectedTime.hour,
            minute: selectedTime.minute,
          );
        }
      } else {
        await prefs.setInt(_waterHourKey, selectedTime.hour);
        await prefs.setInt(_waterMinuteKey, selectedTime.minute);
        if (_waterEnabled) {
          await ReminderNotificationService.instance.scheduleWaterReminder(
            hour: selectedTime.hour,
            minute: selectedTime.minute,
          );
        }
      }
      setState(() {
        if (isWorkout) {
          _workoutTime = selectedTime;
        } else {
          _waterTime = selectedTime;
        }
      });
    } catch (error) {
      _showMessage('Could not save reminder time: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & Notifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (kIsWeb)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Browser reminders run while FitGoal is open in this tab. Keep the tab open and allow notifications for this site.',
                      ),
                    ),
                  ),
                _reminderCard(
                  title: 'Workout reminder',
                  description: 'Get a daily reminder to complete a workout.',
                  enabled: _workoutEnabled,
                  time: _workoutTime,
                  onChanged: (enabled) =>
                      _setReminderEnabled(isWorkout: true, enabled: enabled),
                  onTimeTap: () => _chooseTime(isWorkout: true),
                ),
                const SizedBox(height: 12),
                _reminderCard(
                  title: 'Water reminder',
                  description: 'Get a daily reminder to drink water.',
                  enabled: _waterEnabled,
                  time: _waterTime,
                  onChanged: (enabled) =>
                      _setReminderEnabled(isWorkout: false, enabled: enabled),
                  onTimeTap: () => _chooseTime(isWorkout: false),
                ),
              ],
            ),
    );
  }

  Widget _reminderCard({
    required String title,
    required String description,
    required bool enabled,
    required TimeOfDay time,
    required ValueChanged<bool>? onChanged,
    required VoidCallback? onTimeTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: Text(description),
              value: enabled,
              onChanged: onChanged,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time'),
              trailing: TextButton(
                onPressed: onTimeTap,
                child: Text(time.format(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
