import 'package:flutter/material.dart';

import 'models/notification_payload.dart';
import 'notifications/notification_service.dart';
import 'screens/detail_screen.dart';
import 'screens/home_screen.dart';

class WorkshopApp extends StatefulWidget {
  const WorkshopApp({
    super.key,
    required this.service,
    required this.initializationError,
  });

  final NotificationService service;
  final String? initializationError;

  @override
  State<WorkshopApp> createState() => _WorkshopAppState();
}

class _WorkshopAppState extends State<WorkshopApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.service.onTap = _openDetail;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initial = widget.service.initialNotification;
      if (initial != null) {
        widget.service.initialNotification = null;
        _openDetail(initial);
      }
    });
  }

  @override
  void dispose() {
    widget.service.onTap = null;
    super.dispose();
  }

  void _openDetail(NotificationPayload payload) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => DetailScreen(payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF1F2F40);
    const blue = Color(0xFF2688BD);
    return MaterialApp(
      title: 'Workshop: Notificações Locais',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: const Color(0xFFF5F8FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: dark,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: HomeScreen(
        service: widget.service,
        initializationError: widget.initializationError,
      ),
    );
  }
}
