#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GODOT_BIN:-}" ]]; then
  exec "$GODOT_BIN" --path . "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path . "$@"
elif command -v godot4 >/dev/null 2>&1; then
  exec godot4 --path . "$@"
elif [[ -x /tmp/donut-godot/Godot_v4.5.2-stable_linux.x86_64 ]]; then
  exec /tmp/donut-godot/Godot_v4.5.2-stable_linux.x86_64 --path . "$@"
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
  exec flatpak run org.godotengine.Godot --path "$PWD" "$@"
else
  echo 'Install Godot 4.5.2 or set GODOT_BIN to the Godot executable.' >&2
  exit 1
fi
