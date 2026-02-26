import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ClockPage extends StatefulWidget {
  const ClockPage({super.key});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  static const _prefZoneIdKey = 'clock.selectedZoneId';

  late Timer _t;
  DateTime now = DateTime.now();
  List<String> _zoneIds = const [];
  String? _selectedZoneId;
  bool _loadingZones = true;

  @override
  void initState() {
    super.initState();
    _initTimeZones();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => now = DateTime.now());
    });
  }

  Future<void> _initTimeZones() async {
    tz.initializeTimeZones();

    try {
      final local = await FlutterTimezone.getLocalTimezone();
      final available = await FlutterTimezone.getAvailableTimezones();
      final ids =
          available
              .map((z) => z.identifier)
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!ids.contains(local.identifier)) {
        ids.insert(0, local.identifier);
      }

      if (!mounted) return;
      setState(() {
        _zoneIds = ids;
        _selectedZoneId = local.identifier;
        _loadingZones = false;
      });

      await _restoreSavedZone();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedZoneId = tz.local.name;
        _zoneIds = [_selectedZoneId!];
        _loadingZones = false;
      });

      await _restoreSavedZone();
    }
  }

  Future<void> _restoreSavedZone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefZoneIdKey);
    if (saved == null || !_zoneIds.contains(saved) || !mounted) return;
    setState(() => _selectedZoneId = saved);
  }

  Future<void> _saveSelectedZone(String zoneId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefZoneIdKey, zoneId);
  }

  String _formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hh = abs.inHours.toString().padLeft(2, '0');
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  Future<void> _pickTimeZone() async {
    if (_zoneIds.isEmpty) return;

    String query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final filtered = _zoneIds
                .where((id) => id.toLowerCase().contains(query.toLowerCase()))
                .toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 520,
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search timezone',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setLocal(() => query = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final zoneId = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(zoneId),
                              trailing: zoneId == _selectedZoneId
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.pop(context, zoneId),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedZoneId = selected);
      await _saveSelectedZone(selected);
    }
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedId = _selectedZoneId;
    final selectedNow = selectedId == null
        ? now
        : tz.TZDateTime.from(now, tz.getLocation(selectedId));
    final time = DateFormat('HH:mm:ss').format(selectedNow);
    final date = DateFormat('EEE, dd MMM yyyy').format(selectedNow);
    final offset = _formatOffset(selectedNow.timeZoneOffset);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clock'),
        actions: [
          IconButton(
            onPressed: _loadingZones ? null : _pickTimeZone,
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Choose timezone',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current time', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(
                    time,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(date, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _loadingZones ? null : _pickTimeZone,
                    icon: const Icon(Icons.public),
                    label: Text(selectedId ?? 'Loading timezone...'),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(offset),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
