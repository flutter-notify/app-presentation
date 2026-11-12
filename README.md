# Workshop técnico LDDM — Notificações locais (Flutter)

Projeto de demonstração para a **PUC Minas**, compatível com **Android, iOS e navegador Web**, com quatro experimentos, solicitação de permissões, som e navegação por `payload`.

**Autores:** Rafael Xavier Oliveira · Leonardo Stuart de Almeida Ramalho · Luca Guimarães Lodi · Gabriel Teotônio de Castro Coelho Costa · Gabriel Benício Fonseca do Nascimento.

## O que roda em cada plataforma

| Experimento | Android | iOS | Web (Chrome/Edge, Firefox, Safari*) |
|---|---|---|---|
| Notificar agora | Notificação do Android | Notificação do iOS | Notificação real do navegador |
| Agendar para daqui a 1 minuto | Agendamento nativo `zonedSchedule` | Agendamento nativo `zonedSchedule` | **Timer da aba aberta** + notificação Web |
| Tocar para abrir `/detalhe` | `payload` + callback/launch details | `payload` + callback/launch details | `payload` + service worker/URL de lançamento do plugin |
| Repetir diariamente às 08h | Agendamento recorrente nativo | Agendamento recorrente nativo | **Timer diário enquanto a aba permanecer aberta** |
| Som | Som padrão do canal Android | Som padrão de notificação do iOS | Som do sistema, **mais apito gerado pela página (Web Audio)** quando liberado pelo clique |

\* Em navegadores móveis, em especial Safari do iOS, notificações Web exigem condições e restrições adicionais do navegador/sistema (por exemplo, um web app adicionado à tela de início). **A apresentação mais estável no PC é Chrome ou Edge no macOS/Windows/Linux.**

**Por que o agendamento na Web é diferente?** Navegadores não possuem uma API padrão para agendar notificações persistentes offline e independentes da aba. A versão Web usa `Timer`; o aviso de 1 minuto funciona **com a aba aberta**, podendo atrasar quando suspensa. Fechar/recarregar a página interrompe o agendamento. Isso é um limite real, e está indicado também na própria interface. Para notificações quando o navegador está fechado, seria necessária outra arquitetura, normalmente Web Push com um servidor e uma inscrição do navegador — **não é notificação local independente de servidor**.

A versão mobile agendada é feita pelo sistema operacional e pode funcionar com o app fechado; exatidão e som ainda dependem das autorizações e restrições do dispositivo.

## Pré-requisitos

- Flutter **3.38.1+** e Dart correspondente (`flutter --version` / `flutter doctor -v`).
- Android: SDK 36, Java 17, Android Studio/emulador ou smartphone.
- iOS: **Mac com Xcode e CocoaPods**; para iPhone físico é preciso configurar a assinatura do app no Xcode.
- Web: navegador com suporte a notificações e **localhost ou HTTPS**; não use `file://`.
- Python 3 (`python3`) para configurar os projetos nativos criados pelo Flutter.

O pacote `flutter_local_notifications: 22.3.3` inclui suporte Web. `flutter_timezone` é chamado apenas em Android/iOS, pois a Web usa o fuso local do próprio browser para o Timer.

## Início rápido — Web para apresentação na sala

```bash
unzip notificacoes_locais_lddm_multiplataforma.zip
cd notificacoes_locais_lddm
bash prepare.sh
flutter run -d web-server --web-port 7357
```

Abra **http://localhost:7357** no Chrome ou Edge normal (não aba privada) do computador. Na primeira vez, clique em **Permitir avisos** e **Permitir** no popup do navegador. Depois clique em **Notificar agora** e, se o navegador e o sistema permitirem, o aviso aparecerá fora da tela do app e você ouvirá um pequeno apito do Web Audio.

**Importante:** para testar *o clique na notificação* use `flutter run -d web-server`, não `flutter run -d chrome`: segundo o README do plugin, o Chrome aberto pelo Flutter em modo de depuração usa uma janela especial que pode impedir que os cliques no aviso sejam entregues ao aplicativo.

