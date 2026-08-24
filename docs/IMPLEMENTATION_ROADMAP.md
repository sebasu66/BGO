# BGO — Implementation Roadmap & Checkpoints

This document turns the project vision into an incremental implementation plan.

The goal is deliberately **not** to implement every planned feature at once. BGO should advance through small vertical slices, with a working build and explicit validation checkpoint between slices.

## Guiding rule

> A new subsystem is not considered complete because its code exists. It is complete when it has a focused test fixture, automated checks where practical, and the previous capabilities still work.

Each checkpoint must preserve:

- a locally runnable Godot project
- a valid Web export
- the existing shared-session PoC unless the checkpoint explicitly migrates it
- clear separation between domain state, rendering, networking, and game/package data
- compatibility with future external game packages and MCP control
- an up-to-date agent development contract so multiple AI coding systems can contribute consistently

---

## Architecture boundaries to preserve

### BGO Core

Versioned with this repository.

Owns:

- game/session domain model
- commands, validation, permissions, events
- component contracts and registry
- slots, zones, ownership, visibility policies
- render abstractions
- networking/persistence abstractions
- game-package loading
- asset resolution/cache/validation infrastructure
- testing and conformance infrastructure
- MCP-facing logical APIs later

### Core Component Library

Versioned with BGO Core.

Contains reusable implementations such as:

- boards
- slots
- pieces
- cards
- decks
- dice
- counters
- player areas
- hands
- generic zones

A game definition references stable component IDs, never internal scene/script paths.

### Core Conformance Games

Versioned with BGO Core under test fixtures.

These are small games whose purpose is to exercise public component capabilities. They use the same package format as external games and are not special runtime formats.

Examples:

- board/slot basics
- multiplayer ownership
- cards/decks/hands/discard
- dice
- miniatures
- stacks/counters
- hidden information

### External Game Packages / Mods

**Not versioned with the BGO Core repository.**

A real game is an external package containing declarative definitions and optional assets or remote asset references.

The runtime must eventually be able to load a game package from local storage or a remote source without rebuilding BGO.

External packages must not receive arbitrary trusted GDScript execution privileges.

---

# Phase 0 — Stabilize the current PoC

**Purpose:** freeze a known-good baseline before further architectural work.

Current PoC capabilities include the shared 3D table, Firebase synchronization, player/display roles, permanent editor-visible component scenes, piece pickup/place behavior, and the initial component registry/game-definition work.

### Deliverables

- current TEST001 still launches in Godot
- Web export succeeds
- Player 1 and Player 2 can connect
- neutral ownership remains representable independently from holder ownership
- Player Area and Hand remain distinct domain concepts
- board positions resolve through logical slots

### Checkpoint 0

Before moving on:

- run locally with no parse/runtime errors
- export Web successfully
- verify display + P1 + P2 clients against one Firebase session
- verify existing state can survive schema additions without destructive reset

---

# Phase 1 — Quality gate and automated build safety

**Purpose:** make every later refactor safer and make project knowledge portable across human and AI contributors.

This phase should happen early because every later component and package feature benefits from automated regression checks and a shared implementation contract.

### Deliverables

- one-command local quality check
- GitHub Actions CI on push and pull request
- GDScript lint and formatting checks
- Godot headless import/parse validation
- unit-test runner
- Web export smoke test
- project-structure checks
- initial architectural dependency checks
- repository-level `AGENTS.md` with non-negotiable architecture/deployment constraints
- compact AI development skill/document that explains task routing, domain vocabulary, component/package rules, quality expectations, and the active roadmap sequence

The agent contract is intentionally provider-neutral. ChatGPT/Codex, Gemini-based Firebase tooling, or other coding agents should all be able to consume the same repository-grounded instructions rather than depending on one model's conversational memory.

Suggested pipeline:

```text
format check
    ↓
gdlint
    ↓
project structure / architecture checks
    ↓
Godot headless import + script validation
    ↓
unit/domain tests
    ↓
Web export
```

### Automated code-quality targets

