/* Sinal sonoro da DEMONSTRAÇÃO Web (não altera som do sistema operacional).
 * Deve ser desbloqueado por clique do usuário antes de ser usado por Timer.
 * Não cria notificações falsas: a notificação real vem do plugin via SW. */
(function () {
  'use strict';

  let audioContext = null;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;

  function unlock() {
    if (!AudioContextClass) return false;
    try {
      if (!audioContext) audioContext = new AudioContextClass();
      if (audioContext.state === 'suspended') {
        audioContext.resume().catch(function () { /* permitido sem som */ });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  function beep(startAt, frequency, duration) {
    const osc = audioContext.createOscillator();
    const gain = audioContext.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(frequency, startAt);
    gain.gain.setValueAtTime(0.0001, startAt);
    gain.gain.exponentialRampToValueAtTime(0.22, startAt + 0.018);
    gain.gain.exponentialRampToValueAtTime(0.0001, startAt + duration);
    osc.connect(gain);
    gain.connect(audioContext.destination);
    osc.start(startAt);
    osc.stop(startAt + duration + 0.01);
  }

  function play() {
    if (!unlock() || !audioContext || audioContext.state !== 'running') {
      return false;
    }
    try {
      const t = audioContext.currentTime + 0.02;
      beep(t, 784, 0.18);
      beep(t + 0.23, 1047, 0.24);
      return true;
    } catch (e) {
      return false;
    }
  }

  window.workshopChime = Object.freeze({ unlock: unlock, play: play });
})();
