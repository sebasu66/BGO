# BGO Project Skill

Read this entire file before modifying BGO. Every development task starts by reviewing the current `SKILL.md` so the work is based on the project's current direction, architecture, workflow and technology baseline rather than conversational memory.

BGO uses the external **AI Commit Integrity Check** methodology. When work is integrated into `develop`, the integration commit must carry an `AI-Context-Key` derived from this exact version of `SKILL.md`. The purpose is simple: stale project context should fail early, while the normal path for a cooperative human or coding agent is to read the current skill and work from it.

If this file conflicts with remembered conversation context, the repository wins. If this file conflicts with a deeper authoritative document named below, stop and reconcile the documentation before changing architecture.

## Mission

BGO is a reusable virtual tabletop runtime for turn-based board games. **BGO Core is not a game.** Real games are external declarative `GamePackage`s/mods that reference stable public capabilities and component IDs.

The project must remain understandable and resumable by another competent human or AI contributor without access to old chat history. Repository documentation, tests and observable build state are therefore part of the product's engineering integrity, not optional notes.

Success means reaching a complete, maintainable platform through small verified vertical slices while preserving a working build and avoiding silent architectural drift.

## Product model

A BGO session is the central durable unit. Normal gameplay is session-first:

1. create/select/join a session;
2. resolve participant, seat and role;
3. load the pinned GamePackage identity/version/hash;
4. enter the active session state.

Supported client roles include player, shared display/TV and later spectator/editor/agent modes. The same logical session may be represented differently on Web, mobile, TV, desktop and future MCP clients.

The tabletop is one effectively continuous logical plane containing named sections. Camera presets navigate to meaningful areas; they are not separate copies of game state or separate screens.

`Hand` is a semantic/private collection rendered as a viewport overlay. It is **not** physical tabletop space and is distinct from `PlayerArea`.

## Non-negotiable architecture boundaries

1. BGO Core is a runtime, not a bundled game.
2. External GamePackages are declarative/untrusted content. Do not execute arbitrary remote GDScript.
3. Game definitions reference stable component IDs/configuration, never internal `.gd` or `.tscn` implementation paths.
4. Logical/domain state is authoritative. Rendering, camera, meshes, animation and physics do not decide game legality.
5. Firebase is coordination/persistence infrastructure, not per-frame simulation or the rules engine.
6. Networking and persistence sit behind adapters/repositories and consume domain results.
7. Synchronize logical objects/results, not graphical trajectories.
8. Prefer logical sections/zones/slots and authoritative occupancy/capacity over arbitrary Vector3 placement. Free-form placement is an explicit capability, not the default model.
9. `Hand` and `PlayerArea` remain separate concepts.
10. Owner, holder/controller, location and visibility remain separate concepts; neutral ownership must be representable.
11. Private information is protected by per-client logical state filtering, never merely by hiding graphics.
12. Components expose only configured/relevant capabilities. Do not create one huge generic object-action API.
13. MCP and agent-readable interfaces operate on logical concepts and validated commands, never raw Godot scene nodes.
14. Web, Godot and future native clients share logical contracts, not implementation details.
15. Do not add a second competing abstraction for an existing domain concept without an explicit architectural decision.
16. Significant architecture changes must be reflected in the authoritative documentation; they may not enter silently through implementation code.

Preferred direction:

```text
State + Command -> New State + Events
```

Keep domain operations pure or close to pure whenever practical.

## Components and representations

Public components use stable IDs and own their configuration/validation contracts. Adding a component should extend registries/contracts rather than create large `match component_id` switches throughout the core.

Logical quantity and rendering are separate. Useful representation classes include individual objects/miniatures, stacks/aggregates, formations/squads and virtual counters/resources.

Components progressively describe what they provide, require and permit. Validation should eventually produce both errors/warnings and a derived capability report.

### Dice

A die's logical definition is separate from random resolution and presentation:

```text
DieDefinition
- faces
- weights
- semantics

RollResolver
- physical
- random/trusted
- externally supplied

DiePresentation
- physical 3D
- spinner/reel
- instant
- future custom renderer
```

The authorized originating client may currently resolve a result and persist/share the logical outcome; peers do not need to reproduce an identical physical trajectory. A future trusted/verifiable resolver may replace the current resolver without changing game rules.

The first-party spinner/reel presentation may support arbitrary face symbols/graphics, deceleration, tactile/visual detents and deliberately suspenseful final transitions.

## Session and current runtime direction

The next important domain slice is a real `SessionState` with lifecycle, participants/seats, explicit host capabilities, active player, turn number, END TURN/next-turn flow, game end and result/winner state.

After the session lifecycle is stable, continue formalizing continuous tabletop sections plus child zones/slots, capacity/occupancy and a first complete chess/checkers-like conformance fixture.

GamePackage formalization, conformance fixtures and agent-readable Web build on those stable contracts rather than inventing parallel models.

