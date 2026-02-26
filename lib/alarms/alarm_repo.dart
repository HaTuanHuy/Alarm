import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm.dart';

class AlarmRepo {
  static const _key = 'alarms_v1';
  static const _nextIdKey = 'alarms_next_id_v1';

  Future<List<Alarm>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Alarm.fromJson).toList()..sort(_sortByTime);
  }

  Future<void> save(List<Alarm> alarms) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await sp.setString(_key, raw);
  }

  Future<int> nextId() async {
    final sp = await SharedPreferences.getInstance();
    final cur = sp.getInt(_nextIdKey) ?? 1;
    await sp.setInt(_nextIdKey, cur + 1);
    return cur;
  }

  static int _sortByTime(Alarm a, Alarm b) {
    final aa = a.hour * 60 + a.minute;
    final bb = b.hour * 60 + b.minute;
    return aa.compareTo(bb);
  }
}