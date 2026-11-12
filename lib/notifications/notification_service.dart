import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_payload.dart';

class ScheduleResult {
  const ScheduleResult({required this.when, required this.exact});

  final DateTime when;
  final bool exact;
}

/// Toda a lógica de notificações fica fora das telas.
/// Não usa Firebase, internet ou timers de interface.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _channelId = 'alertas_workshop_v1';
  static const _channelName = 'Alertas do workshop';
  static const _channelDescription =
      'Notificações demonstrativas com som e vibração.';
  static const _minuteId = 2001;
  static const _dailyId = 2002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationPayload? initialNotification;
  void Function(NotificationPayload payload)? onTap;
  String timeZoneName = 'não identificado';
  bool timeZoneIsFallback = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'ic_stat_notification',
      ticker: 'Workshop de notificações locais',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    // Banco IANA: horários com fuso; nunca assuma o UTC de servidor.
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
      timeZoneName = timeZone.identifier;
    } catch (_) {
      // 1 minuto a partir de agora continua correto como instante absoluto.
      // Já o lembrete diário às 08:00 requer o fuso correto.
      tz.setLocalLocation(tz.UTC);
      timeZoneName = 'UTC (fallback)';
      timeZoneIsFallback = true;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        // Pedimos ao usuário pelo botão, não durante a inicialização.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
    }

    // Necessário quando o usuário tocou na notificação com o app encerrado.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      initialNotification = NotificationPayload.decode(
        launchDetails?.notificationResponse?.payload,
      );
    }
  }

  void _handlePayload(String? raw) {
    final payload = NotificationPayload.decode(raw);
    if (payload != null) onTap?.call(payload);
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> notificationsAllowed() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      final info = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return info?.isEnabled ?? false;
    }
    return false;
  }

  Future<bool> openNotificationSettings() async =>
      await _plugin.openAppNotificationSettings() ?? false;

  Future<bool> ensurePermission() async {
    if (await notificationsAllowed()) return true;
    return requestPermission();
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;

    if (await android.canScheduleExactNotifications() ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    // Android 12+/14+: pode abrir tela especial de autorização de alarmes.
    await android.requestExactAlarmsPermission();
    if (await android.canScheduleExactNotifications() ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    // Entrega pode atrasar: não prometemos exatidão sem essa permissão.
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> showNow() async {
    await _plugin.show(
      id: 1001,
      title: '🔔 Notificação imediata',
      body: 'O próprio aparelho mostrou este aviso com som.',
      notificationDetails: _details,
      payload: const NotificationPayload(
        kind: 'Imediata',
        title: 'Notificação imediata',
        description: 'Disparada ao tocar no botão “Notificar agora”.',
      ).encode(),
    );
  }

  Future<void> showDetailNotification() async {
    await _plugin.show(
      id: 1002,
      title: '📲 Toque para abrir o detalhe',
      body: 'Experimente tocar nesta notificação.',
      notificationDetails: _details,
      payload: const NotificationPayload(
        kind: 'Navegação via payload',
        title: 'Você chegou pelo aviso!',
        description:
            'O payload foi recebido e o app navegou para a tela de detalhes.',
      ).encode(),
    );
  }

  Future<ScheduleResult> scheduleInOneMinute() async {
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    final mode = await _scheduleMode();
    await _plugin.zonedSchedule(
      id: _minuteId,
      title: '⏰ Passou um minuto!',
      body: 'A notificação foi agendada localmente, sem servidor.',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: mode,
      payload: const NotificationPayload(
        kind: 'Agendada para 1 minuto',
        title: 'Agendamento concluído',
        description: 'Esta notificação foi disparada pelo sistema operacional.',
      ).encode(),
    );
    return ScheduleResult(
      when: when,
      exact: !Platform.isAndroid || mode == AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<ScheduleResult> scheduleDailyAtEight() async {
    if (timeZoneIsFallback) {
      throw StateError(
        'Fuso do aparelho indisponível: configure o fuso antes de agendar '
        'um horário local recorrente.',
      );
    }
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 8);
    }
    final mode = await _scheduleMode();
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: '☀️ Lembrete diário',
      body: 'São 08:00: hora de conferir seus hábitos!',
      scheduledDate: next,
      notificationDetails: _details,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: const NotificationPayload(
        kind: 'Recorrente, todos os dias às 08:00',
        title: 'Seu hábito diário',
        description: 'O aviso foi configurado para repetir diariamente.',
      ).encode(),
    );
    return ScheduleResult(
      when: next,
      exact: !Platform.isAndroid || mode == AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<int> pendingCount() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.length;
  }

  Future<void> cancelPending() async {
    await _plugin.cancel(id: _minuteId);
    await _plugin.cancel(id: _dailyId);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
