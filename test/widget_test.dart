import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notificacoes_locais_lddm/models/notification_payload.dart';
import 'package:notificacoes_locais_lddm/screens/detail_screen.dart';

void main() {
  testWidgets('a tela de destino mostra dados do payload', (tester) async {
    const payload = NotificationPayload(
      kind: 'teste',
      title: 'Detalhe do workshop',
      description: 'Abriu a tela correta',
    );
    await tester.pumpWidget(
      const MaterialApp(home: DetailScreen(payload: payload)),
    );
    expect(find.text('Detalhe do workshop'), findsOneWidget);
    expect(find.text('Abriu a tela correta'), findsOneWidget);
  });
}
