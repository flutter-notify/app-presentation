# Preparo do projeto no Windows (PowerShell).
# Requisitos: Flutter no PATH e Python 3 instalado.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter nao encontrado no PATH. Execute flutter doctor -v.'
}

$gradleKtsExists = Test-Path -LiteralPath 'android/app/build.gradle.kts'
$gradleGroovyExists = Test-Path -LiteralPath 'android/app/build.gradle'
if (-not ($gradleKtsExists -or $gradleGroovyExists)) {
  Write-Host 'Gerando o projeto nativo Android e Web com Flutter...'
  flutter create --platforms=android,web --project-name notificacoes_locais_lddm --org br.edu.pucminas .
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar os arquivos Flutter.' }
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  python scripts/apply_native_overrides.py
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
  py -3 scripts/apply_native_overrides.py
} else {
  throw 'Python 3 nao encontrado. Instale Python 3 e execute novamente.'
}
if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar configuracoes Android/iOS.' }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar dependencias Flutter.' }

Write-Host ''
Write-Host 'Preparo concluido. Para rodar na Web:'
Write-Host 'flutter run -d web-server --web-port 7357'
Write-Host 'Para Android: flutter devices; flutter run -d ID_DO_ANDROID'
