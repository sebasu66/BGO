# Engine extraction map (draft v0.1)

Purpose: show what in BGO is kernel, what is module, and what is adapter, so the
modular engine can be extracted from BGO instead of rebuilt. "Observed" items come
from reading the code on 2026-10-04. "Proposed" items are decisions still to confirm.

## 1. Layers

| Layer | Meaning | Rule |
|---|---|---|
| Kernel | Domain-neutral: command -> event protocol, registries, session lifecycle, serialization, event routing, logging port | Knows nothing about tabletops, Godot nodes, Firebase or MCP |
| Module | One feature solved once: contract + data + logic + config + view split | Declares provides/requires/emits/consumes in a manifest |
| Adapter | Connects a port to the outside: Godot view, Firebase/GitHub transport, MCP | Replaceable without touching kernel or modules |

## 2. Where each `src/core` file belongs (observed + proposed)

| File | Proposed layer | Note |
|---|---|---|
| `gameplay_state.gd` (835 lines) | Kernel, but mixed | Holds the command protocol, permissions and turn checks AND tabletop verbs (hand, move, collections). Needs a split analysis before extraction |
| `session_state.gd`, `flow_state.gd` | Kernel | Session lifecycle and turn/phase flow |
| `logical_object_state.gd`, `bgo_game_object.gd` | Kernel | Stable object identity |
| `capability_registry.gd`, `component_registry.gd` | Kernel | `component_registry` hardcodes `res://src/components`; the kernel should receive module roots instead |
| `game_event_router.gd` | Kernel | Event contracts |
| `game_definition_loader.gd` | Kernel | Validates definitions, including `runtime.mode` |
| `bgo_logger.gd`, `bgo_activity_log.gd` | Kernel port + adapter | Logger still owns a Firebase sink. Activity log reaches the repository by `has_method` and uses wall-clock time (breaks replays) |
| `tabletop_state.gd`, `table_grid_state.gd`, `hand_state.gd`, `asset_box_state.gd`, `tabletop_definition_builder.gd` | Module family: `tabletop` | First real modules; today they live inside core |
| `sandbox_state.gd` | Kernel mode policy (see section 3) | Currently a separate class with its own verbs |
| `game_api.gd` | Adapter (console/debug projection) | Rooted at global `G` |

Components in `src/components` (14, each with `component.jsonh`) are already modules,
but visual only. Adapters today: `src/network`, `src/mcp`, `src/runtime`, `src/authoring`.

## 3. Session mode (match vs sandbox)

Observed:
- `runtime.mode` is `match` or `sandbox`.
- Match runs through `GameplayState`: session-active, participant and turn checks,
  event history, persistence.
- Sandbox runs through `SandboxState`: in memory, no events, no persistence, own verbs
  (`sandbox.spawn`, `remove`, `set_property`, `move_to_slot`, `move_free`, `set_score`,
  `snapshot.save/restore`). Can export the state as an initial setup.
- Only `games/table_debug` uses `runtime.mode = sandbox`. `games/test001` instead sets
  `sandbox.enabled`, which lets MCP create objects inside a match. Two overlapping ideas.
- The live UI path (`GameSessionRepository`) writes to Firebase directly, so neither
  mode's rules apply to it.

Proposed:
- Mode is a kernel concept: a session policy chosen at start, not something each
  module reimplements.
- Turn enforcement belongs to the match policy. Sandbox lifts it.
- Merge the two sandbox ideas into one: `runtime.mode`.
- Private, non-gameplay actions (reordering your own hand) are a separate product
  decision and may not need a turn even in a match.

## 4. Missing versus the target engine
- Minimal kernel (tabletop concepts still inside core).
- Manifests for core pieces (only components have `component.jsonh`).
- Modules outside the tabletop (camera, animation, effects, NPC AI).
- Integration validator (orphan events, dependency graph, golden replays,
  and a rule that detects writes bypassing the command path).
- Studio and `engine watch`.
- Deterministic time/ids in core (wall-clock use found in logger and activity log).

## 5. Extraction order
E0 route all mutations through the canonical command path (in progress).
E1 generic structure validator split from BGO-specific rules.
E2 kernel: registry, capabilities, command protocol, mode policy.
E3 `status.json` as the base of the Studio.
E4 modules outside the tabletop.
E5 integration validator, watcher, Studio.
