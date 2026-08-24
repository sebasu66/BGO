#!/usr/bin/env python3
"""Validate the generated BGO Web artifact before deploy or upload."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "build" / "web"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_file(relative: str) -> Path:
    path = WEB / relative
    if not path.is_file():
        fail(f"missing Web export file: {path.relative_to(ROOT)}")
    if path.stat().st_size == 0:
        fail(f"empty Web export file: {path.relative_to(ROOT)}")
    return path


def main() -> None:
    index = require_file("index.html")
    pack = require_file("index.pck")
    require_file("project-status/index.html")
    require_file("test-launcher/index.html")
    require_file("help/index.html")

    html = index.read_text(encoding="utf-8", errors="replace")
    for marker in ("__bgoFlightRecorder", "unhandledrejection", "error_generation"):
        if marker not in html:
            fail(f"index.html is missing required flight-recorder marker: {marker}")

    # Godot stores resource paths in the PCK directory. This catches the
    # regression where JSONH files were omitted from the Web package.
    if b"games/test001/game.jsonh" not in pack.read_bytes():
        fail("index.pck does not contain games/test001/game.jsonh")

    print("Web export validation OK")
    print(f"  html: {index.stat().st_size} bytes")
    print(f"  pack: {pack.stat().st_size} bytes")
    print("  flight recorder: present")
    print("  TEST001 JSONH: packed")
    print("  project-status: present")
    print("  test-launcher: present")
    print("  help manual: present")


if __name__ == "__main__":
    main()
