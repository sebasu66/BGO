# BGO Component Standard

This is the canonical component contract for the unpublished BGO prototype. There is one current standard; obsolete approaches are deleted and remain only in Git history.

## Component identity and declaration

Every component lives under `src/components/` and owns one strict JSON-compatible `component.jsonh` containing:

- `schema: "bgo.component"`
- globally unique stable ID matching `bgo.<kind>.<name>`
- semantic `kind`
- non-empty human/agent-readable `description`
- internal scene path
- typed configuration schema
- unique capabilities from the central capability catalog
- canonical verbs implemented by registered runtime handlers

Adding a component must not require editing a central component switch. The registry discovers contracts recursively.

## Domain and presentation boundary

`LogicalObjectState` is the only authoritative state for a game object. It owns identity, component ID, owner, holder, logical location, visibility, quantity, semantic state and extensible properties.

Godot scenes are presentation and interaction adapters. They may cache visual values for rendering, but must not serialize or independently decide authoritative ownership, quantity, location, legality or game outcome.

Components do not all inherit irrelevant behavior. Compatibility is expressed through capabilities. A board is not forced to be ownable; a counter is not forced to be rotatable; a miniature can compose the capabilities it actually supports.

## Capability contracts

Capabilities are declared in `src/capabilities/capabilities.jsonh`. A capability may require:

- logical state fields;
- canonical verbs;
- emitted event types;
- presentation methods.

CI and the runtime reject unknown capabilities and components missing required verbs. Declared verbs are rejected by CI if no runtime handler is registered.

Initial domain capabilities include movement, placement, ownership, holding, quantity and semantic state. Reserved extension contracts include runtime spawning/removal, locking, transfer, rotation, home/return, arbitrary stats, automatic facing and interaction filtering. A component must not claim one of these until its required handlers and tests exist.

`spawnable` describes whether the running game may create additional logical instances from a component definition. It is not implied merely because a component has a Godot scene: scenes also represent fixed boards, zones and setup-only objects. The game runtime owns instance IDs, authorization, placement and registration; the component contract declares that it supports the operation.

`despawnable` permits an instance to leave active play. Returning to the box is a semantic removal that remains recorded in history; it is not an untracked `queue_free()`. Whether removal destroys, archives or moves the object to an out-of-play collection is defined by the command and game package.

`lockable` is authoritative interaction state, not only a visual flag. When locked, ordinary selection, pickup, move and ray-picking are suppressed. Unlocking still uses the validated `object.set_locked` command. A two-to-three-second press is one possible client gesture that requests that command; it is not a permission bypass.

## Commands and events

All authoritative mutation uses the same command path. Commands use imperative dotted names, for example:

- `object.move`
- `object.move_to_collection`
- `object.set_quantity`
- `object.spawn`
- `object.despawn`
- `object.return_to_box`
- `object.set_locked`
- `object.give`
- `object.set_owner`
- `turn.end`

Facts emitted after success use past-tense dotted names:

- `object.moved`
- `object.quantity_changed`
- `turn.ended`

UI, console, AI and declarative listeners issue the same commands. Listeners never write state directly.

The vocabulary has one semantic command per operation. `object.move` changes logical location; an `instant` transition option may render it as a teleport, so `teleport` does not become a competing state mutation. Likewise, UI labels such as “put down” or “pick up” resolve to canonical placement/collection commands.

## Runtime component API

Every loaded game exposes a read-only component catalog derived from its pinned GamePackage. Runtime clients may query component IDs, definitions, capabilities, verbs, live instances and currently legal actions. They may then submit canonical command envelopes through the same validator used by normal UI.

The catalog never grants authority by itself. Spawning, despawning, ownership changes, unlocking and host operations require explicit session permissions and produce recorded events. Runtime code must never instantiate a scene directly as a substitute for `object.spawn`, or remove one directly as a substitute for `object.despawn`.

Suggested stable projection:

- `game.components.list()` and `game.components.get(component_id)`
- `game.objects.list(filter)` and `game.objects.get(object_id)`
- `game.actions.legal(object_id, actor_id)`
- `game.commands.execute(command_envelope)`
- `game.events.subscribe(listener)`

These are projections over the registries and command layer, not a second domain model.

## Web and agent projection

The web client may expose the same safe projection as a namespaced JavaScript bridge for authorized browser automation, for example `window.BGO.game.components.list()` and `window.BGO.game.commands.execute(envelope)`. It must expose structured calls, never arbitrary code evaluation or direct state mutation. Every command carries actor/session identity, passes normal permission and revision checks, and is recorded exactly like a UI command.

Public information intended for AI discovery should use normal semantic HTML, JSON-LD, linked JSON descriptors and discoverable documentation endpoints. Information may be non-visual while remaining present in page source, but secrets, private hands and authorization tokens must never be embedded there. A browser console is a convenient development adapter, not an authentication mechanism and not a replacement for MCP when remote tool discovery is needed.

## Placement and collision

Logical placement is authoritative. Slots and zones decide whether objects may share a location through capacity and acceptance rules. Physics is never the source of legality.

Slots prevent overlap deterministically through capacity and acceptance rules. A slot owns a stable snap pose (position and rotation) and may whitelist component IDs or kinds.

Zones may allow free placement, slots only, or both. During direct manipulation a client may simulate local rigid-body physics for natural dropping and stacking. When manipulation settles, the stable logical pose is committed and becomes authoritative for synchronization, history and replay. Physics never independently changes authoritative state on multiple clients. Objects leaving valid bounds return to their last valid pose or declared home.

Moving between table, hand and player area is handled by the shared placement/collection command handlers, not reimplemented independently by every visual component.

## Presentation filtering

The global table filter decides which objects are de-emphasized. A presentation component claiming `interaction_filterable` must implement `set_interaction_filtered(enabled)` so the filter can make it translucent and non-interactive without mutating game state.

## Miniature extensions

A miniature may additionally compose:

- `rotatable`: deterministic logical orientation plus manual rotation;
- `returnable`: remembers a logical home location and supports return-home commands;
- `stat_bearing`: game-defined serializable statistics exposed generically to UI;
- `auto_facing`: may face a selected/nearest target while preserving an explicit manual override.

Stats are a dictionary defined by the game package, not hardcoded fields such as health or experience. UI is generated from the stat descriptors supplied by the game.

## Required conformance

A public component is incomplete until all of the following pass:

1. structural manifest validation;
2. capability-to-verb validation;
3. registered-handler validation;
4. configuration boundary tests;
5. serialization/convergence tests for logical state it affects;
6. rejection tests proving invalid commands do not mutate state;
7. a focused fixture or conformance game exercising its public behavior;
8. Godot headless import and project quality gate.

Pure or near-pure domain operations are preferred: given the same state and command they must produce the same state and events. Rendering, Firebase, camera and UI dependencies are forbidden in domain handlers.
