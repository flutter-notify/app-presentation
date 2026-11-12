import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_payload.dart';
import 'sound/web_chime_stub.dart'
    if (dart.library.js_interop) 'sound/web_chime_web.dart' as chime;

/// Uma notificação Web agendada pelo temporizador só é executada se o site
/// permanecer aberto. No Android/iOS o próprio sistema armazena o agendamento.
class ScheduleResult {
  const ScheduleResult({required this.when, required this.exact});

  final DateTime when;
  final bool exact;
}

/// Uma interface só para a UI; a execução respeita as capacidades da plataforma.
/// Flutter Web: notificações do navegador + Timer + sinal sonoro local.
/// Android/iOS: APIs nativas do sistema via flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'alertas_workshop_v2';
  static const _channelName = 'Alertas do workshop';
  static const _channelDescription =
      'Alertas locais de demonstração com som e vibração.';
  static const _minuteId = 2001;
  static const _dailyId = 2002;

  bool get isWeb => kIsWeb;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String get platformDescription => kIsWeb
      ? 'Navegador Web'
      : _isAndroid
          ? 'Android'
          : _isIOS
              ? 'iOS'
              : 'Sistema não configurado';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Map<int, Timer> _webTimers = {};

  NotificationPayload? initialNotification;
  void Function(NotificationPayload payload)? onTap;
  VoidCallback? onScheduleChanged;
  String? lastDeliveryError;
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
    web: WebNotificationDetails(
      requireInteraction: true,
      isSilent: false,
      renotify: true,
    ),
  );

  Future<void> initialize() async {
    tz.initializeTimeZones();
    if (kIsWeb) {
      // O browser já conhece sua hora civil local; o Timer não usa tz.local.
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      timeZoneName = '${DateTime.now().timeZoneName} (UTC${hours >= 0 ? '+' : ''}$hours)';
    } else if (_isAndroid || _isIOS) {
      try {
        final timeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZone.identifier));
        timeZoneName = timeZone.identifier;
      } catch (_) {
        // A notificação relativa (1 minuto) ainda usa um instante correto,
        // mas o recorrente às 08h deve ser bloqueado se não houver fuso IANA.
        tz.setLocalLocation(tz.UTC);
        timeZoneName = 'UTC (fallback)';
        timeZoneIsFallback = true;
      }
    } else {
      throw UnsupportedError('Este workshop executa em Web, Android e iOS.');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      ),
    );

    final initialized = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );
    if (initialized == false) {
      throw StateError('Não foi possível inicializar as notificações.');
    }

    if (_isAndroid) {
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

    // Tocar no aviso quando o app/site estava fechado inicia a rota do payload.
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      initialNotification = NotificationPayload.decode(
        details?.notificationResponse?.payload,
      );
    }
  }

  void _handlePayload(String? raw) {
    final payload = NotificationPayload.decode(raw);
    if (payload != null) onTap?.call(payload);
  }

  /// Deve ser chamado diretamente do clique, antes de qualquer await, para
  /// liberar o AudioContext (gesto do usuário) nos navegadores.
  void prepareUserGesture() {
    if (kIsWeb) chime.unlock();
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final webPlugin = _plugin.resolvePlatformSpecificImplementation<
          WebFlutterLocalNotificationsPlugin>();
      if (webPlugin == null || !WebFlutterLocalNotificationsPlugin.isSupported) {
        return false;
      }
      if (webPlugin.permissionStatus == WebNotificationPermission.granted) {
        return true;
      }
      // A API exige um clique humano para mostrar o prompt.
      return await webPlugin.requestNotificationsPermission() ?? false;
    }
    if (_isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (_isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> notificationsAllowed() async {
    if (kIsWeb) {
      return _plugin
              .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin>()
              ?.permissionStatus ==
          WebNotificationPermission.granted;
    }
    if (_isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (_isIOS) {
      final info = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return info?.isEnabled ?? false;
    }
    return false;
  }

  Future<bool> openNotificationSettings() async {
    if (kIsWeb) return false; // Permissões são gerenciadas pelo navegador.
    return await _plugin.openAppNotificationSettings() ?? false;
  }

  Future<bool> ensurePermission() async {
    // Na Web, solicitar diretamente (se necessário) preserva o gesto de clique.
    if (kIsWeb) return requestPermission();
    if (await notificationsAllowed()) return true;
    return requestPermission();
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!_isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;

    if (await android.canScheduleExactNotifications() ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    await android.requestExactAlarmsPermission();
    if (await android.canScheduleExactNotifications() ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload.encode(),
    );
    if (kIsWeb) chime.play(); // O sistema pode silenciar o som do banner Web.
  }

  Future<void> showNow() => _show(
        id: 1001,
        title: '🔔 Notificação imediata',
        body: 'O próprio dispositivo mostrou este aviso.',
        payload: const NotificationPayload(
          kind: 'Imediata',
          title: 'Notificação imediata',
          description: 'Disparada ao tocar em “Notificar agora”.',
        ),
      );

  Future<void> showDetailNotification() => _show(
        id: 1002,
        title: '📲 Toque para abrir os detalhes',
        body: 'Clique nesta notificação para abrir outra tela.',
        payload: const NotificationPayload(
          kind: 'Navegação via payload',
          title: 'Você chegou pelo aviso!',
          description: 'O payload levou você até a tela de detalhes.',
        ),
      );

  void _webSchedule({
    required int id,
    required DateTime when,
    required Future<void> Function() fire,
  }) {
    _webTimers.remove(id)?.cancel();
    final delay = when.difference(DateTime.now());
    _webTimers[id] = Timer(delay.isNegative ? Duration.zero : delay, () async {
      _webTimers.remove(id);
      onScheduleChanged?.call();
      try {
        if (await notificationsAllowed()) {
          await fire();
        } else {
          lastDeliveryError = 'Permissão de notificações retirada no navegador.';
        }
      } catch (error) {
        lastDeliveryError = 'Falha ao entregar o aviso Web: $error';
      } finally {
        onScheduleChanged?.call();
      }
    });
    onScheduleChanged?.call();
  }

  Future<ScheduleResult> scheduleInOneMinute() async {
    if (kIsWeb) {
      final when = DateTime.now().add(const Duration(minutes: 1));
      _webSchedule(
        id: _minuteId,
        when: when,
        fire: () => _show(
          id: _minuteId,
          title: '⏰ Passou um minuto!',
          body: 'Aviso Web disparado com a página aberta.',
          payload: const NotificationPayload(
            kind: 'Agendada para 1 minuto (Web)',
            title: 'Um minuto se passou',
            description: 'Timer do navegador, não um alarme do sistema.',
          ),
        ),
      );
      return ScheduleResult(when: when, exact: false);
    }

    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    final mode = await _scheduleMode();
    await _plugin.zonedSchedule(
      id: _minuteId,
      title: '⏰ Passou um minuto!',
      body: 'O sistema operacional entregou o aviso agendado.',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: mode,
      payload: const NotificationPayload(
        kind: 'Agendada para 1 minuto',
        title: 'Agendamento concluído',
        description: 'Esta notificação foi disparada pelo sistema.',
      ).encode(),
    );
    return ScheduleResult(
      when: when,
      exact: !_isAndroid || mode == AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  DateTime _nextDailyAtEight() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 8);
    if (!next.isAfter(now)) next = DateTime(now.year, now.month, now.day + 1, 8);
    return next;
  }

  void _armWebDaily() {
    _webSchedule(
      id: _dailyId,
      when: _nextDailyAtEight(),
      fire: () async {
        try {
          await _show(
            id: _dailyId,
            title: '☀️ Lembrete diário',
            body: 'São 08:00! Hora de conferir seus hábitos.',
            payload: const NotificationPayload(
              kind: 'Lembrete diário (Web)',
              title: 'Seu hábito diário',
              description: 'Recorrência simulada no navegador aberto.',
            ),
          );
        } finally {
          // Reagenda a próxima ocorrência apenas enquanto a página existir.
          _armWebDaily();
        }
      },
    );
  }

  Future<ScheduleResult> scheduleDailyAtEight() async {
    if (kIsWeb) {
      final when = _nextDailyAtEight();
      _armWebDaily();
      return ScheduleResult(when: when, exact: false);
    }
    if (timeZoneIsFallback) {
      throw StateError('Fuso IANA indisponível; não é seguro agendar às 08:00.');
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
      exact: !_isAndroid || mode == AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<int> pendingCount() async {
    if (kIsWeb) return _webTimers.length;
    final requests = await _plugin.pendingNotificationRequests();
    return requests.length;
  }

  Future<void> cancelPending() async {
    if (kIsWeb) {
      _webTimers.remove(_minuteId)?.cancel();
      _webTimers.remove(_dailyId)?.cancel();
      onScheduleChanged?.call();
      return;
    }
    await _plugin.cancel(id: _minuteId);
    await _plugin.cancel(id: _dailyId);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      for (final timer in _webTimers.values) {
        timer.cancel();
      }
      _webTimers.clear();
      onScheduleChanged?.call();
    }
    await _plugin.cancelAll();
  }
}
