import 'package:flutter/material.dart';

import '../models/notification_payload.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.payload});

  final NotificationPayload payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tela específica')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 76,
                    color: Color(0xFF2688BD),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    payload.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    payload.description,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payload recebido'),
                          const SizedBox(height: 8),
                          SelectableText('tipo: ${payload.kind}'),
                          const SelectableText(
                            'route: ${NotificationPayload.detailRoute}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Voltar ao workshop'),
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
