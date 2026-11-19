#!/usr/bin/env bash
# Build Wasira and run it on the physical phone over adb. Never an emulator.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/phone.sh [--release | --help]

  (default)   ./gradlew installDebug, then launch uz.wasira.debug ("Wasira Dev").
              Installs beside the release; it never replaces it.
  --release   Build the signed release and adb install -r it over uz.wasira.
              Needs the keystore (WASIRA_KEYSTORE, default
              ~/.android/wasira-release.jks) and its Keychain password.
  --help      Show this.

Exactly one device must be connected. With several, set ANDROID_SERIAL.
EOF
}

mode=debug
case "${1:-}" in
  "") ;;
  --release) mode=release ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

find_adb() {
  if command -v adb >/dev/null 2>&1; then command -v adb; return; fi
  local dir
  for dir in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    if [[ -n "$dir" && -x "$dir/platform-tools/adb" ]]; then
      echo "$dir/platform-tools/adb"; return
    fi
  done
  return 1
}

adb=$(find_adb) || {
  echo "adb not found. Install Android SDK platform-tools or set ANDROID_HOME." >&2
  exit 1
}

no_device_help() {
  cat >&2 <<'EOF'
No phone connected.
  USB:      Settings > About phone > tap Build number 7 times, then
            Developer options > USB debugging on, and plug the phone in.
  Wireless: Developer options > Wireless debugging (Android 11+) >
            Pair device with pairing code, then on the laptop:
              adb pair <ip:port>      # the pairing port and code
              adb connect <ip:port>   # the port shown on the Wireless debugging screen
EOF
}

# Pick the one target device, honouring ANDROID_SERIAL.
devices=$("$adb" devices | tail -n +2 | awk 'NF >= 2 { print $1 "\t" $2 }')
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  state=$(awk -F'\t' -v s="$ANDROID_SERIAL" '$1 == s { print $2 }' <<<"$devices")
  case "$state" in
    device) ;;
    unauthorized)
      echo "$ANDROID_SERIAL is unauthorized: unlock the phone and accept the USB debugging prompt." >&2
      exit 1 ;;
    "")
      echo "ANDROID_SERIAL=$ANDROID_SERIAL is not connected." >&2
      if [[ -n "$devices" ]]; then echo "Connected:" >&2; echo "$devices" >&2; else no_device_help; fi
      exit 1 ;;
    *)
      echo "$ANDROID_SERIAL is $state, not ready. Reconnect it and retry." >&2
      exit 1 ;;
  esac
else
  ready=$(awk -F'\t' '$2 == "device"' <<<"$devices" | grep -c . || true)
  if [[ "$ready" -eq 0 ]]; then
    if grep -q $'\tunauthorized' <<<"$devices"; then
      echo "Phone is unauthorized: unlock it and accept the USB debugging prompt, then retry." >&2
    else
      no_device_help
    fi
    exit 1
  fi
  if [[ "$ready" -gt 1 ]]; then
    echo "More than one device. Pick one with ANDROID_SERIAL=<serial> scripts/phone.sh" >&2
    awk -F'\t' '$2 == "device"' <<<"$devices" >&2
    exit 1
  fi
  ANDROID_SERIAL=$(awk -F'\t' '$2 == "device" { print $1 }' <<<"$devices")
  export ANDROID_SERIAL
fi
echo "Device: $ANDROID_SERIAL"

if [[ "$mode" == debug ]]; then
  ./gradlew installDebug
  "$adb" shell am start -n uz.wasira.debug/uz.wasira.MainActivity
  exit 0
fi

# Release: same signing procedure as CLAUDE.md "Releases".
export WASIRA_KEYSTORE="${WASIRA_KEYSTORE:-$HOME/.android/wasira-release.jks}"
if [[ ! -f "$WASIRA_KEYSTORE" ]]; then
  echo "Keystore not found at $WASIRA_KEYSTORE. Set WASIRA_KEYSTORE." >&2
  exit 1
fi
if [[ -z "${WASIRA_KEYSTORE_PASSWORD:-}" ]]; then
  WASIRA_KEYSTORE_PASSWORD=$(security find-generic-password -a wasira -s wasira-release-keystore -w) || {
    echo "Keystore password not in the Keychain (account wasira, service wasira-release-keystore)." >&2
    exit 1
  }
fi
export WASIRA_KEYSTORE_PASSWORD

apk=app/build/outputs/apk/release/app-release.apk
rm -f "$apk"  # a stale signed APK must not stand in for this build
./gradlew assembleRelease

if [[ ! -f "$apk" ]]; then
  echo "No signed APK at $apk (only an unsigned one was built). Refusing to install." >&2
  exit 1
fi
sdk=$(dirname "$(dirname "$adb")")
apksigner=$(find "$sdk/build-tools" -maxdepth 2 -name apksigner 2>/dev/null | sort -V | tail -n 1)
if [[ -n "$apksigner" ]] && ! "$apksigner" verify "$apk" >/dev/null 2>&1; then
  echo "$apk does not verify as signed. Refusing to install." >&2
  exit 1
fi

"$adb" install -r "$apk"
"$adb" shell am start -n uz.wasira/uz.wasira.MainActivity
