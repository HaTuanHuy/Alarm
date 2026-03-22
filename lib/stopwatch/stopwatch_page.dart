import 'dart:async';
import 'package:flutter/material.dart';

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  final Stopwatch sw = Stopwatch();
  Timer? t;
  final List<Duration> laps = [];

  String _fmt(Duration d) {
    final ms = d.inMilliseconds;
    final hh = (ms ~/ 3600000).toString().padLeft(2, '0');
    final mm = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final ss = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0'); // centiseconds
    return '$hh:$mm:$ss.$cs';
  }

  void _start() {
    sw.start();
    t ??= Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => setState(() {}),
    );
    setState(() {});
  }

  void _pause() {
    sw.stop();
    setState(() {});
  }

  void _reset() {
    sw.reset();
    laps.clear();
    setState(() {});
  }

  void _lap() {
    if (!sw.isRunning) return;
    laps.insert(0, sw.elapsed);
    setState(() {});
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsedMs = sw.elapsed.inMilliseconds;
    final running = sw.isRunning;
    final secondProgress = (elapsedMs % 1000) / 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Bấm giờ')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: running ? secondProgress : 0,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _fmt(sw.elapsed),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: running ? null : _start,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Bắt đầu'),
                        ),
                        FilledButton.icon(
                          onPressed: running ? _pause : null,
                          icon: const Icon(Icons.pause),
                          label: const Text('Tạm dừng'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _lap,
                          icon: const Icon(Icons.flag),
                          label: const Text('Vòng'),
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
            const SizedBox(height: 12),
            Expanded(
              child: laps.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có vòng nào',
                        style: theme.textTheme.titleMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: laps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${laps.length - i}'),
                          ),
                          title: Text('Vòng ${laps.length - i}'),
                          trailing: Text(_fmt(laps[i])),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
