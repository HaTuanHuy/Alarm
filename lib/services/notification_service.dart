import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _alarmChannelId = 'alarms_v2';
  static const _alarmChannelName = 'Alarms';
  static const _alarmChannelDesc = 'Alarm notifications';
  static const _timerChannelId = 'countdown_v1';
  static const _timerChannelName = 'Countdown';
  static const _timerChannelDesc = 'Countdown timer notifications';
  static const _countdownNotificationId = 900001;

  Future<void> init() async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        rootNavKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const _AlarmLanding()),
        );
      },
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
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
        priority: Priority.high,
      ),
    );

    await _scheduleWithFallback(
      id: id,
      title: 'Alarm',
      body: label.isEmpty ? 'It\'s time!' : label,
      scheduled: scheduled,
      details: details,
      payload: 'alarm:$id',
      repeatDaily: repeatDaily,
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
        priority: Priority.high,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );

    final scheduled = tz.TZDateTime.from(endsAt, tz.local);

    await _scheduleWithFallback(
      id: _countdownNotificationId,
      title: 'Timer finished',
      body: 'Your countdown has ended.',
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
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
  const _AlarmLanding();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
