#!/usr/bin/env bash
# Builds otis-alerts.apk with the plain Android SDK tools (aapt2, javac, d8, zipalign, apksigner), no Gradle.
# Needs ANDROID_HOME and a JDK. On GitHub Actions both are already installed.
#
# The signing key is made fresh for every build and thrown away, so nobody (not even you) can sign
# an "update" that Android would install over this app. Updating = uninstall, install, set up again.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${ANDROID_HOME:?set ANDROID_HOME to the Android SDK}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
JAR="$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar"
VERSION="${GITHUB_RUN_NUMBER:-1}"
OUT=build
echo "build-tools: $BT"
echo "platform:    $JAR"

rm -rf "$OUT" otis-alerts.apk
mkdir -p "$OUT/assets" "$OUT/gen" "$OUT/classes" "$OUT/dex"
cp index.html manifest.webmanifest icon-192.png icon-512.png "$OUT/assets/"

"$BT/aapt2" compile --dir android/res -o "$OUT/res.zip"
"$BT/aapt2" link -o "$OUT/unsigned.apk" -I "$JAR" --manifest android/AndroidManifest.xml -A "$OUT/assets" \
    --java "$OUT/gen" --min-sdk-version 26 --target-sdk-version 34 \
    --version-code "$VERSION" --version-name "1.$VERSION" "$OUT/res.zip"
javac -source 8 -target 8 -Xlint:-options -bootclasspath "$JAR" -d "$OUT/classes" \
    $(find android/src "$OUT/gen" -name '*.java')
"$BT/d8" --release --min-api 26 --lib "$JAR" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
(cd "$OUT/dex" && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

PASS="$(openssl rand -hex 24)"
keytool -genkeypair -noprompt -keystore "$OUT/key.p12" -storetype PKCS12 -storepass "$PASS" -keypass "$PASS" \
    -alias otis -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Otis alerts" >/dev/null
"$BT/apksigner" sign --ks "$OUT/key.p12" --ks-pass "pass:$PASS" --out otis-alerts.apk "$OUT/aligned.apk"
rm -f "$OUT/key.p12"

"$BT/apksigner" verify --verbose otis-alerts.apk
"$BT/aapt2" dump badging otis-alerts.apk | grep -E "^(package|application-label|application-icon-|sdkVersion|targetSdkVersion|uses-permission)"
ls -l otis-alerts.apk
