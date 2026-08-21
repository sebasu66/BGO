#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []
warnings: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


def require(path: str) -> Path:
    target = ROOT / path
    if not target.exists():
        fail(f"Missing required path: {path}")
    return target


for required in (
    "project.godot",
    "export_presets.cfg",
    "scenes/main.tscn",
    "src/core/component_registry.gd",
    "src/core/game_definition_loader.gd",
    "games/test001/game.jsonh",
    "tests/test_runner.gd",
    "AGENTS.md",
    "docs/IMPLEMENTATION_ROADMAP.md",
    "docs/UI_PLUGIN_STACK.md",
):
    require(required)

ui_plugins = {
    "addons/spark/plugin.cfg": "1.0.2",
    "addons/reactive_ui/plugin.cfg": "0.12.1",
    "addons/reactive_ui_editor/plugin.cfg": "0.10.1",
    "addons/gdss/plugin.cfg": "0.7.0",
    "addons/godotx_toast/plugin.cfg": "2.0.0",
}
project_config = (ROOT / "project.godot").read_text(encoding="utf-8")
for plugin_path, expected_version in ui_plugins.items():
    descriptor = require(plugin_path)
    if descriptor.exists():
        descriptor_text = descriptor.read_text(encoding="utf-8")
        if f'version="{expected_version}"' not in descriptor_text:
            fail(f"{plugin_path}: expected version {expected_version}")
    if f'res://{plugin_path}' not in project_config:
        fail(f"{plugin_path}: plugin is not enabled in project.godot")

require("addons/reactive_ui_analyzer/gdscript_analyzer.gdextension")
export_config = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
for excluded_path in ("addons/reactive_ui_editor/*", "addons/reactive_ui_analyzer/*"):
    if excluded_path not in export_config:
        fail(f"Web export must exclude {excluded_path}")

component_manifests = sorted((ROOT / "src/components").rglob("component.jsonh"))
if not component_manifests:
    fail("No component manifests found under src/components.")

seen_ids: dict[str, Path] = {}
capability_catalog_path = require("src/capabilities/capabilities.jsonh")
try:
    capability_catalog = json.loads(capability_catalog_path.read_text(encoding="utf-8"))
except Exception as exc:
    fail(f"src/capabilities/capabilities.jsonh must be strict JSON-compatible JSONH: {exc}")
    capability_catalog = {}

if capability_catalog.get("schema") != "bgo.capability_catalog":
    fail("Capability catalog must declare schema 'bgo.capability_catalog'")
capability_contracts = capability_catalog.get("capabilities", {})
if not isinstance(capability_contracts, dict) or not capability_contracts:
    fail("Capability catalog must contain a non-empty capabilities object")
    capability_contracts = {}

registered_verbs: set[str] = set()
core_state_fields = {
    "object_id", "component_id", "owner_id", "holder_id", "location_type",
    "location_id", "visibility", "quantity", "state_id", "properties",
}
for gd_path in sorted((ROOT / "src").rglob("*.gd")):
    source = gd_path.read_text(encoding="utf-8")
    registered_verbs.update(re.findall(r'register_verb\(\s*"([a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+)"', source))

