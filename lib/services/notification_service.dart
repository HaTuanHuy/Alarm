import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';

/// Tắt báo thức một lần trong SharedPreferences (dùng được từ cả foreground lẫn top-level).
Future<void> _disableOneTimeAlarmInPrefs(int alarmId) async {
  const key = 'alarms_v1';
  final sp = await SharedPreferences.getInstance();
  final raw = sp.getString(key);
  if (raw == null || raw.isEmpty) return;
  final list = jsonDecode(raw) as List;
  var changed = false;
  final updated = list.map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    if (m['id'] == alarmId && m['repeatDaily'] != true) {
      m['enabled'] = false;
      m['scheduledAtEpochMs'] = null;
      changed = true;
    }
    return m;
  }).toList();
  if (changed) {
    await sp.setString(key, jsonEncode(updated));
    debugPrint('🔔 ĐÃ TẮT BÁO THỨC id=$alarmId qua callback thông báo');
  }
}

/// Xử lý khi nhấn thông báo lúc ứng dụng đang chạy nền (cần là hàm top-level).
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse resp) async {
  debugPrint('🔔 THÔNG BÁO NỀN ĐƯỢC NHẤN: ${resp.payload}');
  if (resp.payload?.startsWith('alarm:') == true) {
    final id = int.tryParse(resp.payload!.substring(6));
    if (id != null) await _disableOneTimeAlarmInPrefs(id);
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _alarmChannelId = 'alarms_v3';
  static const _alarmChannelName = 'Báo thức';
  static const _alarmChannelDesc = 'Thông báo báo thức';
  static const _timerChannelId = 'countdown_v1';
  static const _timerChannelName = 'Đếm ngược';
  static const _timerChannelDesc = 'Thông báo đồng hồ đếm ngược';
  static const _countdownNotificationId = 900001;

  Future<void> init() async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        debugPrint('🔔 THÔNG BÁO ĐƯỢC NHẤN: ${resp.payload}');
        if (resp.payload?.startsWith('alarm:') == true) {
          final id = int.tryParse(resp.payload!.substring(6));
          if (id != null) await _disableOneTimeAlarmInPrefs(id);
        }
        rootNavKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => _AlarmLanding(payload: resp.payload),
          ),
        );
      },
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        _alarmChannelName,
        description: _alarmChannelDesc,
        importance: Importance.max,
        // bypassDnd cần quyền "Ưu tiên DND" do người dùng cấp thủ công trong Settings.
        // Không set ở đây để tránh cảnh báo; alarmClock mode + AudioAttributesUsage.alarm
        // đã đảm bảo âm báo thức luôn phát qua kênh alarm, bỏ qua DND.
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _timerChannelId,
        _timerChannelName,
        description: _timerChannelDesc,
        importance: Importance.max,
      ),
    );
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
    // Thoát khỏi tối ưu hóa pin để báo thức không bị trì hoãn
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<DateTime> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    required String label,
    required bool repeatDaily,
    int secondOffset = 0,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      secondOffset,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _alarmChannelId,
        _alarmChannelName,
        channelDescription: _alarmChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await _scheduleWithFallback(
      id: id,
      title: 'Báo thức',
      body: label.isEmpty ? 'Đến giờ rồi!' : label,
      scheduled: scheduled,
      details: details,
      payload: 'alarm:$id',
      repeatDaily: repeatDaily,
      useAlarmClock: true,
    );
    debugPrint(
      '🔔 ĐÃ LÊN LỊCH BÁO THỨC: id=$id lúc ${scheduled.toString()} (lặp=$repeatDaily, lệch=${secondOffset}s)',
    );

    return scheduled;
  }

  Future<void> cancelAlarm(int id) => _plugin.cancel(id);

  Future<void> scheduleCountdownFinished({
    required DateTime endsAt,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        _timerChannelName,
        channelDescription: _timerChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: playSound,
        enableVibration: enableVibration,
        fullScreenIntent: true,
      ),
    );

    final scheduled = tz.TZDateTime.from(endsAt, tz.local);

    await _scheduleWithFallback(
      id: _countdownNotificationId,
      title: 'Hết giờ đếm ngược',
      body: 'Đồng hồ đếm ngược của bạn đã kết thúc.',
      scheduled: scheduled,
      details: details,
      payload: 'countdown:done',
      repeatDaily: false,
    );
  }

  Future<void> cancelCountdownFinished() =>
      _plugin.cancel(_countdownNotificationId);

  Future<void> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required NotificationDetails details,
    required String payload,
    required bool repeatDaily,
    bool useAlarmClock = false,
  }) async {
    // alarmClock mode = AlarmManager.setAlarmClock() — tối ưu nhất cho báo thức,
    // miễn dịch với Doze mode, hiện icon trên status bar.
    // Không hỗ trợ repeatDaily nên chỉ dùng cho báo thức một lần.
    final primaryMode = (useAlarmClock && !repeatDaily)
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: primaryMode,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        payload: payload,
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') {
        rethrow;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        payload: payload,
      );
    }
  }
}

class _AlarmLanding extends StatelessWidget {
  const _AlarmLanding({this.payload});

  final String? payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Lấy nhãn báo thức từ payload nếu có
    final isCountdown = payload?.startsWith('countdown') ?? false;
    final title = isCountdown ? 'Hết giờ!' : 'Báo thức!';
    final icon = isCountdown ? Icons.hourglass_empty : Icons.alarm;

    return Scaffold(
      backgroundColor: Colors.deepOrange.shade800,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 96, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.alarm_off),
                label: const Text(
                  'Tắt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