## Agent-readable Web

Godot Web remains the primary human renderer, but a running page should expose a lightweight semantic projection of the same authorized logical model for E2E automation, accessibility and future agents.

Semantic state must use the same privacy/visibility filter as human clients. A player page must never expose another player's hidden information merely because data exists in DOM/JavaScript.

A future bridge may expose session/viewer identity, visible objects, turn state, controls and legal actions. MCP later projects the same state/command model rather than creating another game model.

## Development workflow

Normal branch flow:

```text
feature/dev-workbench
    -> coherent PR/merge
    -> develop
    -> full quality gate
    -> Firebase DEV preview
    -> remote E2E

main
    -> PROD only by explicit owner-approved promotion
```

Rules:

- `feature/dev-workbench` is the normal active workbench unless the project explicitly creates another feature branch.
- Intermediate feature commits should stay cheap and reversible.
- `develop` is the DEV integration branch.
- `main` is stable/PROD.
- AI agents and CI must **never** autonomously promote `develop` to `main` or deploy PROD.
- Do not run unrestricted `firebase deploy`; Hosting deployments must be explicit and scoped.
- Do not weaken lint, tests, architecture checks or integrity rules merely to make a change pass.
- If a quality rule itself is wrong, treat that as a separate deliberate policy/tooling change.

## AI Commit Integrity protocol

The validator is maintained outside BGO in:

`sebasu66/AI_commit_integrity_check`

BGO pins an immutable framework revision in its GitHub Actions caller. The target repository contains this skill and a minimal caller, not a second editable copy of the validator.

Before preparing an integration commit, obtain the current word-position challenge from the pinned AICI framework, read this complete skill, and construct the requested response from the current text. Add exactly one trailer:

```text
AI-Context-Key: <response>
```

Any meaningful edit to this file changes its content hash, automatically changing the challenge and invalidating a response based on an older version. There are no markers to rotate.

The mechanism assumes cooperative contributors. It exists to make current context the easy/default path, not to defend against someone deliberately trying to defeat it.

## Quality and evidence

A feature is not complete merely because an agent says it is complete or because code exists.

Use evidence states carefully:

- **PLANNED**: documented intention only;
- **IMPLEMENTED**: code exists;
- **TESTED**: focused automated test proves relevant behavior;
- **VERIFIED**: required quality gate passed;
- **DEPLOYED DEV**: confirmed in the Firebase DEV deployment;
- **PROD**: explicit owner-approved stable promotion.

Do not claim a stronger state without corresponding evidence.

The integration quality gate should cover, as applicable:

- project structure/architecture checks;
- GDScript formatting and lint;
- Godot headless import/parse;
- unit/domain tests;
- conformance fixture tests;
- validated Web export;
- local browser E2E;
- DEV deployment only from `develop`;
- remote E2E against the deployed DEV build;
- retained browser/build evidence on failure.

Objective checks may block integration. Heuristic maintainability findings should be reported clearly and only become blocking when the rule is deterministic and useful.

## Code and repository conventions

These are project-wide implementation rules. Backlog/tasks should normally state **what** must be built and say to implement it according to the current `SKILL.md`; they should not duplicate these conventions. The external AICI policy linter stores the machine-enforced copy of objective rules outside BGO so an ordinary feature change cannot relax them.

### GDScript naming

Use:

- files and folders: `snake_case`;
- `class_name`: `PascalCase`;
- functions/methods: `snake_case`;
- variables/properties: `snake_case`;
- signals: `snake_case`;
- constants: `UPPER_SNAKE_CASE`;
- private/internal helpers: leading `_` plus `snake_case`.

Names should express domain meaning. Avoid generic names such as `manager`, `helper`, `data`, or `thing` when a precise domain name exists.

### Function documentation and size

Public GDScript functions are part of the readable project contract and must have a preceding Godot documentation comment using `##` that explains purpose/contract when the name and types alone are insufficient. Private callbacks/helpers beginning with `_` do not require boilerplate documentation.

Machine-enforced limits for newly changed GDScript files are currently:

- maximum GDScript file length: **500 lines**;
- maximum function length: **60 lines**.

These limits are guardrails, not targets. Prefer smaller cohesive functions/classes. If an implementation needs to exceed an objective limit, refactor responsibilities rather than weakening the rule inside BGO.

### File placement

Use these ownership boundaries:

- `src/core/` — logical/domain contracts, validation and state transitions that must not depend directly on rendering or Firebase;
- `src/components/` — reusable component implementations and component-local presentation/configuration;
- `src/network/` — Firebase/network transport adapters and synchronization infrastructure;
- `src/demo/` — prototype/demo composition that is not authoritative domain logic;
- `scenes/` — top-level/composition scenes;
- `tests/` — focused automated/domain tests and test runner support;
- `games/` — declarative fixture/game definitions, never internal implementation paths;
- `web/` — static Web product/diagnostic surfaces outside the Godot runtime;
- `docs/` — authoritative architecture, roadmap, UX and deployment documentation;
- `scripts/` — development/build tooling, not runtime domain behavior.

