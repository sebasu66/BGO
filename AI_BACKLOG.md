# BGO AI Backlog

Before starting any task, read the complete current `SKILL.md`.

Implement every task in compliance with `SKILL.md` and leave the branch passing the required project checks.

## BGO-001 — SessionState domain foundation

**Status:** IMPLEMENTED

Introduce the first logical `SessionState` foundation described by the current project direction.

Acceptance criteria:

- session lifecycle state is explicit;
- participants and seat assignments are represented logically;
- host identity/capability state is explicit;
- active player and turn number are represented;
- game result/winner state can be represented without requiring UI or Firebase;
- the model can be created and exercised independently of rendering and networking;
- focused automated tests cover the new public behavior;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.

## BGO-002 — Session turn progression

**Status:** IMPLEMENTED

Add logical turn progression on top of the `SessionState` foundation.

Acceptance criteria:

- an active session can advance from the current player to the next valid player;
- turn number advances deterministically;
- invalid turn-advance requests are rejected without mutating state;
- the resulting state transition is testable without rendering or Firebase;
- focused automated tests cover valid and invalid transitions;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.

## BGO-003 — Session completion and result

**Status:** IMPLEMENTED

Complete the logical session lifecycle with explicit game completion and result state.

Acceptance criteria:

- an active session can transition to an ended state;
- result and winner information are represented explicitly;
- ended sessions reject gameplay transitions that are no longer valid;
- focused automated tests cover completion and post-completion rejection behavior;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.

## BGO-004 — Table sections, zones, and slot capacity

**Status:** IMPLEMENTED

Formalize the next logical tabletop slice after the session lifecycle is stable.

Acceptance criteria:

- named tabletop sections are represented logically;
- zones and slots can belong to the appropriate logical section;
- slot occupancy and capacity can be validated without rendering or physics;
- invalid occupancy changes are rejected without corrupting state;
- focused automated tests cover valid and invalid occupancy behavior;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.

## BGO-005 — Logical object state

**Status:** IMPLEMENTED

Introduce a rendering-independent logical object model for tabletop gameplay.

Acceptance criteria:

- objects have stable identity;
- owner and holder/controller are represented separately;
- neutral ownership is representable;
- logical location is represented independently of rendering coordinates;
- object visibility metadata can be represented without exposing private state;
- focused automated tests cover ownership, holder and location behavior.

Implement this task according to the current `SKILL.md`.

## BGO-006 — Validated move command

**Status:** IMPLEMENTED

Add a domain command that moves a logical object between valid tabletop slots.

Acceptance criteria:

- only an authorized active participant can move a controlled object;
- neutral objects can be acquired when the command explicitly permits it;
- invalid ownership, turn or destination conditions reject without mutating state;
- successful movement updates logical location and tabletop occupancy consistently;
- focused automated tests cover valid and rejected commands.

Implement this task according to the current `SKILL.md`.

## BGO-007 — Complete turn command flow

**Status:** IMPLEMENTED

Combine one validated gameplay action with deterministic turn progression.

Acceptance criteria:

- a valid move can complete the current player's turn;
- rejected moves do not advance the turn;
- successful turns produce a stable logical result suitable for persistence/network adapters;
- two logical clients applying the same accepted command sequence converge on the same state;
- focused automated tests cover multi-turn convergence.

Implement this task according to the current `SKILL.md`.

## BGO-008 — First complete conformance game

**Status:** IMPLEMENTED

Create a small declarative turn-based conformance fixture that can be played from setup to explicit winner using the public logical contracts.

Acceptance criteria:

- the fixture uses declarative game data rather than executable game-package scripts;
- two players can complete a deterministic legal game sequence;
- invalid moves are rejected through the same public validation path;
- the session ends with an explicit winner/result;
- an automated fixture test plays one complete game from initial state to result.

Implement this task according to the current `SKILL.md`.

## BGO-009 — Runtime session adapter

**Status:** READY

Connect the current playable runtime to the logical session, tabletop and gameplay contracts.

Acceptance criteria:

- the runtime creates or loads one logical gameplay state for the active session;
- visible piece movement is driven by accepted logical commands rather than bypassing the domain state;
- current player and turn number are available to the player UI;
- rejected commands do not animate or persist as successful moves;
- focused tests cover the adapter boundary where practical.

Implement this task according to the current `SKILL.md`.

## BGO-010 — Player turn controls

**Status:** QUEUED

Expose the complete turn flow through the current player client.

Acceptance criteria:

- the active player can perform an allowed move and complete the turn;
- non-active players cannot complete gameplay actions;
- the UI clearly identifies the active player and turn number;
- ended sessions disable gameplay actions and expose the result;
- existing camera, hand and lobby navigation behavior remains intact.

Implement this task according to the current `SKILL.md`.

## BGO-011 — Shared-session persistence

**Status:** QUEUED

Persist and synchronize the logical session/gameplay state through the existing repository/network boundary.

Acceptance criteria:

- accepted logical state is persisted through the network adapter rather than direct UI writes;
- two clients converge after accepted commands;
- stale or rejected commands do not overwrite newer valid state;
- session lifecycle, active player, turn number and result survive reconnect;
- focused tests cover serialization and adapter behavior where practical.

Implement this task according to the current `SKILL.md`.
