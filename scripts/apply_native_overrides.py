#!/usr/bin/env python3
"""Aplica configuração de notificações ao scaffold nativo criado por Flutter.

Compatível com Android build.gradle.kts (padrão) e build.gradle (legado).
Reexecutável: edições idempotentes.
"""
from __future__ import annotations

import plistlib
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_or_fail(pattern: str, replacement: str, content: str, desc: str) -> str:
    result, n = re.subn(pattern, replacement, content, count=1)
    if n != 1:
        raise RuntimeError(f"Não foi possível encontrar {desc} para atualizar. Confira o template Flutter.")
    return result


def add_to_named_block(text: str, block_name: str, insertion: str) -> str:
    # Localiza fechamento do bloco { ... }, inclusive com chaves aninhadas.
    pattern = rf'\b{re.escape(block_name)}\s*\{{'
    match = re.search(pattern, text)
    if match is None:
        raise RuntimeError(f"Bloco {block_name} não encontrado no Gradle.")
    start = match.end()
    depth = 1
    for index in range(start, len(text)):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
            if depth == 0:
                return text[:index] + insertion + text[index:]
    raise RuntimeError(f"Chaves desbalanceadas no bloco {block_name}.")


def edit_android_app_gradle(path: Path):
    text = path.read_text()
    kotlin = path.suffix == '.kts'
    if kotlin:
        text = replace_or_fail(
            r'\bcompileSdk\s*=\s*(?:flutter\.compileSdkVersion|\d+)',
            'compileSdk = 36', text, 'compileSdk no arquivo Kotlin')
        if 'isCoreLibraryDesugaringEnabled' not in text:
            text = add_to_named_block(text, 'compileOptions',
                '\n        isCoreLibraryDesugaringEnabled = true\n    ')
        text = re.sub(
            r'(sourceCompatibility|targetCompatibility)\s*=\s*JavaVersion\.[A-Z0-9_]+',
            r'\1 = JavaVersion.VERSION_17', text)
        if 'kotlinOptions' in text:
            text = replace_or_fail(
                r'jvmTarget\s*=\s*[^\n]+',
                'jvmTarget = JavaVersion.VERSION_17.toString()', text,
                'Kotlin jvmTarget')
        if 'multiDexEnabled' not in text:
            text = add_to_named_block(text, 'defaultConfig',
                '\n        multiDexEnabled = true\n    ')
        if 'coreLibraryDesugaring(' not in text:
            text += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        text = replace_or_fail(
            r'\bcompileSdk(?:Version)?\s*(?:=\s*)?(?:flutter\.compileSdkVersion|\d+)',
            'compileSdk 36', text, 'compileSdk no arquivo Groovy')
        if 'coreLibraryDesugaringEnabled' not in text:
            text = add_to_named_block(text, 'compileOptions',
                '\n        coreLibraryDesugaringEnabled true\n    ')
        text = re.sub(
            r'(sourceCompatibility|targetCompatibility)\s*(?:=\s*)?JavaVersion\.[A-Z0-9_]+',
            r'\1 JavaVersion.VERSION_17', text)
        if 'kotlinOptions' in text:
            text = replace_or_fail(r'jvmTarget\s*=\s*[^\n]+',
                'jvmTarget = JavaVersion.VERSION_17.toString()', text, 'Kotlin jvmTarget')
        if 'multiDexEnabled' not in text:
            text = add_to_named_block(text, 'defaultConfig',
                '\n        multiDexEnabled true\n    ')
        if 'coreLibraryDesugaring ' not in text:
            text += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    path.write_text(text)


def edit_settings_gradle(path: Path):
    text = path.read_text()
    pattern = r'(?P<prefix>id\(["\']com\.android\.application["\']\)\s+version\s+["\'])(?P<version>[0-9.]+)(?P<suffix>["\'])' if path.suffix == '.kts' else r'(?P<prefix>id\s+["\']com\.android\.application["\']\s+version\s+["\'])(?P<version>[0-9.]+)(?P<suffix>["\'])'
    match = re.search(pattern, text)
    if not match:
        raise RuntimeError('Android Gradle Plugin não encontrado no settings.gradle(.kts).')
    version = tuple(int(v) for v in match['version'].split('.'))
    if version < (8, 11, 1):
        text = text[:match.start('version')] + '8.11.1' + text[match.end('version'):]
    path.write_text(text)


def edit_wrapper():
    prop = ROOT / 'android/gradle/wrapper/gradle-wrapper.properties'
    text = prop.read_text()
    match = re.search(r'gradle-(\d+)\.(\d+)(?:\.(\d+))?-(?:all|bin)\.zip', text)
    if not match:
        raise RuntimeError('Não foi possível identificar a versão do Gradle wrapper.')
    current = (int(match[1]), int(match[2]), int(match[3] or 0))
    if current < (8, 14, 0):
        text = text[:match.start()] + 'gradle-8.14-all.zip' + text[match.end():]
    prop.write_text(text)


def main():
    android_app = ROOT / 'android/app'
    ios_runner = ROOT / 'ios/Runner'
    overrides = ROOT / 'native_overrides'
    configured = []

    if android_app.is_dir():
        gradle = android_app / 'build.gradle.kts'
        if not gradle.exists():
            gradle = android_app / 'build.gradle'
        if not gradle.exists():
            raise RuntimeError('Não foi encontrado build.gradle(.kts) do Android.')
        settings = ROOT / 'android/settings.gradle.kts'
        if not settings.exists():
            settings = ROOT / 'android/settings.gradle'
        edit_android_app_gradle(gradle)
        edit_settings_gradle(settings)
        edit_wrapper()
        shutil.copy2(overrides / 'android/app/src/main/AndroidManifest.xml',
                     android_app / 'src/main/AndroidManifest.xml')
        drawable = android_app / 'src/main/res/drawable'
        drawable.mkdir(parents=True, exist_ok=True)
        shutil.copy2(
            overrides / 'android/app/src/main/res/drawable/ic_stat_notification.png',
            drawable / 'ic_stat_notification.png')
        configured.append('Android')

    if ios_runner.is_dir():
        shutil.copy2(overrides / 'ios/Runner/AppDelegate.swift',
                     ios_runner / 'AppDelegate.swift')
        plist_path = ios_runner / 'Info.plist'
        with plist_path.open('rb') as f:
            plist = plistlib.load(f)
        plist['CFBundleDisplayName'] = 'Workshop Notificações'
        plist['CFBundleName'] = 'NotificacoesLDDM'
        with plist_path.open('wb') as f:
            plistlib.dump(plist, f, sort_keys=False)
        pbxproj = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
        pbx_text = pbxproj.read_text()
        pbx_text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;',
                          'IPHONEOS_DEPLOYMENT_TARGET = 13.0;', pbx_text)
        pbxproj.write_text(pbx_text)
        podfile = ROOT / 'ios/Podfile'
        if podfile.exists():
            pod_text = podfile.read_text()
            if re.search(r'^\s*#?\s*platform :ios,', pod_text, re.MULTILINE):
                pod_text = re.sub(r'^\s*#?\s*platform :ios, [^\n]+',
                                  "platform :ios, '13.0'", pod_text,
                                  count=1, flags=re.MULTILINE)
            else:
                pod_text = "platform :ios, '13.0'\n" + pod_text
            podfile.write_text(pod_text)
        configured.append('iOS')

    print('Configurações aplicadas: ' +
          (', '.join(configured) if configured else 'somente Web (sem ajustes nativos)'))
    print('Próximo passo: flutter pub get && flutter analyze && flutter test.')


if __name__ == '__main__':
    main()
