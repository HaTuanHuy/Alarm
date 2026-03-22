import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  static const _prefTotalSecondsKey = 'countdown.totalSeconds';
  static const _prefRemainingSecondsKey = 'countdown.remainingSeconds';
  static const _prefRunningKey = 'countdown.running';
  static const _prefEndsAtEpochMsKey = 'countdown.endsAtEpochMs';
  static const _prefSoundKey = 'countdown.notifySound';
  static const _prefVibrationKey = 'countdown.notifyVibration';

  Duration total = Duration.zero;
  Duration remaining = Duration.zero;
  Timer? t;
  bool running = false;
  DateTime? _endsAt;
  bool _playSound = true;
  bool _enableVibration = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTimer();
  }

  Future<void> _loadSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeconds = prefs.getInt(_prefTotalSecondsKey) ?? 0;
    final savedRemaining = prefs.getInt(_prefRemainingSecondsKey);
    final savedRunning = prefs.getBool(_prefRunningKey) ?? false;
    final savedEndsAtEpochMs = prefs.getInt(_prefEndsAtEpochMsKey);
    _playSound = prefs.getBool(_prefSoundKey) ?? true;
    _enableVibration = prefs.getBool(_prefVibrationKey) ?? true;

    if (!mounted) return;

    if (savedSeconds > 0) {
      total = Duration(seconds: savedSeconds);
    }

    if (savedRunning && savedEndsAtEpochMs != null) {
      final endsAt = DateTime.fromMillisecondsSinceEpoch(savedEndsAtEpochMs);
      final left = endsAt.difference(DateTime.now());
      if (left.inSeconds > 0) {
        remaining = left;
        _endsAt = endsAt;
        running = true;
        _runTicker();
        await NotificationService.instance.scheduleCountdownFinished(
          endsAt: endsAt,
          playSound: _playSound,
          enableVibration: _enableVibration,
        );
      } else {
        remaining = Duration.zero;
        running = false;
        _endsAt = null;
        await NotificationService.instance.cancelCountdownFinished();
      }
    } else if (savedRemaining != null && savedRemaining > 0) {
      remaining = Duration(seconds: savedRemaining);
    } else if (savedSeconds > 0) {
      remaining = Duration(seconds: savedSeconds);
    }

    setState(() {});
    await _saveState();
  }

  Future<void> _saveTimer(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTotalSecondsKey, duration.inSeconds);
    await prefs.setInt(_prefRemainingSecondsKey, duration.inSeconds);
    await prefs.setBool(_prefRunningKey, false);
    await prefs.remove(_prefEndsAtEpochMsKey);
  }

  Future<void> _saveNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSoundKey, _playSound);
    await prefs.setBool(_prefVibrationKey, _enableVibration);
  }

  void _scheduleCountdownNotification() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    unawaited(
      NotificationService.instance.scheduleCountdownFinished(
        endsAt: endsAt,
        playSound: _playSound,
        enableVibration: _enableVibration,
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    bool localSound = _playSound;
    bool localVibration = _enableVibration;

    final apply = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thông báo đếm ngược'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Âm thanh'),
                value: localSound,
                onChanged: (v) => setLocal(() => localSound = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rung'),
                value: localVibration,
                onChanged: (v) => setLocal(() => localVibration = v),
              ),
            ],
          ),
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

    if (apply != true) return;

    setState(() {
      _playSound = localSound;
      _enableVibration = localVibration;
    });
    await _saveNotificationPrefs();

    if (running && _endsAt != null) {
      _scheduleCountdownNotification();
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTotalSecondsKey, total.inSeconds);
    await prefs.setInt(_prefRemainingSecondsKey, remaining.inSeconds);
    await prefs.setBool(_prefRunningKey, running);
    if (_endsAt != null) {
      await prefs.setInt(
        _prefEndsAtEpochMsKey,
        _endsAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_prefEndsAtEpochMsKey);
    }
  }

  void _runTicker() {
    t?.cancel();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      final endsAt = _endsAt;
      if (endsAt == null) {
        _pause();
        return;
      }

      final left = endsAt.difference(DateTime.now());
      if (left.inSeconds <= 0) {
        setState(() {
          remaining = Duration.zero;
          running = false;
          _endsAt = null;
        });
        t?.cancel();
        t = null;
        NotificationService.instance.cancelCountdownFinished();
        _saveState();
        return;
      }

      setState(() => remaining = left);
      _saveState();
    });
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _start() {
    if (running) return;
    if (remaining.inSeconds <= 0) {
      _pickDuration();
      return;
    }

    setState(() {
      running = true;
      _endsAt = DateTime.now().add(remaining);
    });
    _scheduleCountdownNotification();
    _runTicker();
    _saveState();
  }

  void _pause() {
    running = false;
    _endsAt = null;
    t?.cancel();
    t = null;
    setState(() {});
    NotificationService.instance.cancelCountdownFinished();
    _saveState();
  }

  void _reset() {
    _pause();
    if (total.inSeconds == 0) return;
    remaining = total;
    setState(() {});
    _saveState();
  }

  Future<void> _pickDuration() async {
    int minutes = total.inMinutes;
    int seconds = total.inSeconds % 60;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đặt thời gian'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(labelText: 'Phút'),
                  items: List.generate(60, (i) => i)
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) => setLocal(() => minutes = v ?? minutes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: seconds,
                  decoration: const InputDecoration(labelText: 'Giây'),
                  items: List.generate(60, (i) => i)
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) => setLocal(() => seconds = v ?? seconds),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final d = Duration(minutes: minutes, seconds: seconds);
      if (d.inSeconds == 0) return;
      total = d;
      remaining = d;
      _pause();
      setState(() {});
      await _saveTimer(d);
      await _saveState();
    }
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total.inSeconds == 0
        ? 0.0
        : (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đếm ngược'),
        actions: [
          IconButton(
            onPressed: _openNotificationSettings,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Cài đặt thông báo',
          ),
          IconButton(
            onPressed: running ? null : _pickDuration,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: progress, strokeWidth: 8),
                    const SizedBox(height: 20),
                    Text(
                      _fmt(remaining),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total.inSeconds == 0
                          ? 'Hãy đặt thời gian'
                          : 'Đặt: ${_fmt(total)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: running ? null : _pickDuration,
                          icon: const Icon(Icons.edit),
                          label: const Text('Đặt thời gian'),
                        ),
                        FilledButton.icon(
                          onPressed: running || total.inSeconds == 0
                              ? null
                              : _start,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Bắt đầu'),
                        ),
                        FilledButton.icon(
                          onPressed: running ? _pause : null,
                          icon: const Icon(Icons.pause),
                          label: const Text('Tạm dừng'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Đặt lại'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