Block commits for objective violations where practical:

- malformed project/component structure
- duplicate public component IDs
- invalid game definitions
- forbidden dependency directions
- lint/format failures
- failing tests
- failed Web export

Report, but initially do not necessarily block, heuristic issues such as:

- very large files/functions
- excessive nesting/complexity
- suspicious dead code
- duplicated logic
- vague naming
- excessive side effects in domain code
- architectural smells related to SOLID principles

The design target is not SOLID ceremony. The stronger rule is:

> Domain behavior should be understandable and testable without rendering, UI, or Firebase.

### Checkpoint 1

- CI green from a clean checkout
- the same check command works locally
- an intentional syntax/test failure makes CI fail
- a valid Web export is produced headlessly
- a fresh AI coding agent can read `AGENTS.md` + the AI skill and identify the current phase, forbidden shortcuts, required tests, and deploy constraints without relying on prior chat context

---

# Phase 2 — Core logical model: slots, zones, ownership, commands

**Purpose:** remove remaining PoC coupling between board coordinates, scene nodes, and game rules.

### Deliverables

Formalize:

- `ObjectId`
- `ComponentId`
- `SlotId`
- `ZoneId`
- owner vs holder/controller
- neutral/public ownership
- `Hand`
- `PlayerArea`
- generic public/private zones
- slot occupancy/capacity rules
- point-grid origins and rectangular footprints for placeable objects
- command validation
- high-level events

Board cells should be generated as logical slots. Player areas should expose slots. Free-form positioning can be introduced later as an explicit capability rather than the default representation.

For table surfaces that need inventory-style placement, `TabletopState.grid`
provides a second logical representation: finite points with centimetre
spacing, one origin per placeable object, and a rectangular footprint. This is
still domain state, not a renderer coordinate system. The installed Asset
Placer editor plugin may snap authored 3D nodes to a `BgoTableGrid`, but it only
adds editor metadata; occupancy and range queries remain validated by the
logical tabletop.

The tabletop also exposes an `AssetBoxState` reserve/catalog container. It has
no physical grid or tabletop transform: Asset Placer's editor palette is its
authoring representation, while runtime renders it as a viewport-attached
drawer. Safe runtime commands move logical components between the catalog,
hands, player areas and free tabletop grid points.

Move toward pure/domain-oriented operations such as:

```text
State + Command → New State + Events
```

Rendering and Firebase should consume results rather than determine whether an action is legal.

### Initial commands

- pickup/acquire
- place/move to slot
- transfer/give
- release neutral object

### Checkpoint 2

Automated tests cover at least:

- P1 can manipulate P1 object
- P2 cannot manipulate P1 object without permission
- either player can acquire a free neutral object when allowed
- an occupied or invalid slot can reject placement
- Hand and PlayerArea transitions remain distinguishable
- two logical clients converge on the same resulting state

Manual fixture test still works through Web/Firebase.

---

# Phase 3 — External GamePackage foundation

**Purpose:** separate BGO from games made with BGO.

TEST001 becomes a **core fixture using the real package contract**, not evidence that game files belong inside the product runtime.

### Deliverables

Introduce concepts such as:

- `GamePackage`
- `GamePackageManifest`
- package ID
- package version
- schema version
- game-definition hash
- declared component dependencies
- locale references
- asset manifest

External packages should eventually support loading from:

- local package/directory
- remote manifest URL

The game session should pin an exact package identity/version/hash so all clients use compatible definitions.

### Package security rule

External packages are treated as untrusted/declarative content.

Do not load arbitrary remote GDScript as part of opening a game.

### Checkpoint 3

- TEST001 can be loaded through the GamePackage API
- a copied fixture can be loaded from outside the core game-fixture directory
- invalid/missing package metadata produces precise non-crashing errors
- game definitions never reference internal BGO `.tscn` or `.gd` paths
- session metadata records package ID/version/hash

---

# Phase 4 — Conformance-game suite

**Purpose:** grow component support through small, understandable games instead of one giant test game.

