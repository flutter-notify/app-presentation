#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'ERRO: Flutter não encontrado no PATH. Consulte o README.md.' >&2
  exit 1
fi

platforms='android,web'
if [[ "$(uname -s)" == 'Darwin' ]]; then
  platforms='android,ios,web'
fi

if [[ ! -f android/app/build.gradle.kts && ! -f android/app/build.gradle ]] || \
   [[ ! -f web/index.html ]] || \
   { [[ "$(uname -s)" == 'Darwin' ]] && [[ ! -f ios/Runner/AppDelegate.swift ]]; }; then
  echo "Gerando arquivos padronizados do Flutter: $platforms"
  flutter create --platforms="$platforms" --project-name notificacoes_locais_lddm --org br.edu.pucminas .
fi

python3 scripts/apply_native_overrides.py
flutter pub get

echo ''
echo 'Pronto! Web: flutter run -d web-server --web-port 7357'
echo 'Para Android/iOS, use: flutter devices && flutter run -d ID'
echo 'Valide: flutter analyze && flutter test'
