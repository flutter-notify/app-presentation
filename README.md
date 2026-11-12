# Workshop Técnico · Notificações Locais

Aplicativo didático em **Flutter (Android e iOS)** que acompanha os slides da disciplina **Laboratório de Desenvolvimento para Dispositivos Móveis (PUC Minas)**.

**Integrantes**

- Rafael Xavier Oliveira
- Leonardo Stuart de Almeida Ramalho
- Luca Guimarães Lodi
- Gabriel Teotônio de Castro Coelho Costa
- Gabriel Benício Fonseca do Nascimento

## Funcionalidades

| Botão | Demonstra | Método |
| --- | --- | --- |
| Notificar agora | Alerta local imediato com som do sistema e vibração compatível | `show()` |
| Agendar para 1 minuto | Alerta futuro que pode chegar com o app em segundo plano ou fechado | `zonedSchedule()` |
| Toque abre a tela de detalhes | Navegação por `payload` com app aberto ou iniciado por toque | `getNotificationAppLaunchDetails()` + callback |
| Repetir todo dia às 08:00 | Agendamento recorrente no fuso do dispositivo | `zonedSchedule(matchDateTimeComponents: DateTimeComponents.time)` |
| Permitir / Ajustes | Solicitação e recuperação de permissão negada | Android 13+ / iOS |
| Cancelar agendamentos | Cancela aviso de 1 minuto e aviso diário | `cancel(id: ...)` |

**Não precisa de Firebase, servidor, internet, APNs ou FCM.** Tudo é agendado localmente. O pacote é `flutter_local_notifications` **22.3.3**, fixado para compatibilidade mais ampla com Flutter 3.38.1+ e o Android SDK 36 (a versão 23 exige um setup mais novo).

## 1. Pré-requisitos

- Flutter **3.38.1+** e Dart compatível (`flutter --version`);
- Java 17, Android SDK **API 36**, Android Studio/emulador ou celular Android;
- Para iOS: **macOS + Xcode + CocoaPods** e simulador ou iPhone. Um dispositivo físico é ideal para validar o som;
- Python 3 disponível como `python3` para aplicar as configurações nativas.

Confira o ambiente:

```bash
flutter doctor -v
```

> O ZIP contém **todo o código Dart, testes, manifesto Android, ícone e configuração iOS**. O Flutter gera os arquivos padronizados de Gradle/Xcode para a versão instalada no seu computador. O script abaixo faz essa geração e aplica automaticamente as configurações específicas. Não é necessário editar arquivos manualmente.

## 2. Primeira execução (macOS / Linux)

```bash
unzip notificacoes_locais_lddm.zip
cd notificacoes_locais_lddm
bash prepare.sh
flutter analyze
flutter test
flutter run
```

Se preferir escolher o dispositivo:

