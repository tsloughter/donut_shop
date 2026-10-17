#!/usr/bin/env bash
# Uses your configured Godot Android SDK/JDK/export templates.
# The APK is a debug-signed, sideloadable development build.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p builds
tools/run.sh --headless --export-debug Android builds/little-donut-android.apk 2>&1 | tee builds/android-export.log
test -s builds/little-donut-android.apk
if grep -q 'Project export.*failed' builds/android-export.log; then exit 1; fi
printf '\nAndroid APK: %s/builds/little-donut-android.apk\n' "$PWD"
