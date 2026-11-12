#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'ERRO: Flutter não encontrado no PATH. Consulte o README.md.' >&2
  exit 1
fi

if [[ ! -f android/app/build.gradle.kts && ! -f android/app/build.gradle ]] || [[ ! -f ios/Runner/AppDelegate.swift ]]; then
  echo 'Criando os projetos nativos Android e iOS com o Flutter instalado...'
  flutter create --platforms=android,ios --project-name notificacoes_locais_lddm --org br.edu.pucminas .
fi

python3 scripts/apply_native_overrides.py
flutter pub get

echo ''
echo 'Pronto. Execute: flutter run'
echo 'Confira também: flutter analyze && flutter test'