```bash
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

Se `flutter doctor` identificar componentes faltantes, instale primeiro os componentes indicados. Em iOS, se houver erro na instalação dos pods, no macOS, rode `cd ios && pod install && cd ..` após preparar o projeto. No iPhone real, defina seu time de assinatura em `ios/Runner.xcworkspace` no Xcode (Signing & Capabilities).

Para executar de novo depois, basta `flutter run`; não é necessário reaplicar o setup em toda execução.

## 3. Roteiro da demonstração (3 testes obrigatórios)

1. **Permissões:** abra o aplicativo e toque em **Permitir avisos**. Aceite alertas e sons no Android/iOS. Retire o aparelho do silencioso e de Não Perturbe.
2. **Imediata:** clique em **Notificar agora**. Observe o alerta e ouça o som do sistema.
3. **Agendada:** clique em **Agendar para 1 minuto**. Se o Android solicitar permissão especial para alarmes exatos, conceda. Vá para a tela inicial do celular ou feche o app normalmente. Aguarde a notificação, que o sistema deve entregar. Alguns modos de bateria podem atrasá-la.
4. **Navegação:** clique em **Toque abre a tela de detalhes**. Toque na notificação; será aberta a rota `/detalhe`, exibindo o conteúdo do payload. Teste novamente com o app fechado para demonstrar `getNotificationAppLaunchDetails()`.
5. **Recorrência:** toque em **Repetir todo dia às 08:00**, confira o contador de pendências e explique `DateTimeComponents.time`. Use **Cancelar agendamentos** ao final para evitar notificações futuras do dispositivo da apresentação.

### É possível *forçar* a notificação a apitar?

O aplicativo solicita o som padrão **ligado** nos detalhes do aviso e no canal Android `alertas_workshop_v1` (importância máxima). O sistema operacional é quem toca o som. **Não é possível garantir áudio** quando o aparelho está no silencioso, em Não Perturbe/foco, com volume de alertas zerado, ou se o usuário silenciou as notificações/canal do app. No iOS, o interruptor de silencioso e o modo Foco influenciam a reprodução. No Android, confirme `Configurações > Apps > Workshop Notificações > Notificações > Alertas do workshop > Som`.

No **Android 8+**, canais são persistentes: alterar `playSound` ou importância no código **não altera o canal que já existe**. Se você testou com som desligado, ajuste o canal manualmente ou reinstale o app. No Android 13+, aceite `POST_NOTIFICATIONS` em tempo de execução.

### Precisão do agendamento no Android

O Android 12+/14+ pode restringir alarmes exatos: o exemplo declara `SCHEDULE_EXACT_ALARM` e pede permissão quando necessário. Quando não é concedida, o aplicativo faz **fallback para modo inexato**, mostrando uma mensagem de aviso. Economia de bateria e restrições do fabricante também podem atrasar a entrega. Para a demonstração de 1 minuto ser pontual, conceda a permissão especial e desative otimizações agressivas de bateria se necessário.

Em iOS, o pedido de autorização usa `requestPermissions(alert: true, badge: true, sound: true)`. Os alertas agendados usam um fuso identificado com `flutter_timezone` e a biblioteca `timezone`.

## 4. Estrutura do projeto

```text
notificacoes_locais_lddm/
├── lib/
│   ├── main.dart                      # inicializa o plugin antes do runApp
│   ├── app.dart                       # navigatorKey e payload do app fechado
│   ├── models/notification_payload.dart
│   ├── notifications/notification_service.dart  # permissões, canal e agendamentos
│   └── screens/
│       ├── home_screen.dart           # interface dos 4 experimentos
│       └── detail_screen.dart         # rota aberta pelo toque
├── test/                              # testes unitários e widget
├── native_overrides/
│   ├── android/.../AndroidManifest.xml
│   ├── android/.../ic_stat_notification.png
│   └── ios/Runner/AppDelegate.swift
├── scripts/apply_native_overrides.py # configura Android/iOS após flutter create
├── prepare.sh                        # comando único de instalação
├── pubspec.yaml
└── README.md
```

O diretório `android/` e o diretório `ios/` são criados pelo Flutter executando `bash prepare.sh`. Depois disso, são diretórios normais do projeto e podem ser **versionados no GitHub**. O script é idempotente: também pode ser reexecutado para reaplicar as opções nativas.

## 5. O que cada parte faz

- **`initialize`**: configura plugin, fuso IANA e canal Android com importância alta, som e vibração.
- **`requestPermission`**: diferencia concessão no Android e iOS; oferece caminho para Ajustes se negada.
- **`showNow`**: cria uma notificação local imediata (ID 1001).
- **`scheduleInOneMinute`**: calcula `tz.TZDateTime.now(tz.local) + 1 minuto`, usa o AndroidScheduleMode apropriado (ID 2001).
- **`scheduleDailyAtEight`**: calcula a próxima ocorrência às 08:00 no fuso atual, com repetição diária (ID 2002).
- **`showDetailNotification`**: mostra aviso com payload JSON com rota `/detalhe` (ID 1002).
- **`getNotificationAppLaunchDetails`**: identifica o toque que iniciou o aplicativo antes de `runApp`.
- **`onDidReceiveNotificationResponse`**: recebe o toque quando a aplicação já existe.
- **`navigatorKey`**: abre `DetailScreen` sem exigir um `BuildContext` da notificação.

## 6. Como publicar no GitHub

Após executar `bash prepare.sh` e validar o funcionamento:

```bash
git init
git add .
git commit -m "feat: workshop Flutter notificacoes locais Android iOS"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

Crie previamente o repositório vazio no GitHub. **Atualize o último slide** com a URL real do projeto, conforme o enunciado da disciplina.

## 7. Referências técnicas

- https://pub.dev/packages/flutter_local_notifications/versions/22.3.3
- https://pub.dev/packages/flutter_timezone
- https://pub.dev/packages/timezone
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://developer.android.com/develop/background-work/services/alarms/schedule
- https://developer.apple.com/documentation/usernotifications

## Limitações honestas

O código e o setup foram verificados estaticamente. **O ambiente usado para montar este ZIP não contém Flutter, Android SDK ou Xcode**, portanto a compilação/execução em um dispositivo físico precisa ser feita no seu computador com os comandos acima. Notificações agendadas não ficam garantidas se o usuário revogar permissões, reiniciar sem as condições de restauração, fizer *force stop* do aplicativo no Android, ou se o sistema restringir a entrega.
