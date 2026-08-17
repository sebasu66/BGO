# BGO AI Development Skill

This document is a compact project-specific implementation skill for AI development systems (ChatGPT/Codex, Gemini-based tooling, Claude-based tooling, or other coding agents).

The goal is to let an agent contribute safely without rereading the entire project history on every task.

`AGENTS.md` is the short mandatory contract. This file adds implementation heuristics and task-routing guidance.

---

## 1. Mental model

BGO is a **runtime/platform**, not a collection of hard-coded games.

Think in four layers:

```text
Logical game/session domain
        ↓
Reusable component contracts
        ↓
External declarative GamePackage/mod
        ↓
Client-specific rendering + transport adapters
```

The same logical session may be rendered as high-detail native 3D, low-detail Web 3D, billboards, or top-down sprites without changing game state.

---

## 2. Source-of-truth documents

Read in this order, and only as deeply as the task requires:

1. `AGENTS.md` — operational constraints; always read first.
2. `docs/IMPLEMENTATION_ROADMAP.md` — current phase and checkpoint sequencing.
3. Relevant component/domain files and tests.
4. `docs/PROJECT_VISION.md` — deeper rationale when a design question is not resolved above.
5. `docs/POC_TEST001.md` — current PoC/manual verification behavior.
6. `docs/ADDON_EVALUATION.md` — prior addon decisions.

Do not treat conversation history as the only source of truth when repository docs have been updated.

---

## 3. Task classification

Before coding, classify the requested change.

### Domain change

Examples: ownership, slots, zones, commands, transfers, card draw, dice result.

Rules:

- implement outside rendering where possible;
- favor deterministic/pure operations;
- produce validated commands/events;
- add unit/domain tests;
- renderer and Firebase should consume the result.

### Component change

Examples: deck, die, card, miniature, counter.

Rules:

- give it a stable component ID;
- keep internals inside the component module/folder;
- define/validate public config;
- avoid teaching central core code about every concrete type;
- add tests and conformance coverage.

### Game/mod change

Rules:

- game files are declarative;
- reference component IDs, not implementation paths;
- do not embed arbitrary executable GDScript;
- use the same GamePackage contract as core fixtures.

### Rendering change

Rules:

- do not mutate domain semantics to satisfy a visual shortcut;
- visual representation is replaceable/client-local;
- keep logical state stable across 3D/billboard/top-down modes.

### Networking/Firebase change

Rules:

- hide provider-specific behavior behind repository/transport abstractions;
- Firebase is persistence/coordination, not the game-rule engine;
- do not deploy database rules during the current Test Mode prototype unless explicitly requested;
- Hosting deployment command remains `firebase deploy --only hosting`.

### Asset pipeline change

Rules:

- game objects reference logical asset IDs;
- resolver decides local/remote source;
- downloads must eventually support cache/integrity/failure states;
- asset complexity must be validated against client profiles;
- do not prematurely build the full photobooth/LOD system before earlier roadmap phases are stable.

---

## 4. Core domain vocabulary

Do not conflate these concepts:

### Object

Logical game entity with an object ID and component ID.

### Owner

Player/entity to whom an object belongs. Empty/no owner can represent neutral/public ownership.

### Holder/controller

Who currently controls/holds the object. This is not necessarily the owner.

### Location

Logical location of the object.

Preferred location vocabulary includes slots/zones rather than arbitrary world-space coordinates.

### Slot

Addressable legal placement target such as `board:3:2` or a player-area slot.

Slots can later define capacity, allowed component types, stacking rules, etc.

### Zone

Logical grouping/location such as deck, discard, hand, player area, market, bag.

### Hand

Private/semi-private board-game hand semantics. Do NOT use as a synonym for PlayerArea or generic possession.

### PlayerArea

Physical/logical tabletop area belonging to a player. May contain public or hidden objects and slots.

### Visibility policy

Independent from ownership/location. Examples: public; owner-face/others-back; owner-only; masked.

---

## 5. Preferred command architecture

Move toward deterministic commands:

```text
Input:
  GameState
  Command

Validation:
  permissions
  ownership/holder
  source/destination
  slot/zone rules
  component-specific rules

Output:
  New GameState
  Events[]
  or precise rejection
```