Para iniciar a versão Web usando o Chrome diretamente, `flutter run -d chrome` também funciona para testar a **exibição**, mas use o comando acima para a navegação por toque.

**Windows (PowerShell):** descompacte o ZIP, abra a pasta no terminal do VS Code e execute:

```powershell
.\prepare.ps1
flutter run -d web-server --web-port 7357
```

Acesse `http://localhost:7357` no navegador. No Windows, o preparo gera Android + Web; para criar e executar o projeto iOS, use o `prepare.sh` em um Mac.

### Se o navegador não mostrar ou tocar notificações

1. Confirme que a URL é **localhost** ou **HTTPS**, não endereço HTTP remoto.
2. Clique no ícone de configurações/cadeado ao lado da URL, permita **Notificações** e recarregue a página se solicitado.
3. Permita sons do site, retire o computador de **Não Perturbe**, verifique o volume e mantenha a aba aberta. O apito só pode tocar após um clique humano no aplicativo.
4. Se persistir, em Chrome/Edge abra DevTools > Application > Service Workers e confira se há um worker registrado para a origem. Desative bloqueadores que impeçam notificações.
5. No Firefox/Safari pode haver diferenças. Use Chrome/Edge para a apresentação principal.

O **som da notificação do SO** depende do sistema/navegador; não existe código confiável que consiga sobrepor modo silencioso ou Não Perturbe. O **apito adicional Web** é gerado pelo JavaScript da página apenas enquanto ela estiver aberta e com áudio liberado.

## Android

```bash
bash prepare.sh
flutter devices
flutter run -d ID_DO_ANDROID
```

Na primeira execução, autorize notificações. No Android 12+/14+, a função de 1 minuto pode pedir acesso especial a **alarmes exatos**. Se negado, o código usa modo **inexato**, que pode atrasar. No Android 13+ a permissão `POST_NOTIFICATIONS` também é necessária. Para confirmar o som, retire o aparelho do silencioso/Não Perturbe, habilite o volume de notificações e confirme o som do canal **Alertas do workshop**. O projeto usa canal ID `alertas_workshop_v2` para evitar reaproveitar configurações antigas de um canal silencioso.

## iOS

Em um **Mac**, execute:

```bash
bash prepare.sh
flutter devices
flutter run -d ID_DO_IPHONE_OU_SIMULADOR
```

Em iPhone físico, abra `ios/Runner.xcworkspace` no Xcode e escolha um *Team* para assinar o aplicativo. Solicite permissão de **alertas, badges e som** no próprio app. Teste o som em iPhone físico e com o modo silencioso/Foco desativado. A execução de um app iOS não é possível no Windows ou Linux sem um ambiente Apple de build/assinatura.

## Primeiro preparo do projeto

O ZIP entrega todos os arquivos de **código, Web, manifesto, ícone, AppDelegate e automação**. As pastas `android/` e `ios/` são estruturas padrão **geradas de acordo com o Flutter instalado** por `flutter create` durante `bash prepare.sh` no macOS/Linux ou `prepare.ps1` no Windows, e recebem as alterações em `scripts/apply_native_overrides.py`. A operação é repetível; depois de executada, as pastas podem ser versionadas no repositório público.

Depois do primeiro preparo:

```bash
flutter analyze
flutter test
flutter run -d web-server --web-port 7357
```

Para publicar uma build Web compilada:

```bash
flutter build web --release
# Hospede a pasta build/web em um endereço HTTPS.
```

## Roteiro ao vivo para o Workshop (apresentar em 20–25 minutos)

