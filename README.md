# BGO

BGO is a reusable virtual tabletop runtime built with Godot 4.7.1. BGO Core is not a bundled board game: games are declarative packages that describe components, setup, state and rules against stable BGO contracts.

The same logical session can be viewed from a shared display/TV, a player phone/browser, desktop clients and future agent/MCP clients. Rendering is a projection of authoritative logical state; it is not the source of truth.

## Agreed rendering and authoring sequence

The current priority is to finish and runtime-verify the existing 3D miniature import slice before broadening the rendering surface. That slice includes FBX-to-optimized-GLB/LOD processing, base/billboard calibration, validation and precise error reporting, plus the TEST002 Dracula configuration; only after that evidence is complete should the work be prepared as a PR to `develop`.

The later platform direction is: configurable high-quality 3D with free camera on native Windows; responsive constrained graphics with fixed-height/fixed-pitch perspective cameras on Web and Mobile; and an orthographic tactical pan/zoom view on every platform. Portrait avatars are generated during authoring/import. The Web entry point is a PWA with Mobile, TV/Display and browser-desktop modes; Windows has a separate download and may expose optional companion-enhanced capabilities.

Arbitrary mod assets remain externally hosted and are resolved only through validated URL/hash/cache contracts. Windows authoring may perform untrusted heavy model processing, but runtime clients must consume validated outputs and must not execute arbitrary remote scripts. Later product work may add an assisted Tabletop Simulator JSON migration wizard (not universal compatibility) and an optional PC-generated high-quality board snapshot service. Snapshot request notification is separate from gameplay transport; generated images use expiring shared object storage.

## Single source of truth

Keep project documentation deliberately small. There is one document to read and one to update:

- `README.md` - this file: what BGO is, how it is designed, the decisions already taken and how to run it. If any other document disagrees with this file, this file wins.
- `TODO.md` - everything pending plus the progress log. Update it at the end of every work session.
- `SKILL.md` - coding-agent engineering contract, workflow and machine-enforced conventions.

The former `docs/` folder was folded into this file and `TODO.md` on 2026-10-05 and is gone (Git history keeps the originals). `AGENTS.md` is now a short pointer, and `AI_BACKLOG.md` and `CHANGES.md` are reference/history that must not receive new project state; when something in them is still true and useful, move it here. (`CHANGES.md` is the changelog of a third-party dice-roller addon, not of BGO.)

Contributors and coding agents must read `SKILL.md` before modifying the project.

## Product: one table, many screens

BGO is an online virtual tabletop for turn-based board games. A match is one logical game instance seen through several devices at once. Two ways to play, both supported by the same session:

- **Shared room:** a TV or large display shows the common table (board, pieces, effects, camera, lighting). Each player uses their own phone as a private viewer and controller for the same game.
- **Remote play:** players join the same session from different places and see the same authoritative state.

Different clients may use different cameras, layouts, permissions and private information, but they never fork the game: they all read and change the same logical state through validated commands. Clients share contracts, not implementation.

## Product principles

- **Turn-based first.** BGO does not synchronize high-frequency action gameplay. Board games reduce to discrete commands and events (move a piece, play or draw a card, roll a die, end a turn, change a counter, reveal or spawn an object, refresh a market), which keeps networking cheap.
- **Client-heavy.** Rendering and game execution happen on player devices. The backend coordinates: identity, persistence, discovery, synchronization, access control and the MCP endpoint. It never renders or simulates every match.
- **Provider-independent.** Networking, persistence, authentication, rendering and AI sit behind interfaces, and game-domain code must not depend on Firebase APIs. Today the Firebase repositories are still used directly and only the GitHub jobs relay is a transport class; the planned `RealtimeTransport` boundary is tracked in `TODO.md`.
- **Smart components.** A virtual tabletop should keep the freedom and clarity of a board game while removing physical administration: setup, cleanup, market refills, discard reshuffles, counters, ownership, legal-move calculation, phase advance, scheduled reveals. These behaviors stay modular inside components or rules, so the platform does not turn into a scripted videogame.

## Clients and device roles

| Client | Typical user | What it shows | What it does | Where it runs |
|---|---|---|---|---|
| Display (TV) | The room | Public table: board, pieces, effects, cinematic camera | Presentation only; no direct interaction required | PWA in the TV browser; Android TV wrapper when the TV browser is not good enough |
| Player (phone) | Each player | The same game as a 2D-style view: fixed-height perspective with billboards, plus an orthographic top-down tactical view | Control surface: private hand, dice, actions, targeting, private identity | PWA on the phone; Android app wrapper |
| Remote desktop | A player at a computer | Full player interface in the browser | Same commands as the phone | PWA in the desktop browser |
| Windows native | A player or host who wants quality | Configurable high-quality 3D with a free camera | Same commands; optional companion-enhanced capabilities | Separate Windows download |
| MCP / AI agent | External tools | Logical state only | Validated domain commands, never raw nodes | HTTPS MCP endpoint |

Rules that follow from this table:

