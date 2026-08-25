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

## Runtime structure, Web export and transport boundary

The authoritative Godot client entry is:

```text
project.godot
  -> src/runtime/bgo_client.tscn
  -> src/runtime/bgo_client_runtime.gd
```

Production runtime code belongs in `src/runtime/`, not `src/demo/`. The historical `main_*` files accumulated real product behavior under a demo namespace and grew beyond the desired maintainability shape. They are now reorganized into policy-sized semantic runtime layers:

```text
client_runtime_base
  -> client_runtime_state_sync
  -> client_runtime_interaction
  -> client_runtime_composition
  -> client_runtime_gameplay
  -> client_runtime_camera
  -> bgo_client_runtime
```

This is a migration seam. **Do not extend this chain with another orchestration layer.** New camera, shell, session, networking, interaction or UI responsibilities should preferentially become focused controllers/services with explicit dependencies and be composed by the runtime. The objective is to progressively reduce orchestration inheritance, not recreate `main_3d`, `main_componentized` or `main_filtered` under new names.

A runtime parent may call only methods declared by itself or an ancestor. Never make a parent depend on a method introduced by a later child; reorder responsibilities or extract a composed controller/service.

After GDScript moves/renames or class_name/inheritance changes, remove the generated .godot cache and perform one full project import. A warm cache can preserve stale class metadata and mask invalid dependency direction.

Godot may return exit 0 while logging SCRIPT ERROR: Parse Error: or Failed to load script. Build/check scripts must inspect logs for those signatures. Errors solely from explicitly editor-only add-ons do not justify widening the Web PCK.

At typed plug-in boundaries prefer explicit collection types. Console.parse_line_input() returns PackedStringArray; keep the receiver explicitly typed rather than relying on ternary inference.

Firebase Functions CI targets Node 22. If a newer local Node/npm resolves the lockfile differently, reproduce the CI-compatible toolchain before changing valid backend code; npm 10 correctly installed the Firebase database type packages that npm 11 omitted locally in this integration.

`src/demo/` now contains only real demo/prototype behavior. `logical_client_runtime.gd` is the structured logical-session implementation path and remains explicit while its activation is integrated deliberately.

### Web export contract

The Web PCK is a runtime artifact, not a copy of the repository.

It must include:

- `src/runtime/bgo_client.tscn` and runtime resources reachable from the client;
- `src/runtime/`, `src/core/`, required `src/components/`, `src/ui/`, `src/network/`, `src/mcp/` and current runtime diagnostics;
- runtime portions of required add-ons;
- declarative `games/*/*.jsonh`;
- the runtime capability catalog `src/capabilities/*.jsonh`;
- component `component.jsonh` contracts, which are opened with `FileAccess` at runtime.

It must exclude repository/build/development surfaces such as:

- `build/`, `docs/`, `examples/`, `assets/source/`, `assets/authoring/`, `fastlane/`, `backend/`, `scripts/`, `tests/`, `hosting/`;
- `src/authoring/` and `src/editor/`;
- editor-only add-ons such as Asset Placer, Reactive UI Editor/Analyzer and GDSS editor resources.

Do not exclude `src/debug/` while `project.godot` still autoloads `BgoGameCommandConsole`; first remove or conditionalize that runtime dependency. Do not exclude Sandbox: Sandbox is a supported Web gameplay mode.

Non-resource runtime files are not automatically guaranteed to enter a Godot export. Any JSON/JSONH-style contract read with `FileAccess` must be covered by the preset's include filter and verified in an exported build.

### Realtime transport and MCP

High-frequency peer gameplay and external MCP ingress are separate interfaces.

```text
RealtimeTransport
- connect / disconnect
- peer presence
- realtime events/deltas
- interaction leases

SessionCommandBridge
- submit external command
- command id / actor id / expiry
- result / status
```

MCP must remain transport-independent. MCP tools invoke domain commands and must never directly mutate Firebase RTDB rows, WebRTC/MQTT state or Godot scene nodes. The authoritative host validates rules, ownership and interaction leases, executes accepted commands against logical state and publishes resulting events/state.

