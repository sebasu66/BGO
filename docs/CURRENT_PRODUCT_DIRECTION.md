# BGO — Current Product Direction

This document captures current product/architecture decisions that are useful to preserve even when they are not immediate implementation work.

## Prototype contract policy

BGO is currently an unpublished prototype. It carries no backward-compatibility obligation.

- The repository contains one canonical game schema and one canonical runtime path.
- When a better core contract replaces an earlier prototype, the earlier implementation is deleted rather than retained as an alias, migration or compatibility layer.
- Git is the complete history of discarded approaches.
- Version negotiation and migrations are introduced only after a contract is deliberately published as stable and external games actually depend on it.
- Tests and fixtures are updated to the current contract instead of testing obsolete behavior.

This keeps failures local and visible and prevents old prototype assumptions from becoming accidental public APIs.

## Canonical core protocol

All authoritative game mutations enter through one command envelope with a stable dotted verb, actor, optional target, arguments and optional expected revision. Components declare supported verbs in their own `component.jsonh` contracts. The registry discovers those contracts; adding a component must not require editing a central component switch.

Commands use imperative names such as `object.move`, `object.set_quantity`, `turn.end` and `match.finish`. Resulting facts use past-tense event names such as `object.moved`, `object.quantity_changed`, `turn.ended` and `match.finished`.

Session lifecycle and gameplay flow are separate domain concepts:

- `SessionState`: participants, seats, host, lobby/active/ended lifecycle and result.
- `FlowState`: phase, turn order, turn number and active participants.
- `GameplayState`: objects, tabletop, command execution, revision and event history.

`turn.end` is always explicit in the current core. Moving or otherwise manipulating an object never ends the turn implicitly.

`LogicalObjectState` is the authoritative object truth and contains component identity, owner, holder, logical location, visibility, quantity, semantic state and extensible serializable properties. Godot nodes are views and interaction surfaces; they do not serialize a second competing logical state.

Declarative listeners consume canonical events and issue normal commands back through the same command path. They never mutate domain state directly. Listener chains are ordered, bounded and included in the same recorded command result.

## Near-term product goal

The next playable vertical slice should support a complete abstract board game in the chess/checkers family:

- a real session with assigned participants/seats
- game start and finish
- turn number and active player
- END TURN / next-turn flow
- winner/loser/result state
- a board plus individually meaningful movable pieces/miniatures
- deterministic legal placement/occupancy at the core level
- game-specific movement validation may remain package/rule specific

The goal is not to support every board-game mechanic up front. Core capabilities and validators should grow from concrete supported games.

## Continuous tabletop model

The tabletop is a first-class logical/presentation concept rather than a collection of disconnected UI screens.

A game defines one continuous table plane containing named sections. Sections are modular footprints on that plane and may initially be rectangular or circular.

Typical sections include:

- main board area
- auxiliary boards/tracks
- dice/roller areas
- shared reserves/markets
- player areas/tableaux

Each section may declare:

- identity and label
- footprint/shape and transform on the table plane
- public/private/hidden visibility policy
- owner/seat association where relevant
- allowed child zones/slots
- camera preset/focus target
- interaction/capability restrictions

Players can pan naturally across the continuous table. Camera presets are shortcuts to meaningful table regions, not separate copies of state or separate game screens.

## Hand is not physical tabletop space

Hand remains a semantic/private collection and is rendered as a viewport-attached overlay.

Default player presentation direction:

- collapsed bottom handle/icon with item count
- expandable horizontal hand drawer
- focused center item enlarged relative to neighbors
- optional multi-selection
- PLACE can operate on the explicit selection or focused item

Hand does not consume a physical location on the table plane.

## Sections, zones, and slots

A table section may contain declarative child zones and slots.

Slots/zones may describe:

- capacity
- accepted component/capability classes
- ownership/visibility policy
- orientation/layout
- legal drop behavior
- fixed/static placement rules

Logical occupancy remains authoritative. Physics may assist visuals/picking but is not the source of placement legality.

A future visual authoring tool should edit these same declarations rather than inventing a second runtime format.

## Session-first runtime

Interactive gameplay should never mean entering an unbound table with no game/session context.

Normal flow:

1. select/create/join a game session in the lobby
2. resolve participant and seat/role
3. load the pinned GamePackage/version/hash
4. enter the active session state

If a player URL is opened without a valid participant/seat, the client should route to lobby/seat selection when permitted. Spectator/display/editor modes are explicit modes, not accidental fallbacks.

A session eventually owns lifecycle, participants, turns, event history and result state. Sessions remain persistable so synchronous and asynchronous play can use the same domain model.

## Host and permissions

A session may designate a host with elevated session-management permissions. Host privileges should be explicit commands/capabilities and auditable.