Create one or more focused fixtures per component family.

## Fixture: board / slots / ownership

Exercises:

- board generation
- slots
- occupancy/capacity
- player areas
- Hand vs PlayerArea
- P1/P2 ownership
- neutral pieces
- transfer

## Fixture: cards

Exercises all relevant public card/deck capabilities, including:

- card faces/backs
- deck creation
- shuffle
- draw one
- draw N
- Hand
- discard pile
- return cards to deck
- empty-deck behavior
- optional discard reshuffle
- private/public visibility

## Fixture: dice

Exercises:

- die definitions
- roll
- multiple dice
- deterministic seeded results for automated tests
- replication of logical result
- visual animation independent from logical randomness

## Fixture: miniatures

Exercises:

- spawn
- selection
- slot movement
- rotation
- ownership/neutral ownership
- transfer
- representation changes later

## Later fixtures

- stacks/counters
- hidden-information/masking
- markets/bags/random draws
- timers/turn systems if required

### Component coverage rule

Every public BGO component should eventually have:

1. focused unit/domain tests; and
2. at least one conformance game exercising its meaningful public capabilities.

CI may later fail when a new public component lacks conformance coverage.

### Checkpoint 4

- fixtures share the exact GamePackage format used by external mods
- each implemented public component has explicit coverage
- fixtures remain small enough to diagnose independently

---

# Phase 5 — AssetResolver and remote asset streaming

**Purpose:** let external games reference graphical/audio assets without bundling them into the BGO executable.

### Deliverables

Introduce:

- logical asset IDs
- `AssetResolver`
- asynchronous downloader
- `AssetCache`
- integrity/hash verification
- placeholders/failure states
- persistent vs session cache policy
- optional mirror/source lists
- on-demand loading priorities

Game definitions should normally reference logical asset IDs, not scatter URLs throughout object definitions.

Conceptual flow:

```text
Game object
   ↓
logical asset ID
   ↓
AssetResolver
   ↓
local cache OR remote source
   ↓
verify
   ↓
load representation
```

### Initial scope

Start with one or two safe Web-compatible asset types, likely textures and GLB/GLTF models. Audio and more formats can follow.

### Checkpoint 5

- fixture package can load at least one asset from a remote URL
- cold-cache and warm-cache behavior both work
- failed download/hash mismatch does not crash the table
- unloaded assets show a placeholder
- assets are loaded on demand rather than requiring the complete package payload at session join

---

# Phase 6 — Asset validation and platform budgets

**Purpose:** prevent external content from destroying performance.

### Deliverables

Add an `AssetValidator` / package validation stage that can inspect relevant asset characteristics.

For 3D content, evaluate where available:

- triangle/vertex count
- mesh count
- material count
- texture count and dimensions
- estimated texture/memory cost
- model/file size
- bones/animations/blend shapes
- physical dimensions/bounds
- required UV/normal data for supported rendering paths

Use **profile-specific budgets**, not one universal hard limit.

Example conceptual profiles:

- desktop high
- desktop standard
- web 3D
- web light
- mobile
- TV top-down

An asset may be valid for desktop and invalid for Web, provided the package supplies a compatible fallback representation.

Validation result levels:

- PASS
- WARNING
- REJECT for a specific profile

### Checkpoint 6

- intentionally oversized fixture assets are flagged predictably
- validation identifies which profiles remain supported
- a package lacking any viable representation for the active profile fails gracefully before gameplay

---

# Phase 7 — Multiple visual representations per logical object

**Purpose:** let the same Firebase/session object appear differently on different hardware without fragmenting game state.

Core principle:

> BGO synchronizes logical game objects, not graphics.

Possible representations:

- high-detail 3D mesh
- low-detail 3D mesh
- 8-direction billboard
- 4-direction billboard
- top-down sprite
- icon/thumbnail

A local `RepresentationSelector` chooses the best supported representation based on client graphics profile and context.

### Client examples

- native PC: Forward+ / richer mesh representation
- Web: low mesh or billboard
- mobile: billboard/light representation
- TV top-down: sprite/map representation

