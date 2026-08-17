#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-godot}"

rm -rf build/web
mkdir -p build/web

"$GODOT_BIN" --headless --path . --import --quit
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html
node scripts/sync_project_status.mjs
python3 scripts/validate_web_export.py

echo "BGO Web export ready at build/web/index.html"