A reusable public component normally lives in a component-owned folder. When it has a `component.jsonh`, that folder must use `snake_case` and contain matching `<folder_name>.gd` and `<folder_name>.tscn` siblings. Existing component families may add one grouping directory, for example `src/components/boards/checkered_board/`; do not scatter one component's implementation across unrelated folders.

Component manifests remain `component.jsonh`, stable component IDs use the `bgo.<family>.<name>` style, and external game definitions must never reference these internal file paths.

### Tests and backlog

A backlog item should not restate naming, file paths, function-size limits, documentation syntax, deployment policy or other general implementation rules. It should describe behavior/acceptance criteria and reference the current skill for implementation compliance.

When a public behavior changes, add or update focused tests. Prefer making the correct implementation the easiest way to satisfy the acceptance tests and the policy linter.

## Maintainability rules

Optimize for readable responsibilities, low coupling, explicit dependencies and testability rather than ceremony.

Avoid:

- very long or deeply nested functions;
- giant multi-purpose files/classes;
- duplicated domain logic;
- dead/obsolete code retained without reason;
- hidden side effects in domain operations;
- vague names that conceal domain meaning;
- compatibility hacks that silently reset or corrupt existing session state;
- comments that merely narrate obvious syntax instead of explaining non-obvious intent or constraints.

When a public behavior is added or changed, add focused tests whenever practical. As component families mature, each public component should have focused domain tests and at least one small conformance fixture exercising meaningful capabilities.

## Documentation and project continuity

Authoritative deeper documents currently include:

- `docs/CURRENT_PRODUCT_DIRECTION.md` — current product/architecture decisions;
- `docs/IMPLEMENTATION_ROADMAP.md` — staged implementation/checkpoints;
- `docs/DEPLOYMENT_ENVIRONMENTS.md` — DEV/PROD release rules;
- `docs/PLAYER_CLIENT_UX.md` — player interaction direction where applicable;
- `AGENTS.md` — detailed historical/operational development contract while content is progressively consolidated here.

The project-status dashboard is an operational projection, not a substitute for the roadmap. Update project state when checkpoints, blockers, implementation order or material risks change.

Git history records changes, but it is not sufficient project state documentation. Preserve the reason and current truth in the appropriate project document.

## Technology baseline and freshness rule

Current verified baseline as of 2026-08-18:

- **Godot:** BGO is pinned to `4.7.1-stable`. Godot 4.8 is currently a development series, so do not silently move BGO to it. Official release/archive and API documentation are the authority for version-sensitive engine behavior.
- **Node.js in CI:** `22`. Current Playwright documentation supports current Node 22.x, 24.x and 26.x lines.
- **Playwright:** use the version pinned by BGO package metadata; consult current official Playwright documentation/release notes before relying on recently changed CLI/browser behavior.
- **Firebase Hosting:** DEV uses a preview channel. Preview deployments still interact with the real Firebase project backend resources unless separately emulated/isolated, so do not assume a preview URL implies backend isolation.
- **Firebase project:** `board-game-online-68c3f`.

For Godot, Firebase, Playwright, GitHub Actions or another fast-moving external API/tool, **do not rely solely on model memory** when behavior may have changed. Check current official documentation/release notes before implementing version-sensitive behavior, and prefer the project's pinned version over an unrelated latest/development release unless an upgrade is deliberate.

## Firebase prototype constraints

Current prototype identifiers:

- Firebase project ID: `board-game-online-68c3f`;
- RTDB: `board-game-online-68c3f-default-rtdb.firebaseio.com`;
- Web build output: `build/web/`;
- DEV deployment uses Firebase Hosting preview channel `dev`;
- database Test Mode is temporary and must not be silently treated as production security.

Deploy Hosting only. Never replace the scoped deployment policy with unrestricted production deployment unless the owner explicitly changes that policy.

## Task protocol

For every task:

1. Read/review this complete `SKILL.md` before implementation.
2. Inspect the current branch and relevant files; do not work from remembered file contents.
3. Identify the active roadmap checkpoint and affected product/domain surface.
4. Check current official documentation first when the task depends on fast-changing external technology behavior.
5. Make the smallest coherent vertical change.
6. Preserve the architecture boundaries and code/repository conventions above.
7. Add/update tests for changed public behavior.
8. Update authoritative documentation when a contract, policy, roadmap state or significant architecture decision changes.
9. Do not hide migration/schema errors or destructively reset existing session state to accommodate a schema addition.
10. Leave the feature branch coherent and prepare the current AICI context response before integration to `develop`.
11. Never promote DEV to PROD without explicit owner instruction.

When uncertain, prefer a smaller reversible implementation that preserves public contracts and leaves clear evidence of what is and is not complete.
