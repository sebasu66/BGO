#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-godot}"

printf '\n== BGO structure ==\n'
python3 scripts/check_structure.py

if command -v gdformat >/dev/null 2>&1; then
  printf '\n== GDScript format (advisory during baseline) ==\n'
  gdformat --check src tests || echo 'WARNING: gdformat reported existing formatting debt.'
else
  echo 'WARNING: gdformat not installed. Install with: pip install "gdtoolkit==4.*"'
fi

if command -v gdlint >/dev/null 2>&1; then
  printf '\n== GDScript lint (advisory during baseline) ==\n'
  gdlint src tests || echo 'WARNING: gdlint reported existing lint debt.'
else
  echo 'WARNING: gdlint not installed. Install with: pip install "gdtoolkit==4.*"'
fi

printf '\n== Godot import / parse ==\n'
"$GODOT_BIN" --headless --path "$ROOT" --import --quit

printf '\n== Headless domain tests ==\n'
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_runner.gd

printf '\n== Web export smoke test ==\n'
mkdir -p build/web
"$GODOT_BIN" --headless --path "$ROOT" --export-release Web "$ROOT/build/web/index.html"
node scripts/sync_project_status.mjs

test -f build/web/index.html
test -f build/web/project-status/index.html

echo '\nBGO QUALITY GATE PASSED'