Normal gameplay must remain distinct from authoring/edit mode. Runtime table structure should not become accidentally editable through generic object gestures.

## Components expose only relevant capabilities

BGO should avoid the Tabletop Simulator pattern where every object exposes a huge generic action menu.

A component declares the capabilities/actions that make sense for that component and game configuration. The UI surfaces only those legal/relevant actions.

Examples:

- static scenery: non-movable/non-selectable during normal play
- miniature: select/move/rotate when allowed
- deck: draw, draw N, deal, shuffle, inspect/count when allowed
- stack: add/remove/split/manipulate as a quantity-bearing aggregate

Runtime creation is explicit. A graphical scene is not automatically `spawnable`: the capability means the active session may create new authoritative instances of that component through `object.spawn`. `despawnable`, `lockable` and `transferable` similarly opt into recorded removal/return-to-box, interaction locking and owner/holder transfer commands.

Locked objects are excluded from ordinary selection, ray picking and pickup. A long press may request an unlock, but the normal command validator still decides whether the actor is authorized. Physics and presentation never bypass logical locking.

This both simplifies UX and helps enforce rules.

## Contextual object interaction

Objects with multiple meaningful actions should support a runtime-owned contextual action presentation.

Presentation direction:

- focus/highlight the active object
- dim/de-emphasize other table content
- temporarily suppress accidental interaction with background objects
- show only validated actions for the selected component/state/player

The visual effect may later use depth/blur/post-processing, but interaction safety is the primary requirement.

## Physical objects, aggregates, and counters

Do not assume every logical quantity requires one rendered physical object per unit.

Useful representation classes include:

### Individual object / miniature

Represents one meaningful unit with its own state. Chess pieces fit this model better than generic quantity tokens.

### Stack / aggregate

One logical/render object can represent N equivalent pieces. It may visually appear as a stack or group and supports quantity changes/splitting when the game allows it.

### Formation / squad

A logical group can render as 1, 2, 5, 10, etc. representative miniatures while carrying the real logical quantity separately. This reduces interaction/render overhead for unit-heavy games.

### Virtual resource/counter

Quantities such as gold, food, fame or resources need not always exist as physical loose tokens. They may be represented as icon + number in UI or as a compact counter object in a player area when physical table presence is useful.

Logical state and visual representation remain separate so the same quantity can have different appropriate render modes.

## Capability compatibility and validation

Components should progressively declare what they provide, require and permit so package validation can derive useful compatibility information.

The validator should eventually produce both:

- errors/warnings for contradictory or impossible combinations
- a derived capability report describing what the configured game permits

Example conclusions for a chess-like fixture may include:

- board slots capacity = 1
- stacking disabled
- object spawning during normal play disabled
- piece movement limited to board slots
- no hand/deck capability required

Do not attempt to model every possible board game in advance. Extend capabilities and validation when real supported fixtures require them.

## Camera and visual direction

Player camera should feel closer to a seated human tabletop view than a near-vertical technical camera.

Near-term tuning direction:

- slightly greater camera distance/height so tall components do not crowd the lens
- less top-down pitch
- somewhat wider natural FOV
- preserve one-finger pan, two-finger rotate, pinch zoom and reset/preset navigation
- allow seeing remote player-presence markers at the opposite side of the table where practical

Future inspect mode:

- select/tap an object while INSPECT mode is active
- show an enlarged presentation-oriented view without moving the physical object
- useful for cards, text-heavy pieces and inspecting remote presence/objects
- may include declarative object properties/details

## Player presence and asynchronous sessions

Player presence is ephemeral and separate from durable game state.

A presence marker may be positioned/oriented from the player's current camera so other connected players can understand where that participant is looking.

A player disconnecting must not destroy the session. Durable state should allow everyone to leave and return later, enabling asynchronous turn-based play as well as synchronous sessions.

## Agent-readable Web and discovery graph

BGO should be human-readable, machine-readable and agent-operable from the same logical model.

The Godot Web canvas remains the primary human renderer, but a Web page containing a running game should also expose a lightweight semantic representation that agents, browser automation and accessibility tooling can inspect without having to infer game state from pixels.

The page itself does not need to embed every related piece of knowledge. Instead, it should participate in a discoverable graph of linked resources.

A running session page may expose or reference resources such as:

- current authorized semantic session state
- viewer/role/seat identity
- visible table sections and objects
- legal/relevant actions for the current viewer
- UI/control semantics useful for automation/debugging
- GamePackage identity/version/hash
- structured game rules
- human-readable manual
- agent integration documentation
- capability descriptors
- MCP endpoint/configuration later
- authoring documentation later