1. **Conceito (3 min):** dispositivo/navegador versus push; explique por que não existe servidor no exemplo.
2. **Permissões e canais (4 min):** Android 13+, `requestPermissions` do iOS, permissões do site, canal Android com `importance: max` e som.
3. **Imediata (3 min):** clique **Permitir avisos** e depois **Notificar agora**. No PC, aparece um aviso do sistema com o apito da página.
4. **Agendada (4 min):** clique **Agendar para 1 minuto** e explique `zonedSchedule` no celular versus `Timer` no Web. Enquanto o tempo passa, mostre o código e a diferença de garantias.
5. **Payload (4 min):** clique **Toque abre a tela de detalhes** e clique no aviso; mostre a tela de detalhe. Na Web, use navegador normal + web-server.
6. **Recorrência + limitações (3 min):** mostre a recorrência, fuso horário, economia de bateria e comportamento da Web com a aba fechada.
7. **Perguntas/GitHub (2–4 min):** mostre a estrutura do repositório e aponte onde cada recurso é implementado.

## Onde está cada implementação

```text
notificacoes_locais_lddm/
├── lib/
│   ├── main.dart
│   ├── app.dart                            # navegação para /detalhe
│   ├── models/notification_payload.dart   # encode/decode JSON
│   ├── notifications/
│   │   ├── notification_service.dart       # lógica Android, iOS e Web
│   │   └── sound/
│   │       ├── web_chime_stub.dart         # stub em Android/iOS
│   │       └── web_chime_web.dart          # integração JS pelo Dart
│   └── screens/
│       ├── home_screen.dart                # testes e limitações por plataforma
│       └── detail_screen.dart
├── web/
│   ├── index.html                         # carrega o Flutter e o apito
│   ├── notification_chime.js              # Web Audio API
│   ├── manifest.json
│   ├── favicon.png
│   └── icons/
├── native_overrides/
│   ├── android/app/src/main/AndroidManifest.xml
│   ├── android/app/src/main/res/drawable/ic_stat_notification.png
│   └── ios/Runner/AppDelegate.swift
├── scripts/apply_native_overrides.py
├── test/
├── prepare.sh
├── prepare.ps1
└── pubspec.yaml
```

### Os métodos que podem ser perguntados em sala

| Método | Explicação |
|---|---|
| `initialize` | Inicializa plugin, callbacks de toque, fuso IANA mobile, canal Android e launch details. |
| `requestPermission` | Escolhe Web/Android/iOS; não pede permissão Web ao abrir a página. |
| `showNow` | Dispara notificação imediatamente no ambiente escolhido. |
| `scheduleInOneMinute` | Em Android/iOS usa `zonedSchedule`; na Web usa `Timer` e `show`. |
| `scheduleDailyAtEight` | Mobile usa `matchDateTimeComponents: time`; Web usa Timer rearmado após cada disparo. |
| `showDetailNotification` | Passa JSON com rota `/detalhe` para o clique da notificação. |
| `getNotificationAppLaunchDetails` | Captura uma notificação que abriu o app/site quando ele não estava em execução. |
| `prepareUserGesture` | Libera `AudioContext` do navegador, sujeito à política de autoplay. |
| `cancelPending` | Mobile cancela notificações nativas; Web cancela os Timers em memória. |

## Publicação no GitHub

Depois de `bash prepare.sh`, `flutter analyze`, `flutter test` e o teste manual no navegador e celular:

```bash
git init
git add .
git commit -m "feat: workshop notificacoes locais Android iOS Web"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

Substitua o URL e adicione o endereço real do repositório ao **slide final** antes de apresentar: o enunciado do professor o exige.

## Fontes técnicas para o relatório/oratória

- Plugin Flutter (versão utilizada): https://pub.dev/packages/flutter_local_notifications/versions/22.3.3
- Implementação Flutter Web: https://pub.dev/packages/flutter_local_notifications_web
- Limitações e permissões da Notifications API: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API/Using_the_Notifications_API
- Web Audio API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API

## Validação

Este pacote foi verificado quanto à organização dos arquivos, estrutura Web, sintaxe JavaScript, JSON, XML, automação Python e formato ZIP. **Não foi possível compilar Flutter neste ambiente** (SDK Flutter/Dart não disponíveis). A garantia de funcionamento depende da execução de `flutter analyze`, `flutter test` e testes reais em Android/iOS/Chrome conforme descrito acima. A implementação não contorna permissões nem silencia as limitações do navegador.
