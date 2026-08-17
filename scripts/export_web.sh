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

rm -rf build/web
mkdir -p build/web

"$GODOT" --headless --path . --import --quit
"$GODOT" --headless --path . --export-release Web build/web/index.html
node scripts/sync_project_status.mjs
python3 scripts/validate_web_export.py

echo "BGO Web export ready at build/web/index.html"