A future realtime adapter may be WebRTC/Piggyback, Freelay/MQTT, Tube or another transport without changing the MCP/domain command model. Firebase Functions may continue to host the public HTTPS MCP endpoint even if gameplay transport leaves RTDB.

Sandbox bypasses `RuleAuthority`; it does **not** bypass `InteractionAuthority`. Simultaneous Sandbox clients still acquire/lease/release a component while interacting with it.

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
- Do not stage incidental `.godot`, `.import` or newly generated `.gd.uid` files. A tracked UID rename is only acceptable when it intentionally preserves the identity of a moved tracked script.
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

### Repository-wide AI audit

Copilot Cloud coding-agent audit is currently disabled because it requires a paid capability not used by this project. Do not create automatic Copilot audit issues on `develop`. A future local agent may perform repository-wide advisory analysis derived from the current codebase, but its output must not become a parallel source of project truth.

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

<!-- AICI:POLICY:START -->
### Machine-enforced policy

This block is generated from the protected AICI policy. Do not edit it by hand.

- maximum GDScript file length: **500 lines**;
- maximum function length: **85 lines**;
- maximum decision complexity per function: **10**;
- public function `##` documentation required: **yes**;
- GDScript files/functions/variables/signals: `snake_case` / `snake_case` / `snake_case` / `snake_case`;
- classes: `PascalCase`; constants: `UPPER_SNAKE_CASE`.
- component root: `src/components`;
- component manifest: `component.jsonh`;
- each component manifest folder must be snake_case and own at least one local `.gd` and `.tscn` file.
<!-- AICI:POLICY:END -->

These limits are guardrails, not targets. Prefer smaller cohesive functions/classes. If an implementation needs to exceed an objective limit, refactor responsibilities rather than weakening the rule inside the target repository.

### File placement

Use these ownership boundaries:

- `src/core/` Ã¢â‚¬â€ logical/domain contracts, validation and state transitions that must not depend directly on rendering or Firebase;
- `src/components/` Ã¢â‚¬â€ reusable component implementations and component-local presentation/configuration;
- `src/network/` Ã¢â‚¬â€ Firebase/network transport adapters and synchronization infrastructure;
- `src/runtime/` Ã¢â‚¬â€ actual client runtime/orchestration and runtime-only services; `src/runtime/bgo_client.tscn` enters through `src/runtime/bgo_client_runtime.gd`;
- `src/demo/` Ã¢â‚¬â€ demonstrations/prototypes only; production runtime code must not accumulate here;
- `tests/` Ã¢â‚¬â€ focused automated/domain tests and test runner support;
- `games/` Ã¢â‚¬â€ declarative fixture/game definitions, never internal implementation paths;
- `hosting/` Ã¢â‚¬â€ static Firebase Hosting source surfaces outside the Godot runtime/PCK;
- `docs/` Ã¢â‚¬â€ authoritative architecture, roadmap, UX and deployment documentation;
- `backend/functions/` Ã¢â‚¬â€ Firebase HTTPS Functions/MCP backend; separate from Godot `src/`.
- `assets/source/` Ã¢â‚¬â€ original source material ignored by Godot; `assets/authoring/` is authoring-only and excluded from Web; `assets/runtime/` is shippable.
- `scripts/` Ã¢â‚¬â€ development/build tooling, not runtime domain behavior.

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

Do not proliferate parallel status documents. Current project truth has three maintained sources:

- `README.md`: product/architecture overview and repository structure;
- `TODO.md`: current tasks, blockers and next steps;
- `SKILL.md`: this coding-agent contract, workflow and engineering policy.

Material under `docs/`, plus legacy `AGENTS.md`, `AI_BACKLOG.md` and `CHANGES.md`, is reference/history unless README or TODO explicitly points to it for a specialized contract. When architecture or project state changes, update README/TODO/SKILL rather than creating another status file.

The project-status dashboard is an operational projection generated for DEV visibility; it is not another source of project truth.

## Technology baseline and freshness rule

Current verified baseline as of 2026-08-25:

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
