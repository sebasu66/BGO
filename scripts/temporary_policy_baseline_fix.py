#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

VAR_RE = re.compile(r"^(\s*(?:@\w+(?:\([^)]*\))?\s+)*)var\s+([A-Za-z_][A-Za-z0-9_]*)")
CONST_RE = re.compile(r"^(\s*)const\s+([A-Za-z_][A-Za-z0-9_]*)")
FUNC_RE = re.compile(r"^(\s*)func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
SNAKE_RE = re.compile(r"^[a-z][a-z0-9_]*$")
UPPER_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")

DOCS = {
    "configure": "Configures this object from the supplied project data.",
    "rebuild": "Rebuilds the runtime representation from the current configuration.",
    "slot_id": "Returns the stable slot identifier for the requested board cell.",
    "parse_slot_id": "Parses a stable slot identifier back into board coordinates.",
    "is_valid_cell": "Returns whether the supplied board coordinates identify a valid cell.",
    "is_valid_slot": "Returns whether the supplied slot identifier belongs to this board.",
    "slot_world": "Returns the world-space position represented by a logical slot identifier.",
    "cell_world": "Returns the world-space position represented by board coordinates.",
    "request_move": "Requests a logical move and returns the resulting operation state.",
    "apply_move": "Applies an already-authorized logical move to this component.",
    "area_slot_world": "Returns the world-space position of a player-area slot.",
    "hand_slot_world": "Returns the world-space position of a private-hand slot.",
    "set_pose": "Updates the published player-presence pose.",
    "accepts": "Returns whether this slot accepts the supplied logical object.",
    "set_property_value": "Sets a named logical property on the game object.",
    "get_property_value": "Returns a named logical property from the game object.",
    "add_component": "Attaches a component to the logical game object.",
    "get_component": "Returns the component registered under the supplied identifier.",
    "has_component": "Returns whether the object owns the supplied component identifier.",
    "serialize_state": "Serializes the object's logical state for persistence or transport.",
    "log_event": "Records a structured BGO event using the configured logging sinks.",
    "debug": "Records a debug-level BGO log entry.",
    "info": "Records an informational BGO log entry.",
    "warning": "Records a warning-level BGO log entry.",
    "error": "Records an error-level BGO log entry.",
    "reset_player_camera": "Resets the player camera to the configured default view.",
    "set_selected": "Updates the token's selected visual state.",
    "contains_global_point": "Returns whether the supplied global point intersects this token.",
    "read": "Reads a value from the configured Firebase Realtime Database path.",
    "write": "Writes a complete value to the configured Firebase Realtime Database path.",
    "patch": "Applies a partial update to the configured Firebase Realtime Database path.",
    "push": "Pushes a new child value to the configured Firebase Realtime Database path.",
    "remove": "Removes the value at the configured Firebase Realtime Database path.",
    "set_logger": "Sets the logger used by the session repository.",
    "set_game_definition": "Sets the declarative game definition used by the session repository.",
    "start": "Starts repository synchronization for the current session context.",
    "refresh": "Refreshes repository state from the remote source.",
    "ensure_demo_session": "Ensures the development demo session exists with valid initial state.",
    "pickup_piece": "Moves a logical piece into the requesting player's held state.",
    "move_to_player_area": "Moves a logical piece into a player's public area.",
    "move_to_hand": "Moves a logical piece into a player's private hand.",
    "place_piece": "Places a logical piece into an authorized destination slot.",
    "move_piece": "Moves a logical piece between authorized logical locations.",
    "publish_player": "Publishes the current player's presence metadata.",
    "publish_pose": "Publishes the current player's latest presence pose.",
    "add_cleanup": "Registers a temporary test resource for cleanup after the test.",
    "after_each": "Cleans up temporary test resources after each test case.",
    "test__default_shape": "Verifies the default dice definition shape.",
    "test__shape_migration": "Verifies migration of legacy dice shape data.",
    "legacy_scene_content": "Builds legacy scene text used by the migration fixture.",
    "write_file": "Writes fixture content to a temporary test file.",
    "test__scene_loading_shape_migration": "Verifies legacy dice shape migration while loading a scene.",
}


def to_snake(name: str) -> str:
    stripped = name.lstrip("_")
    prefix = name[: len(name) - len(stripped)]
    s1 = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", stripped)
    s2 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1)
    return prefix + s2.replace("__", "_").lower()


def to_upper_snake(name: str) -> str:
    return to_snake(name).upper()


def rename_identifiers(text: str) -> str:
    replacements: dict[str, str] = {}
    for line in text.splitlines():
        vm = VAR_RE.match(line)
        if vm:
            name = vm.group(2)
            candidate = name.lstrip("_")
            if candidate and not SNAKE_RE.fullmatch(candidate):
                replacements[name] = to_snake(name)
        cm = CONST_RE.match(line)
        if cm:
            name = cm.group(2)
            if not UPPER_RE.fullmatch(name):
                replacements[name] = to_upper_snake(name)
    for old, new in sorted(replacements.items(), key=lambda item: -len(item[0])):
        text = re.sub(rf"(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])", new, text)
    return text


def add_public_docs(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    for line in lines:
        match = FUNC_RE.match(line)
        if match and not match.group(2).startswith("_"):
            index = len(out) - 1
            while index >= 0 and not out[index].strip():
                index -= 1
            has_doc = index >= 0 and out[index].lstrip().startswith("##")
            if not has_doc:
                indent = match.group(1)
                name = match.group(2)
                doc = DOCS.get(name, f"Exposes the `{name}` operation as part of the project's public GDScript contract.")
                out.append(f"{indent}## {doc}")
        out.append(line)
    suffix = "\n" if text.endswith("\n") else ""
    return "\n".join(out) + suffix


def process(path: Path) -> None:
    original = path.read_text(encoding="utf-8")
    updated = add_public_docs(rename_identifiers(original))
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        print(f"updated {path}")


def main() -> None:
    for folder in (Path("src"), Path("tests")):
        for path in sorted(folder.rglob("*.gd")):
            process(path)


if __name__ == "__main__":
    main()
