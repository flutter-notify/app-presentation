import 'package:flutter_test/flutter_test.dart';
import 'package:notificacoes_locais_lddm/models/notification_payload.dart';

void main() {
  test('payload preserva tipo, título e descrição', () {
    const original = NotificationPayload(
      kind: 'agendada',
      title: 'Teste',
      description: 'Daqui a um minuto',
    );
    final decoded = NotificationPayload.decode(original.encode());
    expect(decoded?.kind, 'agendada');
    expect(decoded?.title, 'Teste');
    expect(decoded?.description, 'Daqui a um minuto');
  });

  test('descarta payload inválido ou rota inesperada', () {
    expect(NotificationPayload.decode('{invalido'), isNull);
    expect(NotificationPayload.decode('{"route":"/outra"}'), isNull);
    expect(NotificationPayload.decode(null), isNull);
  });
}
