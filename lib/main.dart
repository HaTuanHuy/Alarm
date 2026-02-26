import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); // permissions + timezone + plugin init
  runApp(const MyApp());
}