#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif [[ -x "./godot" ]]; then
  GODOT="./godot"
else
  GODOT="godot"
fi

echo "Using Godot CLI: $GODOT"

check_godot_log() {
  local log_file="$1"
  local label="$2"
  if grep -E 'SCRIPT ERROR: Parse Error:|Failed to load script' "$log_file" >/dev/null; then
    echo "$label reported GDScript parse/load errors:" >&2
    grep -E 'SCRIPT ERROR: Parse Error:|Failed to load script' "$log_file" >&2 || true
    return 1
  fi
}

rm -rf build/web
mkdir -p build/web build/logs

IMPORT_LOG="build/logs/godot-import.log"
EXPORT_LOG="build/logs/godot-web-export.log"

"$GODOT" --headless --path . --import --quit 2>&1 | tee "$IMPORT_LOG"
check_godot_log "$IMPORT_LOG" "Godot import"

"$GODOT" --headless --path . --export-release Web build/web/index.html 2>&1 | tee "$EXPORT_LOG"
check_godot_log "$EXPORT_LOG" "Godot Web export"

node scripts/sync_project_status.mjs
python3 scripts/validate_web_export.py

echo "BGO Web export ready at build/web/index.html"
