# BGO AI Backlog

Before starting any task, read the complete current `SKILL.md`.

Implement every task in compliance with `SKILL.md` and leave the branch passing the required project checks.

## BGO-001 — SessionState domain foundation

**Status:** READY

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

**Status:** QUEUED

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

**Status:** QUEUED

Complete the logical session lifecycle with explicit game completion and result state.

Acceptance criteria:

- an active session can transition to an ended state;
- result and winner information are represented explicitly;
- ended sessions reject gameplay transitions that are no longer valid;
- focused automated tests cover completion and post-completion rejection behavior;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.

## BGO-004 — Table sections, zones, and slot capacity

**Status:** QUEUED

Formalize the next logical tabletop slice after the session lifecycle is stable.

Acceptance criteria:

- named tabletop sections are represented logically;
- zones and slots can belong to the appropriate logical section;
- slot occupancy and capacity can be validated without rendering or physics;
- invalid occupancy changes are rejected without corrupting state;
- focused automated tests cover valid and invalid occupancy behavior;
- existing behavior remains green under the required project checks.

Implement this task according to the current `SKILL.md`.