These resources may be linked through standard HTML metadata/links where possible and BGO-specific descriptors where needed. They do not need to be visible in the rendered player UI.

Conceptually:

```text
/session/ABC123
    ├── human Godot canvas/UI
    ├── semantic/discovery metadata
    ├── state resource
    ├── rules resource
    ├── manual resource
    ├── capabilities resource
    └── agent integration resource
```

The live state resource should stay compact and reference versioned/static knowledge rather than repeating full manuals or complete rules on every update.

For example, a state snapshot may include package/rules references plus only the current dynamic state and legal actions.

### Privacy boundary

Agent-readable state must pass through the same visibility/authorization policy as human rendering. A player-facing page must never expose another player's private hand or hidden information merely because it is present in HTML, JavaScript state or a semantic endpoint.

Spectator, display, player, host and future agent clients may therefore receive different filtered semantic views of the same underlying session.

### Semantic UI shadow

Because Godot UI renders inside a canvas, DOM inspection alone cannot describe every interactive control. BGO may maintain a compact semantic shadow of important runtime controls, for example:

- control ID/label
- enabled/disabled state
- purpose/action
- approximate screen rectangle when useful for browser-driving agents
- selected/focused object
- active interaction mode

This is intended for diagnostics, E2E automation and agent interoperability, not as an alternate source of game truth.

### Public discovery

Public landing, catalog, game information and agent documentation should use normal indexable HTML and structured metadata so search engines and AI systems can discover what BGO is, which games/capabilities it supports, and how integrations work.

A future well-known descriptor may advertise agent capabilities and stable documentation/integration endpoints without requiring an agent to reverse-engineer the application.

## MCP / AI direction

MCP should operate on logical session/game concepts, not render nodes.

Future capabilities should include:

- tell a player that another participant moved and that it is now their turn
- summarize changes since the player's previous turn
- list legal/relevant actions
- inspect visible game state
- issue validated commands through the same command layer as human UI
- optionally control an AI participant/seat

An AI participant should use the same permissions, visibility and command validation as a human participant.

The Web semantic interface and MCP should not define competing game models. They should be separate projections/interfaces over the same domain state and command validation layer.

## AI-assisted authoring direction

Longer term, an agent should be able to help create a game through the declarative GamePackage model rather than arbitrary trusted code generation.

Target flow:

```text
natural-language game intent
    ↓
GamePackage draft
    ↓
schema/capability validation
    ↓
preview / conformance checks
    ↓
publish
```

The public Web/agent documentation should eventually make authoring capabilities discoverable so an external assistant can understand how to create, validate and publish compatible game packages.

## Visual environment direction

The default scene should move away from a black void toward an effectively horizonless warm tabletop/studio presentation:

- light cream/ivory background/table plane
- very subtle grain/texture
- warm ivory ambient/key light
- multiple soft light sources, conceptually around four directions/corners
- detailed but soft shadows where the active graphics profile supports them
- cozy studio/tabletop appearance without a visible horizon seam

Performance profiles may reduce shadow/light complexity on Web/mobile while preserving the art direction.

## Automation direction

Manual local export/deploy should become optional rather than a required step for every iteration.

Target workflow:

1. commit/push
2. GitHub Actions quality gate installs pinned Godot + Web templates
3. headless import/tests/validated Web export
4. update generated project-status/CI metadata
5. only after green validation, deploy the DEV Hosting target automatically
6. run deployed-site smoke/E2E checks
7. retain screenshots, browser traces, console/network failures and semantic-state evidence on failures
8. surface deployment/diagnostic status in the project dashboard

PROD promotion remains an explicit owner decision and must never be triggered automatically by ordinary development commits.

The next infrastructure checkpoint is therefore automatic DEV deployment after the existing validated GitHub Actions Web export, with explicit environment targeting and no unrestricted Firebase deploy.

## Implementation staging for agent-readable Web

### Can start now

- reserve a stable BGO semantic snapshot contract in the runtime
- expose a small JavaScript bridge/read-only state object from Godot Web
- include viewer/session/package identity and filtered visible-object state
- expose current UI mode/selection and a minimal control descriptor for automated tests
- add links/metadata from the Web shell to public agent/project documentation
- make Playwright/E2E tests consume semantic state in addition to screenshots

### Shortly after SessionState exists

- expose lifecycle, turn, active player, result and event-summary state
- expose legal actions from the same command validator used by the human UI
- add spectator-specific semantic state
- expose versioned rules/package references rather than embedding full rules repeatedly

### Later

- well-known agent capability descriptor
- stable public rules/manual/capability resource graph per GamePackage
- MCP projection using the same state/command layer
- AI participant seats
- AI-assisted GamePackage authoring/validation/publishing
- richer semantic control geometry and browser-agent interoperability where it provides real value
