import 'package:flutter/material.dart';

import '../notifications/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.service,
    required this.initializationError,
  });

  final NotificationService service;
  final String? initializationError;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool? _allowed;
  int? _pending;
  String _message = 'Conceda a permissão e escolha um teste abaixo.';

  bool get _isReady => widget.initializationError == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isReady) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final enabled = await widget.service.notificationsAllowed();
      final count = await widget.service.pendingCount();
      if (!mounted) return;
      setState(() {
        _allowed = enabled;
        _pending = count;
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Não foi possível verificar: $error');
    }
  }

  Future<void> _run(Future<String> Function() task) async {
    if (!_isReady || _busy) return;
    setState(() => _busy = true);
    try {
      final text = await task();
      if (!mounted) return;
      setState(() => _message = text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Falha: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _withPermission(Future<String> Function() action) async {
    await _run(() async {
      if (!await widget.service.ensurePermission()) {
        return 'Permissão negada. Abra os ajustes de notificações do app '
            'para permitir alertas e som.';
      }
      return action();
    });
  }

  String _time(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações locais'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar status',
            onPressed: _isReady ? _refresh : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                const _IntroBanner(),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _allowed == true
                                  ? Icons.verified_outlined
                                  : Icons.shield_outlined,
                              color: _allowed == true
                                  ? Colors.green.shade700
                                  : const Color(0xFF916B1D),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Permissão: ${_allowed == null ? 'verificando...' : _allowed! ? 'concedida' : 'não concedida'}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Fuso: ${widget.service.timeZoneName}'),
                        Text('Agendamentos pendentes: ${_pending ?? '...'}'),
                        if (widget.service.timeZoneIsFallback)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Atenção: fuso real não identificado; a recorrência diária está desabilitada.',
                            ),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _isReady && !_busy
                                  ? () => _run(() async {
                                        final granted = await widget.service
                                            .requestPermission();
                                        return granted
                                            ? 'Permissão concedida. Agora os avisos podem aparecer.'
                                            : 'Permissão não concedida. Abra os ajustes do aparelho.';
                                      })
                                  : null,
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Permitir avisos'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isReady && !_busy
                                  ? () => _run(() async {
                                        final opened = await widget.service
                                            .openNotificationSettings();
                                        return opened
                                            ? 'Confira se alertas e som estão ligados nos ajustes.'
                                            : 'Abra manualmente as configurações de notificações do app.';
                                      })
                                  : null,
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Ajustes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.initializationError != null)
                  Card(
                    color: const Color(0xFFFFE9E9),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: SelectableText(
                        'Não foi possível inicializar o plugin:\n${widget.initializationError}',
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Experimentos', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text('Execute cada um durante a apresentação.'),
                        const SizedBox(height: 18),
                        _DemoAction(
                          number: '01',
                          title: 'Notificar agora',
                          description: 'Chama show(); o aviso deve aparecer e tocar.',
                          icon: Icons.notifications_active_outlined,
                          onPressed: !_isReady || _busy
                              ? null
                              : () => _withPermission(() async {
                                    await widget.service.showNow();
                                    return 'Notificação imediata enviada ao sistema.';
                                  }),
                        ),
                        const Divider(height: 28),
                        _DemoAction(
                          number: '02',
                          title: 'Agendar para 1 minuto',
                          description: 'Chama zonedSchedule(); pode testar com o app fechado.',
                          icon: Icons.access_time,
                          onPressed: !_isReady || _busy
                              ? null
                              : () => _withPermission(() async {
                                    final result = await widget.service
                                        .scheduleInOneMinute();
                                    return 'Programada para ${_time(result.when)}. '
                                        '${result.exact ? 'Modo exato solicitado.' : 'Modo inexato: o Android pode atrasar.'}';
                                  }),
                        ),
                        const Divider(height: 28),
                        _DemoAction(
                          number: '03',
                          title: 'Toque abre a tela de detalhes',
                          description: 'O payload informa a rota e os dados do aviso.',
                          icon: Icons.open_in_new,
                          onPressed: !_isReady || _busy
                              ? null
                              : () => _withPermission(() async {
                                    await widget.service.showDetailNotification();
                                    return 'Aviso enviado. Toque nele para navegar para /detalhe.';
                                  }),
                        ),
                        const Divider(height: 28),
                        _DemoAction(
                          number: '04',
                          title: 'Repetir todo dia às 08:00',
                          description: 'Recorrência com fuso e DateTimeComponents.time.',
                          icon: Icons.event_repeat,
                          onPressed: !_isReady || _busy ||
                                  widget.service.timeZoneIsFallback
                              ? null
                              : () => _withPermission(() async {
                                    final result = await widget.service
                                        .scheduleDailyAtEight();
                                    return 'Próximo aviso às ${_time(result.when)}; '
                                        'repete todos os dias. ${result.exact ? 'Exato.' : 'Pode atrasar no Android.'}';
                                  }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFFE6F0F7),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resultado', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(_message),
                        if (_busy) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !_isReady || _busy
                          ? null
                          : () => _run(() async {
                                await widget.service.cancelPending();
                                return 'Agendamento de 1 minuto e recorrência removidos.';
                              }),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: const Text('Cancelar agendamentos'),
                    ),
                    TextButton.icon(
                      onPressed: !_isReady || _busy
                          ? null
                          : () => _run(() async {
                                await widget.service.cancelAll();
                                return 'Todos os avisos do aplicativo foram cancelados.';
                              }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Limpar todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'O som depende do volume, do modo silencioso, do Não Perturbe e das configurações do canal (Android). Não é possível forçar áudio contra essas escolhas do sistema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF5C6773)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2F40),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(22),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WORKSHOP TÉCNICO · LDDM',
            style: TextStyle(color: Color(0xFF79C6F0), letterSpacing: 1.2),
          ),
          SizedBox(height: 8),
          Text(
            'Quem avisa é o próprio aparelho.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Flutter • Android • iOS • sem Firebase ou servidor',
            style: TextStyle(color: Color(0xFFE1E9F0)),
          ),
        ],
      ),
    );
  }
}

class _DemoAction extends StatelessWidget {
  const _DemoAction({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE1EFF8),
          child: Text(number, style: const TextStyle(color: Color(0xFF235F80))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(description),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: const Text('Executar teste'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
