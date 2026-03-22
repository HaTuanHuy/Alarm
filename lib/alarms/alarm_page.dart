import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

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
    if (mounted) setState(() {});
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

  void _showScheduledMessage(String base, {int secondOffset = 0}) {
    if (secondOffset <= 0) {
      _showMessage(base);
      return;
    }

    _showMessage(
      '$base. Phát hiện báo thức trùng giờ, đã dời +${secondOffset}s để tránh xúng đột.',
    );
  }

  int _secondOffsetFor(Alarm alarm) {
    final sameMinuteEnabledCount = alarms
        .where(
          (a) =>
              a.id != alarm.id &&
              a.enabled &&
              a.hour == alarm.hour &&
              a.minute == alarm.minute,
        )
        .length;

    if (sameMinuteEnabledCount <= 0) return 0;
    return sameMinuteEnabledCount % 30;
  }

  Future<Alarm> _scheduleAndMerge(Alarm alarm, {int? secondOffset}) async {
    final resolvedSecondOffset = secondOffset ?? _secondOffsetFor(alarm);
    if (Platform.isAndroid) {
      var exactStatus = await Permission.scheduleExactAlarm.status;
      if (!exactStatus.isGranted) {
        exactStatus = await Permission.scheduleExactAlarm.request();
        if (!exactStatus.isGranted) {
          throw Exception('Exact alarm permission required');
        }
      }
      var notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        notifStatus = await Permission.notification.request();
        if (!notifStatus.isGranted) {
          throw Exception('Notification permission required');
        }
      }
    }
    final scheduled = await NotificationService.instance.scheduleAlarm(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      label: alarm.label,
      repeatDaily: alarm.repeatDaily,
      secondOffset: resolvedSecondOffset,
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
        title: const Text('Chi tiết báo thức'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Nhãn'),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setLocal) => SwitchListTile(
                title: const Text('Lặp hàng ngày'),
                value: repeatDaily,
                onChanged: (v) => setLocal(() => repeatDaily = v),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
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
        final secondOffset = _secondOffsetFor(alarm);
        alarms[idx] = await _scheduleAndMerge(
          alarm,
          secondOffset: secondOffset,
        );
        _showScheduledMessage('Đã tạo báo thức', secondOffset: secondOffset);
      }
    } catch (_) {
      if (idx >= 0) {
        alarms[idx] = alarms[idx].copyWith(
          enabled: false,
          clearScheduledAt: true,
        );
      }
      _showMessage(
        'Đã lưu, nhưng lên lịch thất bại. Vui lòng kiểm tra quyền thông báo.',
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
        final secondOffset = _secondOffsetFor(updated);
        updated = await _scheduleAndMerge(updated, secondOffset: secondOffset);
        _showScheduledMessage(
          'Đã cập nhật báo thức',
          secondOffset: secondOffset,
        );
      } catch (_) {
        updated = updated.copyWith(enabled: false, clearScheduledAt: true);
        _showMessage(
          'Đã cập nhật giờ, nhưng lên lịch thất bại. Vui lòng kiểm tra quyền thông báo.',
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
        final secondOffset = _secondOffsetFor(a);
        alarms[idx] = await _scheduleAndMerge(a, secondOffset: secondOffset);
        if (secondOffset > 0) {
          _showScheduledMessage('Đã bật báo thức', secondOffset: secondOffset);
        }
        await _persist();
      } catch (_) {
        alarms[idx] = a.copyWith(enabled: false, clearScheduledAt: true);
        await _persist();
        _showMessage(
          'Không thể bật báo thức. Vui lòng kiểm tra quyền thông báo.',
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
      appBar: AppBar(title: const Text('Báo thức')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAlarm,
        icon: const Icon(Icons.add),
        label: const Text('Thêm báo thức'),
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
                      Text(
                        'Chưa có báo thức',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nhấn Thêm báo thức để tạo nhắc nhở đầu tiên.',
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
                    ? (a.repeatDaily ? 'Hàng ngày' : 'Một lần')
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
                          tooltip: 'Sửa giờ',
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