for manifest_path in component_manifests:
    rel = manifest_path.relative_to(ROOT)
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{rel}: component manifest must currently be strict JSON-compatible JSONH: {exc}")
        continue

    component_id = str(data.get("id", "")).strip()
    kind = str(data.get("kind", "")).strip()
    scene = str(data.get("scene", "")).strip()
    description = str(data.get("description", "")).strip()
    capabilities = data.get("capabilities")
    verbs = data.get("verbs")
    state = data.get("state")
    if data.get("schema") != "bgo.component":
        fail(f"{rel}: schema must be 'bgo.component'")
    if not component_id:
        fail(f"{rel}: missing component id")
    elif component_id in seen_ids:
        fail(f"Duplicate component id {component_id}: {seen_ids[component_id].relative_to(ROOT)} and {rel}")
    else:
        seen_ids[component_id] = manifest_path

    if not re.fullmatch(r"bgo\.[a-z0-9_]+(?:\.[a-z0-9_]+)+", component_id):
        fail(f"{rel}: invalid stable component id '{component_id}'")
    if not kind:
        fail(f"{rel}: missing component kind")
    if not description:
        fail(f"{rel}: missing component description")
    if not isinstance(data.get("config"), dict):
        fail(f"{rel}: config must be an object")
    if not isinstance(state, dict):
        fail(f"{rel}: state must be an object")
        state = {}
    if not isinstance(capabilities, list):
        fail(f"{rel}: capabilities must be an array")
        capabilities = []
    if len(capabilities) != len(set(capabilities)):
        fail(f"{rel}: capabilities must not contain duplicates")
    if not isinstance(verbs, dict):
        fail(f"{rel}: verbs must be an object")
        verbs = {}
    for verb in verbs:
        if not re.fullmatch(r"[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+", verb):
            fail(f"{rel}: invalid canonical verb '{verb}'")
        elif verb not in registered_verbs:
            fail(f"{rel}: declared verb '{verb}' has no registered runtime handler")
    component_sources = "\n".join(
        path.read_text(encoding="utf-8") for path in manifest_path.parent.glob("*.gd")
    )
    for capability_id in capabilities:
        if capability_id not in capability_contracts:
            fail(f"{rel}: unknown capability '{capability_id}'")
            continue
        capability = capability_contracts[capability_id]
        for required_state in capability.get("required_state", []):
            if required_state not in core_state_fields and required_state not in state:
                fail(
                    f"{rel}: capability '{capability_id}' requires state field "
                    f"'{required_state}'"
                )
        for required_verb in capability.get("required_verbs", []):
            if required_verb not in verbs:
                fail(f"{rel}: capability '{capability_id}' requires verb '{required_verb}'")
        for required_method in capability.get("required_view_methods", []):
            if not re.search(rf"func\s+{re.escape(required_method)}\s*\(", component_sources):
                fail(
                    f"{rel}: capability '{capability_id}' requires view method "
                    f"'{required_method}' in its component folder"
                )
    if not scene.startswith("res://src/components/") or not scene.endswith(".tscn"):
        fail(f"{rel}: component scene must be an internal component .tscn path, got '{scene}'")
    elif not (ROOT / scene.removeprefix("res://")).exists():
        fail(f"{rel}: referenced scene does not exist: {scene}")

for game_path in sorted((ROOT / "games").rglob("*.jsonh")):
    text = game_path.read_text(encoding="utf-8")
    if "res://" in text or ".tscn" in text or ".gd\"" in text:
        fail(f"{game_path.relative_to(ROOT)}: game definition references an internal Godot implementation path")

# New core-domain code must not reach directly into Firebase/network adapters.
# bgo_logger.gd is a known PoC exception and remains visible as technical debt until
# its transport sink is injected/moved out of core.
for core_path in sorted((ROOT / "src/core").rglob("*.gd")):
    text = core_path.read_text(encoding="utf-8")
    if "firebase" in text.lower() or "src/network/" in text:
        rel = core_path.relative_to(ROOT)
        if rel.as_posix() == "src/core/bgo_logger.gd":
            warn("src/core/bgo_logger.gd still owns a Firebase sink; tracked PoC architecture debt")
        else:
            fail(f"{rel}: core domain must not depend directly on Firebase/network adapters")

if (ROOT / "build/web/index.html").exists():
    warn("build/web exists in the checkout. Treat it as generated output; source changes belong outside build/.")

main_scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
if "res://addons/" in main_scene:
    fail("scenes/main.tscn hard-references an optional addon; a clean CI checkout would not be portable")

print(f"BGO structure check: {len(component_manifests)} component manifests, {len(seen_ids)} unique component IDs")
for message in warnings:
    print(f"WARNING: {message}")
for message in errors:
    print(f"ERROR: {message}", file=sys.stderr)

if errors:
    print(f"STRUCTURE CHECK FAILED: {len(errors)} error(s), {len(warnings)} warning(s)", file=sys.stderr)
    raise SystemExit(1)

print(f"STRUCTURE CHECK PASSED: {len(warnings)} warning(s)")
