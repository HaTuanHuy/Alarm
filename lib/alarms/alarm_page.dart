import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import 'alarm.dart';
import 'alarm_repo.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with WidgetsBindingObserver {
  final repo = AlarmRepo();
  List<Alarm> alarms = [];
  bool loading = true;
  Timer? _expiryWatcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _expiryWatcher = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshExpiredOneTimeAlarms(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshExpiredOneTimeAlarms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryWatcher?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    alarms = await repo.load();
    await _refreshExpiredOneTimeAlarms(shouldSetState: false);
    setState(() => loading = false);
  }

  Future<void> _persist() async {
    await repo.save(alarms);
    setState(() {});
  }

  Future<void> _refreshExpiredOneTimeAlarms({
    bool shouldSetState = true,
  }) async {
    if (alarms.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var changed = false;

    for (var i = 0; i < alarms.length; i++) {
      final a = alarms[i];
      final dueAt = a.scheduledAtEpochMs;
      if (a.enabled && !a.repeatDaily && dueAt != null && nowMs >= dueAt) {
        alarms[i] = a.copyWith(enabled: false, clearScheduledAt: true);
        changed = true;
      }
    }

    if (!changed) return;
    await repo.save(alarms);
    if (shouldSetState && mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Alarm> _scheduleAndMerge(Alarm alarm) async {
    final scheduled = await NotificationService.instance.scheduleAlarm(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      label: alarm.label,
      repeatDaily: alarm.repeatDaily,
    );

    return alarm.copyWith(
      enabled: true,
      scheduledAtEpochMs: alarm.repeatDaily
          ? null
          : scheduled.millisecondsSinceEpoch,
      clearScheduledAt: alarm.repeatDaily,
    );
  }

  Future<void> _addAlarm() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final labelController = TextEditingController();
    bool repeatDaily = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alarm details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setLocal) => SwitchListTile(
                title: const Text('Repeat daily'),
                value: repeatDaily,
                onChanged: (v) => setLocal(() => repeatDaily = v),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final id = await repo.nextId();
    final alarm = Alarm(
      id: id,
      hour: time.hour,
      minute: time.minute,
      label: labelController.text.trim(),
      enabled: true,
      repeatDaily: repeatDaily,
      scheduledAtEpochMs: null,
    );

    alarms = [...alarms, alarm]
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );

    final idx = alarms.indexWhere((x) => x.id == alarm.id);
    try {
      if (idx >= 0) {
        alarms[idx] = await _scheduleAndMerge(alarm);
      }
      _showMessage('Alarm created');
    } catch (_) {
      if (idx >= 0) {
        alarms[idx] = alarms[idx].copyWith(
          enabled: false,
          clearScheduledAt: true,
        );
      }
      _showMessage(
        'Saved, but scheduling failed. Please check notification permissions.',
      );
    }
    await _persist();
  }

  Future<void> _editAlarmTime(Alarm a) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: a.hour, minute: a.minute),
    );
    if (picked == null) return;

    final idx = alarms.indexWhere((x) => x.id == a.id);
    if (idx < 0) return;

    var updated = a.copyWith(
      hour: picked.hour,
      minute: picked.minute,
      clearScheduledAt: true,
    );

    if (updated.enabled) {
      try {
        updated = await _scheduleAndMerge(updated);
        _showMessage('Alarm updated');
      } catch (_) {
        updated = updated.copyWith(enabled: false, clearScheduledAt: true);
        _showMessage(
          'Time updated, but scheduling failed. Please check notification permissions.',
        );
      }
    }

    alarms[idx] = updated;
    alarms.sort(
      (x, y) => (x.hour * 60 + x.minute).compareTo(y.hour * 60 + y.minute),
    );
    await _persist();
  }

  Future<void> _toggle(Alarm a, bool enabled) async {
    final idx = alarms.indexWhere((x) => x.id == a.id);
    if (idx < 0) return;

    if (enabled) {
      try {
        alarms[idx] = await _scheduleAndMerge(a);
        await _persist();
      } catch (_) {
        alarms[idx] = a.copyWith(enabled: false, clearScheduledAt: true);
        await _persist();
        _showMessage(
          'Could not enable alarm. Please check notification permissions.',
        );
      }
      return;
    }

    await NotificationService.instance.cancelAlarm(a.id);
    alarms[idx] = a.copyWith(enabled: false, clearScheduledAt: true);
    await _persist();
  }

  Future<void> _delete(Alarm a) async {
    await NotificationService.instance.cancelAlarm(a.id);
    alarms.removeWhere((x) => x.id == a.id);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('00');

    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAlarm,
        icon: const Icon(Icons.add),
        label: const Text('Add alarm'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : alarms.isEmpty
          ? Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm_off,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text('No alarms yet', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Tap Add alarm to create your first reminder.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: alarms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = alarms[i];
                final time = '${fmt.format(a.hour)}:${fmt.format(a.minute)}';
                final subtitle = a.label.isEmpty
                    ? (a.repeatDaily ? 'Daily' : 'One-time')
                    : a.label;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(subtitle, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Switch(
                          value: a.enabled,
                          onChanged: (v) => _toggle(a, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editAlarmTime(a),
                          tooltip: 'Edit time',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(a),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
