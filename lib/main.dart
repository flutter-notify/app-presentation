import 'package:flutter/material.dart';

import 'app.dart';
import 'notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = NotificationService.instance;
  String? initializationError;
  try {
    await service.initialize();
  } catch (error) {
    initializationError = error.toString();
  }
  runApp(WorkshopApp(
    service: service,
    initializationError: initializationError,
  ));
}
