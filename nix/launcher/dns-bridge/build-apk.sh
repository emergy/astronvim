#!/usr/bin/env bash
# Сборка без Gradle и сторонних библиотек. Нужны JDK 17 и Android SDK 35.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "$0")" && pwd)
: "${ANDROID_JAR:?Путь к android.jar API 35}"
: "${ANDROID_BUILD_TOOLS:?Каталог Android build-tools 35.0.0}"
: "${DNS_BRIDGE_KEYSTORE:?Путь к постоянному signing keystore вне Git}"
: "${DNS_BRIDGE_KEY_PASSWORD:?Пароль signing keystore}"
: "${DNS_BRIDGE_BUILD_DIR:?Каталог сборки вне исходников}"
mkdir -p "$DNS_BRIDGE_BUILD_DIR/classes" "$DNS_BRIDGE_BUILD_DIR/dex"
mapfile -t sources < <(find "$source_root/app/src" -name '*.java' -print | sort)
javac --release 8 -encoding UTF-8 -classpath "$ANDROID_JAR" -d "$DNS_BRIDGE_BUILD_DIR/classes" "${sources[@]}"
mapfile -t classes < <(find "$DNS_BRIDGE_BUILD_DIR/classes" -name '*.class' -print | sort)
"$ANDROID_BUILD_TOOLS/d8" --lib "$ANDROID_JAR" --min-api 23 --output "$DNS_BRIDGE_BUILD_DIR/dex" "${classes[@]}"
"$ANDROID_BUILD_TOOLS/aapt2" link --manifest "$source_root/app/AndroidManifest.xml" -I "$ANDROID_JAR" -o "$DNS_BRIDGE_BUILD_DIR/unsigned.apk"
jar uf "$DNS_BRIDGE_BUILD_DIR/unsigned.apk" -C "$DNS_BRIDGE_BUILD_DIR/dex" classes.dex
"$ANDROID_BUILD_TOOLS/zipalign" -f 4 "$DNS_BRIDGE_BUILD_DIR/unsigned.apk" "$DNS_BRIDGE_BUILD_DIR/aligned.apk"
"$ANDROID_BUILD_TOOLS/apksigner" sign --ks "$DNS_BRIDGE_KEYSTORE" --ks-key-alias android-dns-bridge \
  --ks-pass env:DNS_BRIDGE_KEY_PASSWORD --key-pass env:DNS_BRIDGE_KEY_PASSWORD \
  --out "$DNS_BRIDGE_BUILD_DIR/android-dns-bridge.apk" "$DNS_BRIDGE_BUILD_DIR/aligned.apk"
"$ANDROID_BUILD_TOOLS/apksigner" verify --verbose "$DNS_BRIDGE_BUILD_DIR/android-dns-bridge.apk"
