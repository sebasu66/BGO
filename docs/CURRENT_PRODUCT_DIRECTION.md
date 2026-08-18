# BGO — Current Product Direction

This document captures current product/architecture decisions that are useful to preserve even when they are not immediate implementation work.

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
6. surface deployment/diagnostic status in the project dashboard

PROD promotion remains an explicit owner decision and must never be triggered automatically by ordinary development commits.

The next infrastructure checkpoint is therefore automatic DEV deployment after the existing validated GitHub Actions Web export, with explicit environment targeting and no unrestricted Firebase deploy.