1. One codebase and one protocol. Phone, TV and desktop are rendering and permission profiles of the same runtime, not separate applications.
2. Delivery order: try the Web/PWA first. If a device browser is insufficient (common on Smart TVs), distribute the same runtime as an Android or Android TV wrapper. The game model and communication protocol stay identical in both cases.
3. The rendering profile is chosen per client: Windows native gets configurable 3D with a free camera; Web and Mobile get responsive constrained graphics (billboards, fixed-height and fixed-pitch perspective camera with yaw orbit); every platform also offers the orthographic tactical pan/zoom top-down view.
4. A phone is both a viewer and a controller. Anything private (a player's hand, a non-public area) must be filtered per client by the state layer. Render layers never protect secrets.
5. Gameplay legality lives in the domain, never in the web frontend or in a particular client.

## Session and join flow (target design)

This is the intended flow for the web checkpoint W1. It is not built yet; progress is tracked in `TODO.md`.

1. A host creates a session from the web platform by choosing a game package. The session pins the package ID, version and content hash.
2. The session gets a room code and an invite link. Showing a QR code on the TV is the natural way to share it; this is a proposal, not a decision.
3. The TV opens the Display role.
4. Each phone joins with the code or link and takes a seat as a participant.
5. The web launcher opens the Godot runtime with explicit context: session, package, identity (guest for now), device role and preferred profile. There is no hidden coupling.
6. Reconnecting must restore lifecycle, active player, turn number and result (backlog item BGO-011).

Accounts and login are a later checkpoint; anonymous test access is intentional for now. Billing, ads and paid plans are deferred until a commercial model is chosen, and any commercial state must be server-side and never trusted from a client.

## Player interaction model

The phone is not a miniature TV. It is the player's private controller, camera and inventory; the shared display is the communal presentation surface.

- **Display camera.** Target modes, cycled with a remote or simple controls: Overview (the whole table, readability first), Focus or smart camera (frames the region of a relevant domain event such as a piece move, card placement, dice roll or reveal), and later an optional manual or cinematic mode. Not built yet.
- **Phone camera.** Constrained, above the table, orbit style: drag pans and orbits, pinch zooms, an optional rotate gesture adjusts the viewing angle, and limits keep the player over the useful table area. Gestures move the camera first and never drag objects directly.
- **Tap and long press.** A tap runs the object's most common action; a long press (600 ms, `object_context_menu_controller.gd`) opens the extended menu for less frequent or administrative actions. Both come from the object's components and the player's permissions, never from a global menu. A deck, for example, draws on tap and offers move, shuffle, split, give and remove in the extended menu.
- **Pick Up and Place modes** replace drag-and-drop of 3D objects on mobile (the action strip exposes PICKUP and PLACE). In Pick Up mode, tapping eligible objects moves them into your hand, several in a row. In Place mode you select an object or an ordered group from the hand and tap destinations; repeated taps place them sequentially because the hand keeps its order.
- **The hand is a generic container,** not only for cards: miniatures, tokens, coins, dice, markers and temporary objects. Objects in a hand follow the player, not a table coordinate. Others see them fully (owner), masked, hidden, or only as a count; this filtering is not enforced yet.
- **Ownership versus possession.** `owner_id` is persistent game ownership (a red miniature belongs to the red player); `holder_id` is current possession (a coin that player 2 holds right now). The split is what makes giving money, cards or shared resources natural.
- **Transfers** (give an object, give N units, trade, return to the common supply) are commands validated by rules and permissions. No transfer verb exists yet.
- **Presence.** Each player may publish camera transform, pointer transform, selected object and interaction state; remote clients draw a lightweight avatar rig (head, pointer, optional hands) so people feel present at the same table. No video is streamed, and a future VR client could swap in headset and controller transforms. Render layers and culling masks (a public layer plus private layers per player) are a rendering mechanism, not a security boundary: information a client is not allowed to know is never sent to it just because its camera does not draw it.

## Events, checkpoints and restoration

- Every meaningful action is a high-level command recorded as an event from the start. The state keeps two views: the current state for rendering and sync, and an append-only event history for inspection, debugging desyncs, replay, a readable player history, AI analysis and reconstruction. `GameplayState` already keeps `event_history` and a `revision`.
- **Checkpoints** (target): a complete serializable state plus metadata, taken at useful boundaries such as setup complete, start of a turn or round, before a complex resolution, or an explicit host save. Today only sandbox has in-memory named snapshots, with no history; match sessions have none.
- **Restoration** is a session-level administrative action, not a local undo. It restores the whole logical state: objects and poses, hands and containers, ownership and possession, counters and resources, deck order when needed, turn and phase, permissions, the active player and the random state. It normally belongs to the host or referee and may require player consensus depending on the game. It is itself recorded as an event (for example `session.restored` with actor, checkpoint, previous and new revision) and never deletes the original history.

## Modular engine architecture

BGO is the first product built on a modular game engine: a small kernel, hard-separated modules and replaceable adapters. Board games are the first kind of game it delivers, not the only kind it can host. The extraction is incremental: the engine is carved out of BGO, not rebuilt beside it. Steps E0-E5 are tracked in `TODO.md`.

```text
Adapters   Godot view, Firebase/GitHub transport, MCP        (replaceable)
   |
Modules    one feature each: contract + data + logic + config + view
   |
Core services   console, logger, debug, base empty-table renderer
   |
Kernel     command -> event protocol, registries, session lifecycle,
           session mode policy, serialization, event routing
```

Dependency rule: each layer may depend only on the layers below it. The kernel never depends on core services, modules or adapters. Today `src/core/bgo_logger.gd` still owns a Firebase sink, which violates this and is tracked as debt.

Core services belong to every game regardless of its type: the in-game terminal console, logging, debugging and the basic rendering of an empty table with its camera. Modules are everything a game adds on top of that.

### Modules

- A module lives in its own folder and depends only on the kernel's public contract and its own files. It declares what it provides, requires, emits and consumes in a manifest (`component.jsonh` today).
- Modules must be developed independently: working on one must not be able to break another as long as it respects its contract and the core stays compatible.
- GDScript has no visibility rules, so isolation is enforced from outside the language: the folder rule checked by `scripts/check_structure.py` (today it only checks core against Firebase), path-based ownership (CODEOWNERS and path-aware CI), and later separate packages that depend only on the contract.
- Every module publishes its methods to the console through an explicit `console_api()` descriptor, so any component can be found, inspected and driven from the terminal, MCP or AI without a GUI. Adding a dice must make `throw` callable from the terminal the same day.
- Every module carries a `MODULE.md` that states its concept and business rules in numbered plain language (for example H3, A2), plus the open questions and gaps. The owner reads and corrects those rules instead of reading code.

### Studio

`python scripts/build_studio.py [--open]` generates a read-only page at `.engine/studio/index.html` (generated, gitignored) from the component manifests, code, tests and git history. It has four zoom levels: symbol with a health light; ports and checks (capabilities, config, verbs, manifest/console/test checklist); concept (from `MODULE.md`, or an auto-draft labelled as unvalidated); and code. Green means mechanical checks only: "tests reference it" is a name match, not coverage. The Studio exists so the owner can follow the implementation without rereading code, and so any new agent or developer can recover the state of each part.

## Ownership boundaries and engineering rules

What lives where:

- **BGO Core** (this repository): session and game domain model, commands, validation, permissions and events; component contracts and registry; slots, zones, ownership and visibility policies; render, networking and persistence abstractions; game-package loading; asset resolution and validation; test and conformance infrastructure; the logical API for MCP.
- **Core component library** (this repository): reusable boards, slots, pieces, hands, player areas, containers and similar. Game definitions reference stable component IDs (`bgo.<family>.<name>`), never internal scene or script paths.
- **Conformance games** (this repository, `games/`): small fixtures that exercise the public capabilities of components. They use exactly the same package format as external games; there is no special runtime format for them.
- **External game packages and mods** (not in this repository): a real game is a package of declarative definitions plus optional assets or remote asset references. It must eventually load from local storage or a remote manifest without rebuilding BGO. Packages are untrusted declarative content: no remote GDScript is ever executed to open a game, and a session pins an exact package ID, version and content hash so every client uses the same definition (pinning is not built yet).

Engineering rules:

1. A subsystem is not complete because its code exists. It is complete when it has a focused test fixture, automated checks where practical, and the previous capabilities still work. Every checkpoint keeps the project runnable locally, keeps the Web export valid, and keeps domain state, rendering, networking and game data separate.
2. Domain behavior must be understandable and testable without rendering, UI or Firebase. The direction is pure operations, `state + command -> new state + events`; rendering and Firebase consume the result and never decide whether an action is legal.
3. Every public component should have focused tests and at least one conformance game that exercises its meaningful public capabilities.
4. BGO synchronizes logical game objects, not graphics. One object may have several representations (high or low detail mesh, 8 or 4 direction billboard, top-down sprite, icon); a client-local selector picks one from its graphics profile and context, and the logical object ID, slot, ownership, quantity, rotation, commands and events stay identical.
5. Game definitions reference logical asset IDs, not scattered URLs. Remote assets resolve through a validated URL, integrity hash and cache contract. Asset budgets are per profile (desktop high, desktop standard, web 3D, web light, mobile, TV top-down), with results PASS, WARNING or REJECT for a given profile; an asset can be valid on desktop and rejected on Web if the package supplies a fallback representation.
6. Heuristic quality findings (very large files or functions, deep nesting, dead code, duplicated logic, vague names) are reported but do not block. Objective violations block: malformed project or component structure, duplicate component IDs, invalid game definitions, forbidden dependency directions, lint or format failures, failing tests, failed Web export.

## Session modes and game rules

Mode is a kernel concept: a session policy chosen when the session starts, not something each module reimplements. A game declares it as `runtime.mode`.

- **Sandbox:** a real table. Once components exist, anyone can add anything to the table and anyone can grab and move anything freely. No turns and no game rules. Interaction authority still applies: concurrent clients use acquire/lease/release so two people cannot manipulate the same component at once.
- **Match (structured game):** the rules of the game apply. Turn order, how many phases a turn has, who may act on what, and every other rule come from the game's configuration, not from engine code. Board games differ a lot, so none of these rules is hard-coded.

Game rules live in a JSONH file inside the game's own folder, outside the engine code. Modules and core are the engine; a game is data. The games under `games/` (`test001`, `test002`, `table_debug`, `conformance_race`) are test and conformance fixtures that exercise the console, hands, miniatures and similar features. They are not real games.

Today two overlapping sandbox ideas exist (`runtime.mode = sandbox` in `table_debug`, and `sandbox.enabled` in `test001` for MCP object creation). They are to be merged into the single `runtime.mode`.

## Tabletop rules decided so far

Commands (all through the canonical `GameplayState` path, so the console, MCP and AI can drive them):

- `object.move` moves an object to a slot, including objects held in a hand or player area ("place from hand", "take out of a player area").
- `object.move_to_collection` moves an object into a hand or player area.
- `object.reorder_in_hand` reorders a participant's own hand.
- `object.take_from_box` and `object.return_to_box` move objects between an asset box and the table.
- `object.set_quantity` and `object.set_state` change quantity and state.

Decisions:

1. Reordering your own hand is always allowed, even out of turn. It is common sense and not a game rule; a game's rules may override it later.
2. By default you cannot move objects that are not yours. You can inspect them (a zoom view with 3D rotation). Games may restrict or relax this through ownership and rules.
3. Owner, holder/controller, location and visibility remain separate concepts. Hand and PlayerArea remain distinct.
4. A player area has no capacity limit for now. Objects placed in it are laid out next to each other in a grid that grows toward the side where the player is seated (`seat_side`).
5. Identical tokens need a display setting: grouped (one object with a count that behaves like a deck, letting you take 1 to N) or individual. Not built; to be tuned per component when each component is tested on its own.
6. Availability modes and quantities on objects are stored but no rule uses them. Ignore them until a rationale appears.
7. Privacy flags are only settings today: other players' hands and non-public areas are not hidden server-side yet. This is a to-do per component and part of per-client state filtering.

## Canonical core protocol

BGO is an unpublished prototype with no backward-compatibility obligation: one canonical game schema and one canonical runtime path. When a better contract replaces an earlier one, the old implementation is deleted (git is the history), not kept as an alias or migration layer, and tests and fixtures follow the current contract. Versioning and migrations start only when a contract is deliberately published and external games depend on it.

- Every authoritative mutation enters through one command envelope: a stable dotted verb, `actor_id`, optional `target_id`, `args` and an optional `expected_revision` (a stale revision is rejected). Components declare their verbs in `component.jsonh` and the registry discovers them, so adding a component never edits a central switch.
- Commands are imperative (`object.move`, `turn.end`, `match.finish`); results are past-tense events (`object.moved`, `object.quantity_changed`, `turn.ended`, `match.finished`).
- Three separate states: `SessionState` (participants, seats, host, lobby/active/ended lifecycle, result), `FlowState` (phase, turn order, turn number, active participants) and `GameplayState` (objects, tabletop, command execution, revision, event history). `turn.end` is always explicit: manipulating an object never ends a turn.
- `LogicalObjectState` is the only object truth: component identity, owner, holder, location, visibility, quantity, semantic state and serializable properties. Godot nodes are views and never hold a second logical state.
- Declarative listeners (`GameEventRouter`) consume events and issue ordinary commands through the same path. They never mutate state directly; chains are ordered, bounded and part of the same recorded result.
- Host privileges are explicit and auditable commands. Normal play is distinct from authoring and edit mode.

## Tabletop model and object interaction

Design decisions; each item says what exists today.

- **Continuous table.** One table plane with named sections (main board, auxiliary tracks, dice areas, shared reserves, player areas). A section can declare identity, footprint and transform, visibility, owner or seat, child zones and slots, a camera preset and capability restrictions. `TabletopState` already stores sections, zones and slots. Camera presets are shortcuts to regions of the same table, never separate screens or copies of state.
- **Slots and zones** may declare capacity, accepted component or capability classes, ownership and visibility, orientation and drop behavior. Logical occupancy is authoritative; physics may assist picking and visuals but never decides legality.
- **Hand** is a private semantic collection drawn as a viewport overlay: collapsed handle with a count, expandable drawer, enlarged focused item, optional multi-selection, PLACE acting on the selection or the focused item. It takes no space on the table plane. This is the target presentation, not fully built.
- **Only relevant capabilities.** A component declares the actions that make sense for it and for the game configuration, and the UI shows only legal ones (no giant generic action menu). Static scenery is not selectable in normal play. `src/capabilities/capabilities.jsonh` declares, among others, `spawnable`, `despawnable`, `lockable` and `transferable`; a graphical scene is never spawnable by default. Locked objects are excluded from selection, picking and pickup; a long press may request an unlock but the validator decides. Only the catalog entries exist today: the `object.spawn`, lock and transfer verbs are not implemented in `GameplayState`.
- **Contextual interaction.** Focus the active object, dim the rest, suppress accidental background interaction, show only validated actions. **Inspect mode:** tapping an object while inspecting opens an enlarged view with 3D rotation without moving it (not built).
- **Quantities.** Do not assume one rendered object per unit. Representation classes: individual object (a miniature, a chess piece); stack or aggregate (one object for N equivalent items, split when allowed); formation or squad (renders 1, 2, 5, 10 representatives while carrying the real quantity); virtual counter (icon plus number in the UI, or a compact counter object in a player area). Logical state and rendering stay separate.
- **Capability validation.** Components progressively declare what they provide, require and permit so package validation can report contradictory combinations and derive what a configured game allows. For a chess-like fixture that report would say: slot capacity 1, stacking off, spawning off during play, moves limited to board slots, no hand or deck. Extend it only when a real fixture needs it.
- **Camera.** A seated-human tabletop feel rather than a near-vertical technical camera: more distance and height so tall components do not crowd the lens, less top-down pitch, a somewhat wider field of view. Keep one-finger pan, two-finger rotate, pinch zoom and preset navigation.
- **Visual environment.** A warm, horizonless studio: cream or ivory table plane and background, subtle grain, warm key and ambient light from several soft sources, soft shadows where the graphics profile allows. Performance profiles may reduce shadows and lights without changing the look.
- **Presence** is ephemeral and separate from durable state: a marker positioned from a player's camera (`player_presence_repository` and `player_presence_layer`). A player disconnecting never destroys the session; durable state lets everyone leave and return, so synchronous and asynchronous play share one model.
- **Session first.** The table is never entered without a session: select, create or join; resolve participant and seat; load the pinned package; enter the state. A player URL without a valid participant or seat routes to the lobby or seat selection when permitted. Spectator, display and editor modes are explicit, never accidental fallbacks.

## Agent-readable Web and AI (design)

Design only. The JavaScript bridges that exist today serve presence and the logger snapshot, not a semantic session state.

- A running session page should expose a lightweight semantic representation next to the Godot canvas, derived from the same logical model: authorized session state, viewer role and seat, visible sections and objects, legal actions for the current viewer, UI control semantics, package ID, version and hash, and links to rules, manual, capability descriptors and later the MCP endpoint. The live state stays compact and references versioned static resources instead of repeating manuals.
- **Privacy:** agent-readable state passes through the same visibility policy as rendering. Spectator, display, player, host and agent clients get different filtered views. Nothing private may appear in HTML, JavaScript state or a semantic endpoint.
- **Semantic UI shadow:** a compact descriptor of important runtime controls (id, label, enabled, purpose, approximate rectangle, selected object, interaction mode) for diagnostics, E2E and agents. It is never a source of game truth.
- Public landing, catalog and documentation use ordinary indexable HTML with structured metadata; a future well-known descriptor may advertise agent capabilities.
- MCP and AI operate on logical concepts with the same permissions, visibility and validation as a human; an AI participant takes a seat like anyone. The Web semantic interface and MCP are two projections of one state and command layer, never competing models.
- Long term, AI-assisted authoring goes through declarative packages, never trusted generated code: natural-language intent, GamePackage draft, schema and capability validation, preview and conformance checks, publish.

## Component standard

The canonical component contract for the unpublished prototype. There is one current standard; obsolete approaches are deleted and remain only in Git history.

- **Identity.** Every component lives under `src/components/` and owns one strict JSON-compatible `component.jsonh`: `schema: "bgo.component"`, a globally unique stable ID `bgo.<kind>.<name>`, a semantic `kind`, a non-empty description, the internal scene path, a typed configuration schema, unique capabilities from the central catalog, and the canonical verbs implemented by registered runtime handlers. The folder is `snake_case` and owns matching `<folder>.gd` and `<folder>.tscn` files. The registry discovers contracts recursively, so adding a component never edits a central switch.
- **Domain and presentation boundary.** `LogicalObjectState` is the only authoritative object state. Godot scenes may cache visual values for rendering but never decide ownership, quantity, location, legality or outcome. Compatibility is expressed through capabilities, not inheritance: a board is not forced to be ownable and a counter is not forced to be rotatable.
- **Capability contracts** live in `src/capabilities/capabilities.jsonh` and may require state fields, verbs, emitted events and presentation methods. `scripts/check_structure.py` and `CapabilityRegistry` reject unknown capabilities and components missing a required verb. A component must not claim a capability until its handlers and tests exist. `spawnable` means the running game may create more instances (a Godot scene alone never implies it, since scenes also represent fixed boards and setup-only objects); `despawnable` means an instance may leave active play, where returning to the box is a recorded semantic removal and never an untracked `queue_free()`; `lockable` is authoritative interaction state: locked objects suppress selection, pickup, move and picking, and unlocking uses a validated `object.set_locked` command (a long press only requests it, it is not a permission bypass).
- **Commands.** Imperative dotted names, one semantic command per operation. Implemented: `object.move` (accepts objects in a slot, a hand or a player area), `object.move_to_collection`, `object.reorder_in_hand`, `object.take_from_box`, `object.return_to_box`, `object.set_quantity`, `object.set_state`, `turn.end`, `match.finish`. Planned: `object.spawn`, `object.despawn`, `object.set_locked`, `object.give`, `object.set_owner`. Facts are past tense: `object.moved`, `object.quantity_changed`, `hand.reordered`, `turn.ended`, `match.finished`. `object.move` changes logical location and an `instant` transition may render it as a teleport, so there is no competing `teleport` command; UI labels such as "put down" resolve to canonical commands. UI, console, AI and declarative listeners all issue the same commands.
- **Runtime component API** (target projection, never a second domain model): `game.components.list()` and `.get(id)`, `game.objects.list(filter)` and `.get(id)`, `game.actions.legal(object_id, actor_id)`, `game.commands.execute(envelope)`, `game.events.subscribe(listener)`. The catalog never grants authority; spawning, despawning, ownership changes, unlocking and host operations need explicit session permissions and produce recorded events, and runtime code never instantiates or frees a scene as a substitute for `object.spawn` or `object.despawn`. Today's equivalent is the `G` autoload (see Developer tooling).
- **Placement and collision.** Logical placement is authoritative. Slots and zones decide whether objects may share a location through capacity and acceptance rules; a slot owns a stable snap pose and may whitelist component IDs or kinds; a zone allows free placement, slots only, or both. During direct manipulation a client may simulate local physics for natural dropping and stacking, and when manipulation settles the stable logical pose is committed. Physics never independently changes authoritative state on several clients; objects leaving valid bounds return to their last valid pose or declared home. Moving between table, hand and player area goes through the shared command handlers, never per-component reimplementations.
- **Presentation filtering.** A component claiming `interaction_filterable` must implement `set_interaction_filtered(enabled)` so the global filter can make it translucent and non-interactive without touching game state.
- **Miniature extensions** (reserved contracts, not claimable until implemented): `rotatable` (deterministic logical orientation plus manual rotation), `returnable` (remembers a home location and supports return-home), `stat_bearing` (game-defined serializable statistics, with UI generated from the package's stat descriptors rather than hardcoded health or experience fields), `auto_facing` (faces a selected or nearest target while preserving a manual override).
- **Sandbox authoring runtime.** `runtime.mode: "sandbox"` is a local authoring session, not a match with rules switched off: participants, areas, scores and any registered component are allowed, but there is no turn flow, winner, terminal state, event history or remote persistence. Snapshots are explicit named in-memory restore points. Exporting a sandbox yields a declarative initial-state fragment; the package stores only component IDs and allowed configuration overrides.
- **Required conformance.** A public component is incomplete until all of these pass: structural manifest validation; capability-to-verb validation; registered-handler validation; configuration boundary tests; serialization and convergence tests for the logical state it affects; rejection tests proving invalid commands do not mutate state; a focused fixture or conformance game exercising its public behavior; the Godot headless import and the project quality gate. Pure or near-pure domain operations are preferred (same state and command give the same state and events), and rendering, Firebase, camera and UI dependencies are forbidden in domain handlers.
## Player client UX

The player client is a landscape-first Web and mobile controller for one continuous shared tabletop, usable with both thumbs while keeping most of the screen for the game. It never splits a game into artificial screens when the content would coexist on a real table.

- **Camera gestures.** One-finger drag pans in the table plane; pinch zooms within runtime limits; two-finger drag rotates around the fixed vertical axis; Reset Camera restores the seat preset; section shortcuts move to a declared section preset (not built). Defaults follow the seat or player side and a package may tune them later. Desktop mirrors this without taking selection from the left button: left or middle drag pans (a plain click stays selection), right drag orbits with a clamped tabletop pitch, the wheel zooms toward the table point under the cursor, WASD or arrows pan continuously (Shift accelerates), Q and E orbit, Page Up and Page Down or plus and minus zoom, R or Home restores the seat preset. Display clients do not inherit player gestures.
- **Landscape thumb zones.** A left utility strip (collapsible to a handle) holds secondary and global actions: Reset Camera, Filters, later Inspect, fullscreen and orientation, return to lobby. A right game strip holds the match actions: Pick Up when supported, Place when armed, End or Next Turn, and contextual actions for the selection. END TURN stays disabled unless the current participant owns the active turn, read from the logical `SessionState` and never inferred locally. The right strip shows only capabilities relevant to the active game and component, never a giant universal menu.
- **Hand presentation.** A borderless stack of the objects' 3D representations attached to the viewport, with no panel, title or hand-zone background: FILO order with the newest in front, overlap with slight alternating rotation like a physical pile, every object manually selectable with the active one framed, and dense hands reduce the overlap step to stay inside the viewport. Compatible stackable objects group into one visual stack while keeping their logical IDs, and in Place mode the next FILO object is selected automatically after one is placed. `PICKUP`, `NONE` and `PLACE` are logical modes of the global action rail. The carousel is client presentation; ownership, visibility, order, selection commands and placement stay logical.
- **Contextual actions.** Components expose validated actions and the UI shows only those legal now for that object, state and player. While a contextual menu is open the active object stays emphasized, the background is dimmed and accidental background picking is suppressed; a later blur or depth effect is polish, the interaction isolation is the functional requirement. Examples: a deck offers draw, draw N, deal, shuffle; a miniature offers move and rotate where allowed; an aggregate stack offers split, add and remove; static scenery has no normal manipulation.
- **Inspect mode** (not built) gives a non-destructive enlarged, screen-oriented view for reading cards and text-heavy components, seeing properties, inspecting pieces without moving them, and examining remote presence markers. It never alters the logical transform.
- **Filters** are a per-client convenience (show only my pieces, de-emphasize another owner, filter by component type or capability). Filtered-out objects stay faintly visible but non-interactive. This is not privacy: hidden information must be filtered out of the logical client state.
- **Interaction profiles** (not built) are safe declarative presets such as `bgo.player.standard` (tap selects, one-finger pan, contextual actions), `bgo.player.direct_interact` (taps invoke component actions, pickup controls may be hidden) and `bgo.player.card_heavy` (floating hand stack emphasized, rapid placement). A profile maps tap, drag, pinch, pickup, hand-stack and inspect behavior to runtime-owned capabilities and validated commands; packages never supply GDScript for gestures, and a game definition describes structure, rules and presentation intent, never device pixel layouts.
- **Client settings** open from the gear button and change presentation and local preferences, never rules. Sections: Video (dynamic 3D resolution with minimum and maximum render scale, adjusted once per second from observed FPS), 3D Quality (low, medium, high: MSAA and shadows; plus VISUAL DEBUG for diagnostic text, one-centimetre grid points and RGB pivot axes, off by default), Appearance (global UI template, font and control scale, accent color, applied live), Lighting (a client intensity multiplier for key, fill and ambient light) and Gameplay (hand pickup of a stackable component: `ONE AT A TIME`, the default, separates one logical unit, and `WHOLE STACK` moves everything; non-stackable and quantity-one objects always move whole). Values persist in `user://client_settings.cfg`. The panel is the stable component `bgo.ui.settings_panel`. To add a setting: add its default and normalization to `BgoClientSettingsController`, apply it in the controller without coupling it to domain state, add the control under a section or a new tab of `BgoSettingsPanel`, add a focused test, and update this file.

## Table grid and asset box

- **Logical grid.** `TabletopState.grid` is a logical point grid independent of Godot nodes, in centimetres; renderers pick their own world scale. API: `configure_grid(columns, rows, spacing)`, `place_object_at_grid(id, origin, footprint)`, `objects_at_grid_point(point)`, `objects_in_grid_area(origin, size)`, `object_grid_points(id)`. An object has one origin point and a rectangular footprint; placements do not overlap by default and a caller may opt into overlap for future stack and container behavior. The main grid is logically unbounded: signed coordinates stay valid beyond any board, rendering is sparse, and with Visual Debug small point patches appear only around physical objects. The large table plane is a visual and picking surface, not a boundary.
- **Anchors.** Every placeable 3D representation puts its root origin on its supporting base, so placement never needs a guessed vertical offset. Small objects (pieces, miniatures, dice, cards, tokens, decks) use `base_center`. Large authored surfaces such as boards should use `base_corner`, aligned with the logical grid origin; today the code only uses `base_center`, and existing centred boards need an explicit placement migration before the anchor changes, because renderers never silently move them.
- **Board resolution.** `BgoCheckeredBoard` separates a logical board unit from its centimetre grid: `grid_cell_size_cm` is the physical size of one unit and `grid_points_per_unit` is the placement resolution. TEST001 uses 5 and 5, so an `8 x 6` board exposes `40 x 30` points, centred inside each centimetre subdivision. Placement is magnetic and deterministic: the nearest named slot first, otherwise the nearest valid fine-grid point, persisting a `grid` location with origin and footprint. Mouse, touch and remote state share this policy; it is never inferred from the rendered mesh. The scene component is `src/components/grids/table_grid/table_grid.tscn`.
- **Asset Placer** (editor tool only, never runtime domain): `src/editor/bgo_asset_placer_grid_bridge.gd` snaps preview positions to the table grid when a `BgoTableGrid` exists in the edited scene, even if Asset Placer's own snapping is off, and tags placed nodes with `bgo_grid_origin`, `bgo_grid_footprint`, `bgo_grid_path` and `bgo_placeable` metadata. Scenes without a table grid keep the original behavior.
- **Asset box.** `AssetBoxState` is the logical catalog or reserve of assets declared by a package: membership, quantity, availability and ownership, never positions or occupancy. At runtime the intended representation is a viewport-attached drawer, not a Node3D on the table. The `ASSET BOX` control toggles the catalog state and status; instantiating new copies from the catalog in the client is the next slice. When an item leaves the box its placement is validated by `TabletopState.grid`. A definition declares `"asset_box": {"id": "game_box", "label": "ASSET BOX"}` and places objects there with an `initial_location` of type `asset_box`.
## Authoring: node composition, variants and behaviors

Direction for the desktop authoring workflow. Existing nodes in `src/authoring/nodes/`: `BgoGameObject3D`, `BgoBehavior`, `BgoPlaneRepresentation`, `BgoModelRepresentation`, `BgoBillboardRepresentation`, `BgoPbrMaterial`. The rest below is design.

- **Composition over monoliths.** A game component is assembled from reusable BGO nodes plus declarative properties, following Godot's composition model; ordinary variants need no trusted GDScript. A scene normally has one `BgoGameObject3D` root that coordinates presentation and features and exposes an editable property bag, and it stays a presentation adapter while `LogicalObjectState` stays authoritative.
- **Three namespaces.** `definition` holds authored defaults that belong to the package; `state` holds per-instance mutable match state synchronized by the domain model; `variables` holds game, match and player variables owned by the right scope rather than by a render node. The editor may show definition properties as a key-value map, but every child feature or representation publishes a schema so keys stay typed, discoverable and validated, with provenance, type, range, description and default shown in the inspector.
- **Representations and anchors.** Interchangeable visual adapters that never own gameplay state: plane (cards, tokens, flat art), box (decks, blocks), primitive, model (GLB props, miniatures, dice), billboard (comic-style characters). PBR surfaces use one reusable material node (albedo, normal, roughness, metallic, AO, height, UV scale, scalar overrides). Every physical object has an explicit configurable pivot (`base_center`, `center` or `custom` through a `Marker3D`), and slots, snapping, rotation and animation use the logical anchor, not the mesh origin.
- **Feature nodes** (stackable, rotatable, lockable, placeable, flippable, surface, slot layout, stats) publish their properties and capabilities and integrate with canonical commands without silently mutating authoritative state. Pure domain constraints such as uniqueness, maximum instances or spawn policy may stay declarative package constraints.
- **Base component, variant, instance.** A base is a reusable composition with a typed property contract. A variant is a package-owned specialization that normally only overrides definition properties (base `bgo.character.billboard`, variant `wasteland.raider_rifleman` overriding `image`, `height`, `shadow_radius`), and may compose permitted feature nodes when it truly needs different capabilities. An instance is a concrete object with a stable ID, owner, location and state, and instance state is never copied back into the variant. Authoring operations: create base component (core authoring only), create variant, duplicate variant, add to package, create setup instance from a variant, preview and validate.
- **`BgoBehavior`: WHEN event, IF conditions, THEN actions.** It subscribes to canonical events and submits ordinary commands through the same authority and validation path as UI, console and AI, and never edits another node, a Firebase row or a state dictionary. Friendly triggers (`onPlay`, `onDiscard`, `onTake`, `onTurnStart`, `onTurnEnd`, `onEnterSlot`, `onLeaveSlot`, `onAcquire`, `onRelease`) compile to canonical event types plus filters, never a second vocabulary (for example `onDiscard` maps to a canonical collection-move event filtered to the discard collection), and the editor also allows picking the underlying event directly. Conditions are side-effect-free expressions over authorized state. Actions translate to registered commands and setters across Game, Match and System scopes. Targets use a compact language (`self`, `actor`, `owner`, `holder`, `source`, `target`, explicit IDs, queries by tag, component, slot or zone, `Match`, `Game`, `System.environment`) that resolves deterministically and respects visibility and permissions. Chains are ordered, bounded and observable: maximum depth and action count, loop detection or causality IDs, deterministic ordering, idempotency for retried external commands, every resulting command and event recorded in the parent result, and precise validation errors.
- **Authoring UX** reuses Godot's Scene Tree, Inspector, gizmos and `@tool` nodes instead of rebuilding a scene editor. A BGO dock adds package context, variant inheritance, validation and high-level workflows: create or open a GamePackage, browse components and variants, create a variant, add or remove feature nodes, edit the effective property map and behaviors, validate, create setup instances, preview or play in sandbox, export.
- **Boundary.** Game is definitions, variants and authored behaviors; Match is instances, players, variables, flow and state; System is environment and application-level capability; Godot custom nodes expose and render those concepts and never become a second source of gameplay truth.
## Developer tooling

- **Console.** `addons/console` is the DEV-only `Console` autoload. `BgoGameCommandConsole` (`src/debug/bgo_game_command_console.gd`) bridges it to live objects through focused `bgo_console_*` services (discovery, API projection, invocation and conversion, lifecycle cleanup). Only nodes with an explicit `console_api()` descriptor are command hosts; runtime reflection is never an exposure mechanism. It is a developer tool that never bypasses domain validation and is disabled in release builds. Covered by `tests/console_command_bridge_test.gd`.
- **Vocabulary.** Roots `Game.*`, `Match.*`, `System.*`. `getX` reads without side effects, `setX` requests a validated mutation of an intentionally writable property, `isX` and `hasX` return booleans, everything else uses an explicit verb (`moveToGrid`, `roll`, `shuffle`, `delete`). Public spelling is camelCase while internal GDScript stays snake_case, and lookup is case-insensitive. Discovery: `System.api.getEntities()`, `System.api.getMethods("Match.piece_1")`, `System.api.describe("Game.definition", "getWidth")`, `System.api.audit()` (every declared entity, exposed name and explicit call target; private helpers and undeclared methods cannot enter the registry), `System.constants.getAll()` and `System.constants.get(name)`. Public constants are flat `UPPER_SNAKE_CASE` under `System.constants` (`COMPONENT_BASIC_CYLINDER`, `PLAYER_COLOR_RED`, `LOCATION_PLAYER_AREA`, `ROLE_HOST`) and unknown constants are rejected. `Tab` completes factories, methods and live `Match.*` entities from the innermost builder.
- **Fluent definition builder** (`src/authoring/bgo_fluent_expression_parser.gd`, `src/authoring/bgo_builder_registry.gd`). A restricted parser, not `eval`: only registered builders, methods, literals and `System.constants.*` execute. Example: `Game.create().setId("x").setName("BGO Component Test").setPlayerCount(2).setTurnBased(true)`, then `Game.current().setTable(Game.Table.create().setWidth(15.5).setDepth(9.8).addComponent(Game.CheckeredBoard.create().setId("main_board").setColumns(8).setRows(6)))`, `addPlayer(Game.Player.create().setName("Player 1"))`, `addCatalogEntry(...)`, `setAssetBox(Game.AssetBox.create().setId("game_box"))`, `addObject(Game.BasicCylinder.create().setOwner(1).setInitialSlot("1,2"))`, `validate()`, `build()` and `saveAs(path)`. Every `setX` and `addX` returns the parent builder, so nested and multi-line chains are equivalent. `build()` returns `{ok, data, errors}` and succeeds only if the definition loader accepts the whole definition; `saveAs()` re-validates and accepts `user://` and, in DEV only, `res://games/`. Builder types: `Game`, `Game.Table`, `Game.Player`, `Game.CheckeredBoard`, `Game.PlayerArea`, `Game.CatalogEntry`, `Game.AssetBox`, `Game.BasicCylinder`. Player IDs are generated (`player_1`, `player_2`), a two-player preset puts red and blue opposite each other, positions and rotations are rounded and normalized, and `getWarnings()` reports it. The builder authors definitions and never bypasses validated `Match.*` commands or silently replaces the active match.
- **`G` autoload** (`src/core/game_api.gd`), the GDScript debug root: `G.help()`, `G.games()`, `G.definition(path)`, `G.components(id)`, `G.state(path)`, `G.execute(command)` and `G.export_initial_state()`. Reads return copies, and `G.execute` uses the same validated command path as UI, automation and MCP, so accepted changes stay evented and replayable.
- **Loading a game.** One installed JSONH definition at `games/<id>/game.jsonh`, chosen with `/?game=<id>` on Web or `--game=<id>` on desktop, and a role chosen with `--role=` (Web: `?role=display` or `?role=player&player=player_1`). `table_debug` is the first table-only conformance scene: no board, four colored areas exercising free placement, slot-only placement, accepted component kinds and mixed placement, with `table.debug: true` enabling diagnostic overlays, running in sandbox mode.
- **Logging.** Godot's native file log goes to `user://logs/bgo.log` and keeps ten session files (`debug/file_logging/max_log_files`). `BgoLogger` writes structured JSON events to the Godot output, a per-run JSONL diagnostic sink and the prototype remote sink (still Firebase, tracked debt); in debug builds it also forwards events to the console with level coloring without echoing back into Godot. Minimum level is `set_minimum_level()` (`debug`, `info`, `warning`, `error`; debug builds default to `debug`, release to `info`). Composition records `COMPONENT_INSTANTIATION_STARTED`, `COMPONENT_PROPERTY_APPLIED`, `COMPONENT_PLACED`, `COMPONENT_INSTANCE_READY`, component lifecycle events (`COMPONENT_READY`, `COMPONENT_CONFIGURED`, `COMPONENT_REBUILT`) and `TABLE_COMPOSITION_READY`. Components emit `component_event(event_name, payload)` and the composition adapter adds the stable instance and component IDs. The console separates Commands from Logs, with level filter, search and Clear (`logs.level`, `logs.search`, `logs.clear`); filtering is visual only.
- **Error diagnostics.** Normal logging stays local and in memory, and an error run is published only when an error is detected: the latest at `debug_public/latest_error/TEST001` in RTDB (public and temporary, remove or protect it when RTDB rules are enabled) and the full history under `/debug/<game>/<client>/error_runs/<run_id>`. A payload has run, game and client IDs, capture time and source, recent structured events and the browser flight-recorder snapshot. The Web export injects `window.__bgoFlightRecorder` before Godot starts to buffer console output, `window.onerror` and unhandled rejections; Godot polls it and uploads when the error generation advances, and if it is missing `BgoLogger` publishes a synthetic `WEB_FLIGHT_RECORDER_MISSING` error.
- **Repeatable Web export.** `scripts/export_web.ps1` (Windows) or `scripts/export_web.sh` (Linux, macOS, CI) cleans `build/web`, imports the project, exports Godot Web, copies the auxiliary pages and runs `scripts/validate_web_export.py`, which fails if the main Web files are missing or empty, the flight recorder is absent from `index.html`, the TEST001 JSONH is not in `index.pck`, or `/project-status/` and `/test-launcher/` were not copied. CI uses the same path. `scripts/check.ps1` and `scripts/check.sh` are the local quality-check wrappers.
## UI stack and add-ons

| Add-on | Version | Responsibility |
| --- | ---: | --- |
| Spark | 1.0.2 | Lightweight reactive bindings for conventional Controls and adapters |
| Reactive UI | 0.12.1 | Declarative UI runtime and `.guitkx` rendering |
| Reactive UI Editor | 0.10.1 | Godot editor authoring for Reactive UI |
| GDSS | 0.7.0 | Themes, visual states, transitions, stylesheet authoring |
| GodotX Toast | 2.0.0 | Transient success, error, warning and information feedback |
| Developer Console | 1.5.0 | DEV-only runtime console with automatic BGO object command discovery |
| Lucide Icons for Godot | 1.1.0 plus a fixed Lucide 1.33.0 subset | Consistent SVG-derived runtime and editor icons |

`scripts/check_structure.py` pins the first five versions. Also installed: `ambientcg`, `asset_placer`, `bgo_component_browser`, `blendkit`, `dice_roller`, `godot_ai`, `JsonhGd`, `lente`, `properUI_drawer`, `TexturedGlassMaterialPack-4`, `tnowe_extra_controls`.

- Reactive UI Editor depends on Reactive UI and must be enabled after it. `reactive_ui_editor` and `reactive_ui_analyzer` are excluded from Web exports, which the structure check enforces. These add-ons are presentation and authoring only: BGO Core stays authoritative and UI bindings never create a second game state or couple domain rules to rendering or Firebase. The Developer Console is separate DEV tooling and never a production gameplay authority.
- **UI components** (stable IDs; games reference IDs and allowed configuration, never `.gd` or `.tscn` paths): `bgo.ui.context_menu` (reactive menu with hierarchical rows and selection states, may live in a transparent `SubViewport` shown as a 3D billboard), `bgo.ui.toast` (facade over the installed `GodotxToast` runtime), `bgo.ui.action_strip` (declarative strip that receives IDs, labels and Lucide icon IDs and holds no game logic), `bgo.ui.session_header` (session, mode, profile and turn) and `bgo.ui.settings_panel`.
- **Theme profiles.** `BgoUiThemeProfiles` builds one shared `Theme` applied to the top UI controls, and components use semantic variations (`BgoShellPanel`, `BgoHeaderPanel`, `BgoShellButton`, `BgoEmphasisButton`) instead of local styles. Settings exposes the base profile, font and control scale and accent color, persisted per client and applied live. To add a template, add an entry to `PROFILES` in `src/components/ui/theme_profiles/ui_theme_profiles.gd`. A game may propose a declarative template but the client's local preference wins.
- **Licenses.** Spark, GDSS and GodotX Toast carry permissive licenses. Reactive UI and Reactive UI Editor use the ReactiveUI Community License 1.0, not MIT: it requires a "Made with ReactiveUI" notice and a commercial license above its revenue or funding threshold, so review `addons/reactive_ui/LICENSE` and `addons/reactive_ui_editor/LICENSE` before any commercial distribution. Lucide is pinned to commit `bfc6e57430c67ce59d788aa0c674559aeb20fe4e` and a fixed subset of its SVGs is vendored so editor startup and exported clients never download anything. Sources: github.com/CosmoMyzrailGorynych/spark, github.com/yanivkalfa/ReactiveUI-Godot, github.com/cruglet/gdss, github.com/godot-x/toast, github.com/Rodrigoalvesr/lucide-godot, github.com/lucide-icons/lucide.
- **Add-on decisions.** Use now: JsonhGd (GDScript JSONH for definitions and configuration, no GDExtension or .NET in the Web-first runtime) and Deep RayCast 3D (optional deep selection when pieces overlap, keeping the single-hit raycast as the fast path). Experiment: Lente for camera authoring, grading and captures (the Compatibility renderer has no engine depth of field, so DOF is a Forward+ experiment, and core camera logic never depends on it), GPU Texture Painter for future authoring or customization (needs UV2 data and Web and mobile performance testing), GoBuild as an editor-only mesh tool (review GPLv3 before redistributing). Not for core: xpTURN.Klotho (deterministic lockstep and rollback on Godot .NET, unnecessary for turn-based Firebase), Card Combat Engine (specialized for card-combat concepts, usable as reference or an optional game module), Mesh Tools (selective authoring use only). Localization: JSONH Translations needs .NET, so keep translation data portable and later load it with JsonhGd into `TranslationServer`.
## Repository structure

```text
BGO/
|-- src/
|   |-- runtime/        # client runtime, composition and bgo_client.tscn
|   |-- core/           # domain state, definitions, registries and command API
|   |-- components/     # reusable tabletop/UI components + component.jsonh
|   |-- network/        # persistence/realtime adapters and repositories
|   |-- ui/             # reusable client-side UI controllers
|   |-- mcp/            # MCP/domain command projection
|   |-- debug/          # runtime diagnostics still required by current autoloads
|   |-- authoring/      # authoring-only; excluded from Web runtime export
|   |-- editor/         # editor-only; excluded from Web runtime export
|   `-- demo/           # demonstrations/prototypes only
|-- games/              # declarative GamePackages / fixtures
|-- assets/
|   |-- source/         # original sources; ignored by Godot and not shipped
|   |-- authoring/      # authoring library; excluded from Web
|   `-- runtime/        # assets intentionally shippable with the runtime
|-- addons/             # installed Godot runtime/editor plugins
|-- backend/
|   `-- functions/      # Firebase HTTPS Functions, including the MCP endpoint
|-- hosting/            # static Firebase Hosting source surfaces
|-- examples/           # third-party/reference examples; ignored by Godot
|-- scripts/            # development/build/deploy tooling
|-- tests/              # automated tests; not shipped in the Web PCK
|-- fastlane/           # Android/store/release metadata
|-- build/              # generated export output; gitignored
`-- artifacts/          # generated browser/CI evidence; gitignored
```

`examples/.gdignore` prevents downloaded examples from entering the active Godot project. `assets/source/.gdignore` does the same for original source material such as Blender files. `assets/authoring/` may remain importable in the editor/authoring application but is excluded from the Web export; `assets/runtime/` is the place for resources intentionally shipped to clients.

## Runtime entry point

`project.godot` starts `src/runtime/bgo_client.tscn`, whose root script is `src/runtime/bgo_client_runtime.gd`.

The historical production code under `src/demo/main_*` was moved to `src/runtime/` and split into policy-sized responsibility layers:

```text
client_runtime_base
  -> client_runtime_state_sync
  -> client_runtime_interaction
  -> client_runtime_composition
  -> client_runtime_gameplay
  -> client_runtime_camera
  -> bgo_client_runtime
```

This chain is a migration seam, not a pattern to extend. New camera, networking, shell, session, interaction and UI responsibilities should preferentially become focused controllers/services composed by the runtime instead of adding another orchestration inheritance layer.

Runtime inheritance is one-way: a parent layer may call only methods declared by itself or an ancestor. It must never depend on a method first introduced by a child. After moving or renaming GDScript files, or changing class_name/inheritance, validate once from a clean .godot cache because stale class metadata can hide an invalid dependency direction.

The production runtime composes `RuntimeSessionAdapter`, which loads shared match snapshots into the canonical `SessionState` + `FlowState` + `GameplayState` model. There is no second logical-client entry path.

## Runtime rules

BGO supports two product modes:

- **Structured games:** domain rules, turns, ownership and legal commands are enforced.
- **Sandbox:** turn/rule restrictions are bypassed, but interaction authority is not. Concurrent clients still need acquire/lease/release semantics so two users cannot manipulate the same component simultaneously.

`Hand` and `PlayerArea` are separate concepts. Owner, holder/controller, location and visibility are also separate state dimensions.

Game packages reference stable component IDs such as `bgo.<family>.<name>`; they do not reference internal `.gd` or `.tscn` implementation paths.

## Web export boundary

The Web PCK is a runtime artifact, not a copy of the repository.

It includes runtime/core/components/UI/network/MCP resources required by the client, required runtime add-ons, declarative `games/*/*.jsonh`, the runtime capability catalog `src/capabilities/*.jsonh`, and component `component.jsonh` contracts.

It excludes generated output, docs, examples, source/authoring assets, backend functions, development scripts, tests, static hosting sources, authoring/editor code and editor-only add-ons.

`src/debug/` is not excluded yet because `project.godot` still autoloads `BgoGameCommandConsole`; remove or conditionalize that dependency before excluding debug code.

Sandbox is part of the Web runtime. Authoring/editor tooling is not.

## Component public API

Registered BGO components expose a validated public control surface for the existing Developer Console, editor workbench GUI and MCP projection. Components keep their native Godot inheritance (`Node3D`, `Control`, `Area3D`, `RefCounted`, and so on); the shared contract is structural rather than a forced base class.

The common surface is the explicit `console_api()` descriptor, configuration methods and a visual refresh method where the component has a rendered representation. All 14 registered `bgo.*` components implement this surface. `console_api()` preserves the stable component ID, embeds method descriptions, exposes adapter-ready Godot argument types and maps every manifest `config` property to a curated setter. Component-specific setters validate input, update the representation and emit an update signal when applicable. Callers use these methods instead of changing exported properties directly. Undeclared methods are never published through reflection.

For example, `BgoCheckeredBoard` exposes `set_light_texture_path(res://...)`, `set_dark_texture_path(res://...)`, `set_light_color_string(...)` and `rebuild()`. Texture setters resolve only project resources and accept only `Texture2D` assets. Invalid paths or values return failure without changing the component.

The console, GUI and MCP adapters consume the same declared method metadata and validation path. Descriptor-bound arguments let concise methods such as `setColumns(value)` route to a shared internal property applicator without inflating the public GDScript surface. They are applied identically by command-line and Python-like console invocation. Adding a component requires its manifest, implementation API and focused public-API test to remain aligned.

JSON/JSONH files loaded with `FileAccess` must be explicitly covered by the export preset and verified in the generated `index.pck`.

## Networking and MCP boundary

Realtime gameplay transport and external AI commands are separate concerns:

```text
RealtimeTransport          SessionCommandBridge
(peer gameplay)            (HTTPS/MCP ingress)
		\                    /
		 -> host/domain command authority
					|
			 canonical logical state
```

MCP tools operate on domain concepts such as `piece.move`, `deck.shuffle` and `game.get_state`; they never directly mutate Firebase rows, WebRTC/MQTT peers or Godot scene nodes. The host validates accepted commands and broadcasts resulting state/events.

Firebase Functions can continue hosting the public HTTPS MCP endpoint even if high-frequency gameplay later moves away from Firebase RTDB.

The current prototype synchronizes through `GameSessionRepository`, which polls the whole Firebase RTDB session every 0.75 seconds. That is acceptable as a proof of concept but not the target: it costs traffic when nothing changes, bounds latency by the polling interval, repeats the same reads on every client, suits drag and pose updates badly, and makes the transport easy to confuse with the authoritative model. A transport carries commands, events and state projections; it never decides whether a move is legal.

```text
                 BGO Core: state + command -> events
                              |
                   host / domain authority
                              |
            +-----------------+-----------------+
            |                                   |
     RealtimeTransport                    Persistence
     live traffic: commands, events,      durable snapshot, recovery,
     leases, transient drag and pose      asynchronous play, catalog
            |                              (Firebase RTDB for now)
            +--> connected clients
```

- Firebase is not automatically removed. A session must survive every peer disconnecting, so a purely ephemeral peer mesh is never enough: authoritative state is persisted before peers disappear, and a returning client recovers the snapshot and rejoins. This also allows asynchronous turn-based play with nobody online.
- Two independent improvements exist: Firebase listeners instead of polling (a valid intermediate and fallback), and moving live traffic off RTDB to a peer or relay transport, which the planned spike (see `TODO.md`) will test on a disposable branch.
- The first spike is host authoritative: a client sends an intent, the host validates it through the Core, then broadcasts the accepted state and events. Sandbox may bypass rule authority but still enforces interaction leases so two peers cannot control one object.
- Fallback order if no peer or relay candidate is reliable: Firebase listeners; a lightweight managed relay behind `RealtimeTransport`; only then a dedicated BGO realtime service. Full-session polling is never kept as the normal mechanism. Polling may remain only inside a transport that inherently needs it (the GitHub Jobs bridge uses a lease plus polling) and stays scoped to it.

### MCP prototype (DEV)

- The developer console and MCP are separate adapters over the same typed logical command API. MCP never evaluates console strings and never accepts Godot nodes, scene paths, Firebase paths or arbitrary method names; transport permission checks never replace domain validation.
- Public vocabulary: `Game.*` (definition data), `Match.*` (current match state and actions) and `System.*` (runtime capabilities and discovery). Entity methods use flat camelCase (`getName`, `isActive`, `moveToPoint`); constants are `System.constants.UPPER_SNAKE_CASE`; the canonical call syntax is Python-like (`Match.piece_1.getOwner()`).
- The server exposes 12 tools. Reads: `bgo_get_context`, `bgo_get_definition`, `bgo_get_state`, `bgo_get_grid_state`, `bgo_inspect_object`, `bgo_objects_at_point`. Discovery and control: `bgo_get_entities` (authorized entity paths and commands), `bgo_get_properties` (values, writable schema, commands), `bgo_set_properties` (only properties declared writable, validated by the component registry) and `bgo_execute` (only commands registered and advertised for that entity). Host-only legacy tools: `bgo_create_object_at_point` and `bgo_move_object_to_point`. Coordinates are logical grid points, never camera or world space.
- Mutations are written as pending commands to the Firebase queue; the open Godot host rebuilds logical state, calls `BgoMcpGameApi` (through `BgoMcpCommandProcessor`), and atomically persists the accepted result. A write returns `timeout` if no host client is open, and the pending command still runs when the host reconnects. One host authority is assumed.
- The remote DEV server is the stateless Streamable HTTP Firebase Function `bgoMcpDev` (`backend/functions/`, server version 0.2.0) at `https://us-central1-board-game-online-68c3f.cloudfunctions.net/bgoMcpDev/mcp`, with a health route at `/health`. Its non-secret DEV binding is `backend/functions/.env.board-game-online-68c3f`.
- Access policy is `dev_direct_no_auth` (`src/mcp/mcp_prototype_access_policy.gd`): anyone holding the endpoint acts as the configured host, with one fixed session and host binding per deployment. It is not production authentication and must never be published as a production connector.
- Game identity and session identity are not fully separated yet: the Firebase path still uses the game ID. The target session pins `session_id`, `game_package_id`, `game_package_version` and `game_package_hash`, so one package can have many sessions.

### GitHub Jobs bridge

`BgoGithubJobsTransport` turns a persisted job (`<match>/github_jobs/<job_id>`, with the lease at `<match>/github_lease`) into the normal command envelope and delegates to `BgoMcpCommandProcessor`; it implements no Game, Match or System semantics of its own. One client holds the lease and processes jobs; the lease renews on each session poll and expires so another client can take over, and the job ID plus its terminal status suppress duplicates. Declarative authoring uses the same path with logical entities such as `Game.table.instances.main_board` and returns a definition patch that the repository projects under the session `definition` node. Godot Web never holds a GitHub token: `BgoGithubJobRelay` is the boundary, and a server-side relay submits work. Every public API call records a structured `PUBLIC_API_INVOCATION` entry through `BgoActivityLog`; the bounded history persists at `activity_log/events/<event_id>` so another client can recover it, while JSONL under `user://logs/bgo-activity.jsonl` is local diagnostics only.

## Web platform

The public web application around the Godot runtime is a separate product surface. It owns what a normal web app does better: landing and explanation, game catalog and discovery, create, join and resume flows, invite links and room codes, device-role selection (player, display, spectator, host where allowed), download links for native clients, documentation and release notes, and later accounts, owned packages, creator publishing and admin tooling. The Godot runtime owns gameplay rendering and interaction and must not become the place for marketing pages or account management.

- **Boundary.** Web and game clients talk through shared backend contracts, never through each other's internals. No web page needs to understand Godot scene nodes, and Godot never needs to understand a commercial provider's UI. The web framework stays replaceable behind stable backend and schema contracts; treat it as a separate application boundary even while it lives in this monorepo. Keep a small design system (typography, spacing, color tokens, buttons and forms, cards, navigation, breakpoints, loading, error and empty states) so continuous visual iteration stays consistent. Gameplay legality never moves into the web frontend.
- **Launcher.** A launch resolves `session_id`, the package ID, version and hash, the identity context (guest for now), the device role, the authorization context once it exists, and the preferred client mode. It routes to the Godot Web player, the Godot Web display, an installed native desktop client, or later an Android or TV client. Deep links and native launch come after the web flow is stable.
- **Catalog.** It describes external GamePackages and never bakes games into the frontend: package ID and version, title, description, author, player count, supported capabilities and components, supported client and graphics profiles, media, locales, manifest URL, size estimates and access requirements if a product model ever adds them.
- **Access policy during the prototype.** Do not block runtime, lobby, package or web-shell testing on registration or login; anonymous test access is intended. There is no checkout, no paid plan, no advertising and no supporter entitlement, and gameplay code makes no assumption about a commercial model. When authentication arrives, the web platform is where accounts are created and managed, Godot clients consume a stable identity or token contract, the domain does not couple to one auth SDK (Firebase Auth may be the first provider), and DEV keeps a low-friction test path. Until then, keep a clean seam for identity without inventing fake profile machinery.
- **Monetization is deferred** until real usage data exists (candidates: donations, supporter membership, freemium, subscriptions, creator fees, ads, package sales). When it comes, model access as backend capabilities (account tier, supporter status, subscription state, feature entitlements, package ownership, session limits) so gameplay asks whether an identity has a permission, never where it came from. Billing secrets, payment verification and webhooks stay server-side, and client-provided commercial state is never trusted.
- **AI-assisted web work** follows the same discipline: read `SKILL.md` first, use backend contracts instead of inventing schemas, keep secrets server-side, add no auth or billing plumbing before its checkpoint, test the important session flows, and update this file when a shared contract changes.

## Environments and deployment

- **DEV** is the actively changing integration build from `develop`; **PROD** is the stable build from `main`. Both stay reachable at different URLs. PROD does not yet imply production-grade auth, billing or support; it means the stable build the owner chooses to expose.
- Flow: feature or fix branch, quality gate, `develop`, automatic DEV deploy, manual validation, **the owner decides to promote**, merge to `main`, quality gate again, PROD deploy. Passing CI never authorizes PROD; CI or an agent may recommend a promotion but must not make that product decision. `develop` must stay runnable even though it changes often.
- **Automatic DEV path** (`.github/workflows/quality-gate.yml`): on push to `develop` it deploys the validated Web export only to the Firebase Hosting preview channel named `dev`, which cannot overwrite the `live` channel, then runs the browser tests again against the deployed URL, and records `e2e_local`, `deploy_dev` and `e2e_dev` in `project-status/ci.json`. It needs the GitHub secret `FIREBASE_DEV_SERVICE_ACCOUNT` (a Hosting-capable service-account JSON, never committed) and the repository variable `FIREBASE_DEV_PROJECT_ID`. The curated quality gate stays the source of truth; do not adopt a second generated deploy workflow.
- **Firebase deploy safety.** The only allowed commands are `firebase deploy --only hosting` and the named DEV MCP exception `firebase deploy --only functions:bgo-mcp-dev:bgoMcpDev --project board-game-online-68c3f`, which touches neither Hosting nor RTDB rules and runs from the `develop` workflow only when the repository variable `BGO_MCP_DEPLOY_ENABLED` is `true`. Never run an unrestricted `firebase deploy` while RTDB rules and other resources are in prototype state. When several projects or targets exist, deploy scripts must name the destination explicitly (`deploy-dev` and `promote-prod` rather than a bare `deploy`) so DEV output cannot reach PROD by accident.
- **Backend isolation.** Everything still runs in the single Firebase project `board-game-online-68c3f`. Two Hosting sites in one project are content separation, not backend isolation, because RTDB, Auth and Storage are shared. The target is separate DEV and PROD Firebase projects; until then any shared state that must be separated uses an explicit environment namespace in the adapter configuration.
- **Configuration.** Environment-specific values (project ID, RTDB URL, hosting base URL, catalog endpoints later, logging and debug flags, feature flags) live in configuration, never scattered through the domain, and gameplay code is never duplicated per environment.
- **Browser E2E.** Playwright (`package.json`, `playwright.config.mjs`, `tests/e2e/`, `scripts/serve_web.mjs`) checks that the status dashboard and test launcher load, that Godot Web creates a canvas, that the browser flight recorder exists, that the public error viewer loads, and that uncaught page errors fail the run. Evidence is kept on purpose: screenshots, videos, traces, JSON results and the HTML report travel in the `bgo-e2e-*` workflow artifact, so a failure explains itself.
- **Project status dashboard.** Source lives in `hosting/project-status/` (`status.json` for checkpoints and blockers, `ci.json` for transient CI results) and is copied into `build/web/project-status/` by the Hosting `predeploy` hook `scripts/sync_project_status.mjs` (or `scripts/sync_project_status.ps1` locally); never author it inside `build/`. CI injects transient results without committing generated state back to Git. Missing data shows as unknown, never as healthy. See `TODO.md` for whether `status.json` stays.

## Development flow

```text
feature branch
	  |
	  v
   develop
	  |
	  v
Firebase DEV + remote E2E

main = PROD only by explicit owner promotion
```

The integration Quality Gate covers protected project policy, structure, GDScript format/lint, Godot import/parse, core tests, validated Web export, browser E2E and DEV deployment checks.

### Clean-checkout bootstrap

A portable checkout contains every referenced addon script/config/scene, runtime asset and native library declared by a tracked `.gdextension`. Root-local Godot executables, logs, `.godot/`, imported cache payloads and build outputs are generated local state and are not repository dependencies. Install Godot separately and expose its absolute executable path as `GODOT_BIN`; a clean clone intentionally does not contain `godot_console.exe`. Tracked `.import` descriptors and `.gd.uid` sidecars never replace the first Godot filesystem scan.

Addon autoloads in `project.godot` must use explicit `*res://...` paths. UID-only addon autoloads can be evaluated before the UID cache exists and resolve to an empty path on the first clean launch. Godot may normalize known paths back to UIDs after import; do not commit that rewrite. `scripts/check_structure.py` rejects UID-only required autoloads and missing GDExtension libraries.

From a new checkout, run:

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.1-stable_win64_console.exe'
& $env:GODOT_BIN --headless --path . --import --log-file clean_import.log
& $env:GODOT_BIN --headless --path . --script res://tests/test_runner.gd --log-file clean_tests.log
python scripts/check_structure.py
```

Success requires process exit code `0` and no `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, `Failed to instantiate` or `Unrecognized UID` entries in the logs. After adding or moving a `class_name`, remove only the checkout's generated `.godot/` cache and repeat the full import.

Use the checked-in export wrapper for Web. It creates the ignored output directories, scans Godot logs, synchronizes `project-status`, and validates the complete export:

```powershell
./scripts/export_web.ps1
```

Godot can return process exit code 0 while its log still contains SCRIPT ERROR: Parse Error: or Failed to load script. Project import/export checks must scan for those signatures instead of trusting only the process code. Execution errors emitted solely by explicitly editor-only add-ons such as asset_placer are classified separately and do not justify widening the Web PCK.

Do not stage incidental `.godot`, `.import` or newly generated `.gd.uid` noise. Generated `build/`, `artifacts/` and `.firebase/` content is not source.

Copilot Cloud project-audit automation is disabled because the project is not using that paid capability. A future local agent may perform repository-wide advisory analysis.

### Agent task handoff and definition of done

A handoff to an agent carries: the branch and commit, the requested change, the active roadmap phase, the files or components expected to change, the tests to add or run, and the constraints from `SKILL.md`. An agent reports: files changed, public contracts added or changed, tests added, schema and migration effects, deferred work and the quality-gate result. A task is done only when it belongs to the active phase (or says why it was pulled forward), crosses no architectural boundary, adds focused tests for public behavior, updates fixture and conformance coverage when a capability changes, updates this README when a public contract changes, fails safely and diagnostically, runs or leaves ready the quality gate, and leaves later-phase work deferred. Schema changes validate versions explicitly, surface exact errors and never silently reinterpret a field; migrate valid prototype sessions when practical. Remote package data is untrusted: never download and execute it.

### Manual verification of the shared board

Roles: `?role=display&game=TEST001` renders synchronized state and cannot manipulate pieces; `?role=player&game=TEST001&player=player_1` (and `player_2`) controls only objects the player owns or currently holds, and neutral objects (empty `owner_id`) can be claimed while unheld. Checklist: run locally first with no GDScript parse errors; Display, Player 1 and Player 2 render the same board; the neutral stack appears after the definition synchronizes; Player 1 cannot pick up Player 2's owned stack; either player can pick up the neutral stack while unheld; PICK UP moves the object into that player's hand; PLACE only resolves to a valid slot and animates and synchronizes on every client; Firebase events and logs record the interaction. The Web export is `build/web/index.html`, and the only allowed deploy command remains `firebase deploy --only hosting`.

## Technology baseline

- Godot `4.7.1-stable`
- Node.js `22` in CI
- Playwright version pinned by `package.json`
- Firebase project `board-game-online-68c3f`
- Firebase Functions source `backend/functions/`
- Static Hosting source `hosting/`
- Web build output `build/web/`
