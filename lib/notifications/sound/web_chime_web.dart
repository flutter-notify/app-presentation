import 'dart:js_interop';

/// Funções JS fornecidas por web/notification_chime.js.
/// Mantém APIs Web fora do código compilado para Android/iOS.
@JS('workshopChime.unlock')
external bool _unlock();

@JS('workshopChime.play')
external bool _play();

void unlock() {
  try {
    _unlock();
  } catch (_) {
    // Aviso visual continua disponível mesmo sem Web Audio.
  }
}

void play() {
  try {
    _play();
  } catch (_) {
    // A permissão de áudio é uma decisão do browser/usuário.
  }
}
