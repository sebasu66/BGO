#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)


def spans(text: str) -> list[tuple[str, int, int]]:
    matches = list(FUNC_RE.finditer(text))
    return [
        (m.group(1), m.start(), matches[i + 1].start() if i + 1 < len(matches) else len(text))
        for i, m in enumerate(matches)
    ]


def main() -> None:
    child_path = Path("src/demo/main_3d.gd")
    base_path = Path("src/demo/main_3d_base.gd")
    child = child_path.read_text(encoding="utf-8")
    base = base_path.read_text(encoding="utf-8").rstrip() + "\n\n\n"
    move = {"_pointer_is_over_controls", "_orbit_camera"}
    selected: list[str] = []
    keep_parts: list[str] = []
    cursor = 0
    for name, start, end in spans(child):
        keep_parts.append(child[cursor:start])
        block = child[start:end]
        if name in move:
            selected.append(block.rstrip() + "\n\n\n")
        else:
            keep_parts.append(block)
        cursor = end
    keep_parts.append(child[cursor:])
    if len(selected) != len(move):
        raise RuntimeError(f"expected {len(move)} functions, moved {len(selected)}")
    child_path.write_text("".join(keep_parts), encoding="utf-8")
    base_path.write_text(base + "".join(selected).rstrip() + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
