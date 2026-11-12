'use strict';
// Testa o sinal sonoro sem precisar de navegador/alto-falante reais:
// node scripts/test_web_chime.cjs
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
let opened = 0;
let closed = 0;
class AudioContextMock {
  constructor() {
    this.state = 'suspended';
    this.currentTime = 1;
    this.destination = {};
  }
  resume() {
    this.state = 'running';
    return Promise.resolve();
  }
  createOscillator() {
    return {
      frequency: { setValueAtTime() {} },
      connect() {},
      start() { opened++; },
      stop() { closed++; },
    };
  }
  createGain() {
    return {
      gain: {
        setValueAtTime() {},
        exponentialRampToValueAtTime() {},
      },
      connect() {},
    };
  }
}
const browser = { window: { AudioContext: AudioContextMock } };
const code = fs.readFileSync(path.join(__dirname, '..', 'web', 'notification_chime.js'), 'utf8');
vm.runInNewContext(code, browser);
if (!browser.window.workshopChime.unlock()) throw new Error('Não desbloqueou áudio.');
if (!browser.window.workshopChime.play()) throw new Error('Não iniciou apito.');
if (opened !== 2 || closed !== 2) throw new Error('Apito com número incorreto de tons.');
console.log('OK: Web Audio com dois tons e desbloqueio por gesto.');