The logical object ID, slot, ownership, quantity, rotation, commands, and events remain identical.

### Checkpoint 7

Using the miniature fixture:

- the same session can be opened simultaneously by clients using different representation profiles
- state changes are identical regardless of representation
- switching representation does not alter logical state

---

# Phase 8 — Dedicated top-down/table-map renderer

**Purpose:** provide a clear, lightweight shared-TV/table mode rather than merely placing a perspective camera overhead.

### Deliverables

- orthographic/top-down board renderer
- component-specific top-down representations
- quantity/stack indicators
- simplified selection/change highlighting
- efficient rendering for large object counts

This can become a strong option for TV display clients and low-power hardware.

### Checkpoint 8

- board fixture and miniature fixture are fully playable/observable in top-down mode
- top-down client can coexist with a 3D PC client in the same session

---

# Phase 9 — Asset authoring pipeline / photobooth

**Purpose:** help creators turn rich source assets into efficient runtime representations.

This is intentionally later than streaming, validation, and representation selection.

Potential tools:

- automatic thumbnails
- top-down renders
- 4/8-direction transparent billboard capture
- optional mesh simplification workflow
- metadata generation
- representation manifest generation

A creator may provide one detailed model and generate:

```text
source high-detail model
        ↓
low-detail mesh
billboard 8
billboard 4
top-down sprite
icon
```

Generated assets should still pass the same validator as manually authored assets.

### Checkpoint 9

- one miniature source asset can produce usable generated representations
- generated output is referenced through the normal package/asset system
- mobile/Web fixture can run without loading the source high-detail model

---

# Phase 10 — MCP logical control MVP

**Purpose:** allow an MCP-capable external AI/client to inspect and manipulate the game through safe logical operations.

An owner-requested DEV vertical slice started early in August 2026 without
changing the main implementation sequence. It provides a Streamable HTTP
Firebase Function, logical entity/property discovery, validated property writes,
and queued registered host commands validated by the Godot domain adapter. The
legacy create/move tools remain compatibility aliases. This is not Checkpoint 10 completion:
authentication, revision conflicts, complete visibility filtering, the wider
command catalog, and conformance parity remain open. See `docs/MCP_PROTOTYPE.md`.

Do not expose raw Godot scene nodes.

Expose concepts such as:

- sessions
- players
- objects/components
- zones/slots
- legal actions
- ownership/visibility as authorized
- commands
- event history

The MCP layer must call the same domain command validation used by human clients.

### Conformance tests

Reuse fixture games to test natural high-level operations such as:

- cards: draw three cards, discard one, shuffle
- miniatures: move a neutral piece to a named slot
- dice: roll 2d6

### Checkpoint 10

- MCP can describe fixture state without reading render nodes
- MCP-issued legal commands produce the same events as UI commands
- illegal commands are rejected through the same validation path

---

# Later / explicitly deferred

These are valid product directions but should not distract the current implementation sequence:

- dynamic automatic graphics downgrade based on measured FPS
- sophisticated normal/depth billboard relighting
- VR presence
- rich remote avatars/hands
- rollback/prediction networking
- real-time physics synchronization
- arbitrary mod scripting
- production marketplace/discovery/payment infrastructure
- advanced cinematics/photo-mode integration
- final visual-art direction and environment polish

---

# Immediate implementation order

The near-term sequence is intentionally short:

```text
0. Verify current componentized TEST001
        ↓
1. CI + lint + test + headless Web export + agent development contract
        ↓
2. Finish logical slots/zones/ownership/transfer model
        ↓
3. Formalize external GamePackage contract
        ↓
4. Split TEST001 into focused conformance fixtures as components grow
        ↓
5. Asset streaming
```

Do not start graphics profiles, billboard generation, top-down rendering, or photobooth generation until the package and asset-resolution boundaries are stable.

This ordering keeps the project testable while ensuring later visual optimization is built on a clean logical/runtime architecture rather than patched into a monolithic PoC.
