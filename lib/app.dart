import 'package:flutter/material.dart';
import 'alarms/alarm_page.dart';
import 'clock/clock_page.dart';
import 'stopwatch/stopwatch_page.dart';
import 'timer/countdown_page.dart';

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavKey,
      debugShowCheckedModeBanner: false,
      title: 'Đồng hồ',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  final pages = const [
    ClockPage(),
    AlarmPage(),
    StopwatchPage(),
    CountdownPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerHighest, scheme.surface],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.access_time_outlined),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'Đồng hồ',
            ),
            NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm),
              label: 'Báo thức',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Bấm giờ',
            ),
            NavigationDestination(
              icon: Icon(Icons.hourglass_bottom_outlined),
              selectedIcon: Icon(Icons.hourglass_bottom),
              label: 'Hẹn giờ',
            ),
          ],
        ),
      ),
    );
  }
}