Examples:

```text
MoveObject
AcquireNeutralObject
TransferObject
DrawCards
ShuffleDeck
DiscardCard
RollDice
```

UI, MCP, and remote clients should ultimately call the same command layer.

---

## 6. Conformance-game rule

Do not put every behavior into one mega fixture.

Create focused fixture packages using the real package contract:

```text
board/slots/ownership
cards/decks/hands/discard
dice
miniatures
stacks/counters
hidden information
```

A fixture should exercise the meaningful public surface of the component family it validates.

Examples for cards:

- create/populate deck
- shuffle
- draw one / N
- hand privacy
- discard
- return/reshuffle
- empty-deck behavior

Examples for dice:

- deterministic seeded logical result for tests
- multiple dice
- replication
- visual animation independent from logical result

---

## 7. Quality heuristics

Automate objective constraints where possible.

Potential blocking checks:

- lint/format
- syntax/import errors
- invalid project/component structure
- duplicate stable IDs
- invalid package/schema references
- forbidden dependencies
- test failures
- Web export failure

Potential warning-level checks initially:

- very large functions/files
- excessive nesting/cyclomatic complexity
- suspicious duplicate logic
- unused private code/resources
- vague names
- too many responsibilities
- hidden side effects
- repeated type switches that should be registry-based

Do not mechanically maximize SOLID patterns. Prefer fewer clear abstractions over unnecessary interface layers.

---

## 8. Safe schema evolution

BGO is expected to evolve while prototype Firebase sessions already exist.

When adding fields:

- provide defaults/normalization when practical;
- migrate or augment existing state without resetting valid player progress;
- validate schema versions explicitly;
- surface exact errors;
- keep migration logic testable;
- never silently reinterpret a field with incompatible semantics.

---

## 9. External package and asset security

Treat remote package data as untrusted.

Never implement a package format that effectively means:

```text
download remote .gd -> load -> execute
```

Remote assets/definitions must be data interpreted by trusted BGO code.

Future rules/DSL capabilities must be explicitly sandboxed/validated.

---

## 10. Graphics profiles

Planned profiles may include native desktop, Web 3D, Web light/mobile, and top-down/TV modes.

Do not store the selected renderer representation as authoritative session state unless it is genuinely game semantics.

A logical miniature can locally resolve to:

```text
mesh_high
mesh_low
billboard_8
billboard_4
top_down
icon
```

A mod may provide multiple representations. Later asset validation determines which client profiles each representation can support.

---

## 11. AI-assisted development

Multiple AI systems may contribute to BGO. Do not assume one model is the sole developer.

Any AI coding integration should be grounded in the repository contract rather than private conversational memory.

Recommended handoff payload for an agent task:

```text
- current branch/commit
- requested change
- active roadmap phase/checkpoint
- files/components expected to change
- tests that must be added/run
- known constraints from AGENTS.md
```

An agent should report:

```text
- files changed
- public contracts added/changed
- tests added
- migrations/schema effects
- deferred work
- quality-gate result
```

This makes ChatGPT/Codex, Gemini-based Firebase tooling, or other agents interchangeable contributors instead of isolated sources of project knowledge.

---

## 12. Definition of done for an agent task

A task is not done merely when code was generated.

Before declaring completion:

1. Confirm the change belongs to the active roadmap phase or explicitly document why it is pulled forward.
2. Ensure no architectural boundary from `AGENTS.md` was violated.
3. Add/update focused automated tests for public behavior.
4. Update fixture/conformance coverage when a component capability changes.
5. Update package/schema docs when public data contracts change.
6. Preserve backward compatibility or provide an explicit migration.
7. Ensure errors fail safely and diagnostically.
8. Run/leave ready the repository quality gate.
9. Keep later-phase work deferred rather than opportunistically implementing it.

---

## 13. Current priority

At the time this skill was introduced, the project should prioritize:

```text
current PoC validation
    ↓
automated quality gate / CI / lint / tests / headless Web export
    ↓
logical slots/zones/ownership/command layer
    ↓
external GamePackage contract
```

Agents should avoid starting remote asset streaming, multi-representation graphics, photobooth tooling, or MCP implementation until the required earlier checkpoint is stable, unless the roadmap is explicitly revised.
