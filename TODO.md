# TODO

This file is the only place for pending work and progress. `README.md` explains what BGO is and how it is designed; this file says what is left and what has been done.

Update rule: at the end of every work session move finished items to the progress log with the date, add any newly discovered work, and keep each item verifiable. Mark an item `[x]` only when its exit criteria are met, not merely because code exists.

Last updated: 2026-10-05. Branch: `feature/github-transport-ai-timeline`; `origin` has everything up to `c194502`, and the documentation consolidation below is committed locally and not pushed yet.

## How to resume (read this first)

1. Read `README.md` (design, decided rules, repository structure), `SKILL.md` (agent contract, policy limits, workflow) and then "Next up" below. Nothing else is authoritative.
2. Check the repository before changing anything: `git status`, `python scripts/check_structure.py`, then the headless tests with `<godot> --headless --path . --script res://tests/test_runner.gd` (last full run: 1174 assertions passing). On the main development machine Godot 4.7.1 is `C:\DEV\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe`, the version CI uses.
3. Lint and format exactly as CI does, on changed `.gd` files only: install `gdtoolkit==4.*` in a throwaway virtual environment, then run `gdformat --check` and `gdlint`. One function can be exempted from `max-returns` with `# gdlint:ignore=max-returns` on the line above its `func` (no space after the colon); five guard-clause validators in `gameplay_state.gd` already are.
4. Godot's headless import rewrites five autoload paths in `project.godot` (GodotxToast and four Ambient* ones) from explicit `res://` to `uid://`, which makes `check_structure.py` fail on a clean checkout. Restore them with `git checkout -- project.godot` before committing. A normalizer script is still to be built.
5. `assets/MINIS/` (344 MB of raw FBX and PNG for the Dracula miniature) and `shader/` (CC0 frosted-glass shaders) are untracked on purpose, and nothing references them except one `representation.json`. The owner has not decided what to do with them.
6. Studio: `python scripts/build_studio.py [--open]` regenerates the disposable `.engine/studio/index.html` from component manifests, code, tests and `MODULE.md` files.
7. Tooling notes from the main machine: Windows PowerShell output stops at the first non-ASCII character, so read files through Python with `encode('ascii','backslashreplace')`; a very long single command fails with `ENAMETOOLONG`, so write long files in parts; prefer scripted replacements that assert an exact single match.
8. Working agreement with the owner: ask before pushing, promoting to PROD, running anything that deploys, or deleting something that is not clearly obsolete. Decisions made so far are in "Tabletop rules decided so far" (`README.md`) and "Open decisions" below.

## Progress log (newest first)

### 2026-10-18 (later)
- [x] Table 0.2.0: 5 cm grid (`cell_size_cm`, `table.set_cell_size`), containment both ways, locator, magnet drop with closed-table refusal, private-zone snapshot filter. Rules T10-T13 in `src/components/table/MODULE.md`.
- [x] Hierarchy applied: `grids/table_grid` -> `table/grid`, `slots/basic_slot` -> `table/slots`, `player_area` -> `player/area`, `hands/vertical_hand` -> `player/hand`, `player_presence` -> `player/presence`. Dependency goes one way: the player asks the table, the table never imports the player.
- [x] `scripts/run_tests.py`: fails on any `SCRIPT ERROR`, compile failure or timeout. The plain Godot runner printed PASSED while two scripts did not compile, so a green count alone is not evidence.
- [x] `SKILL.md`: tests must follow the real behavior (real game definition, real command path, real components), never invented stand-ins.
- [x] `table_grid_test.gd` rewritten: it loads `games/test001` with the real loader and adapter and changes it with the real verbs (`slot.add`, `table.set_mode`, `zone.set_visibility`, `object.move`, `turn.end`). Mutation check: breaking `TableVisibility` makes it fail.
- [x] PBR presets from ambientCG (marble, wood, felt, metal) are painted on the floor; test per preset; switching back to no preset gives a plain floor (a bug the test found).
- [x] Found: a script that fails to compile leaves the Godot test runner hanging instead of exiting. `scripts/run_tests.py` limits it to 120 s and reports the error. The runner itself should call `quit(1)` on failure.
- [x] Two-stage method recorded in `SKILL.md` ("Two stages") and enforced by `check_structure.py`: `x.y.z-prototype` = working code and functional tests, tried by the owner through the MCP; `x.y.z` = polished (texts, logs, `MODULE.md`, full tests). Applies from the next slice on.
- [ ] Wire the grid code to the product (see G6, G7, G8 in `src/components/table/MODULE.md`): `object.drop`, `container.put_inside`, `container.take_out` verbs; filter `hands` and `events` per viewer.
- [ ] Test the table through MCP with the real game (a real seat: zone + hand + presence). The per-seat player zone creation is still to do.
- [ ] Linter: cyclomatic complexity (`gdradon`), Godot warnings as errors (unused variable, parameter, signal, unreachable code) for `table/` and `player/`, unused private functions in `check_structure.py`.
- [x] Deleted the stray `src/components/slot/` (two unreferenced `.tscn`) with the owner's OK; Git history keeps them.
- [ ] Make the project test command use `scripts/run_tests.py` in `AGENTS.md`, `SKILL.md` and CI.
- [ ] Wire `TableVisibility.snapshot_for_viewer` into the real client and MCP snapshots.

### 2026-10-18
- New standards in `SKILL.md`: **self-contained components (MVC)** and **super-readable code**. `scripts/check_structure.py` enforces them for the paths in `SELF_CONTAINED_COMPONENTS` and `READABLE_STRICT`; other code is only counted (112 findings = visible debt). Migrate a component by adding it to those lists.
- First component built to the standard: `src/components/table/` (`bgo.table.basic` 0.1.0): table mode (`free`/`closed`), surface, lights, zone visibility/resize, anchored slots, host-only verbs (`table.*`, `zone.*`, `slot.*`), live view, English/Spanish texts, log, tests. Rules and open gaps are in its `MODULE.md`. Design: `docs/mesa.md` in the `general` repo.
- BGO branches reduced to `develop`, `main`, `respaldo`, `codex/reactive-ui-dev`; `develop` pushed (Firebase anonymous auth + membership rules).
- Next: surface PBR preset painting, private-zone filtering, slot world position from board cell, then the `g`/`m` terminal tree and the Onitama slice.

### 2026-10-04 and 2026-10-05

- [x] Documentation consolidated: all 29 files of `docs/` (about 200 KB) were read, what is still true was moved into `README.md` and `TODO.md` after checking it against the code, and `docs/` was removed (Git history keeps the originals). Corrections made while checking: the README said 13 components and the real count is 14; capability verbs (`object.spawn`, lock, transfer) are declared in the catalog but not implemented; match sessions have no checkpoints or restore, and there is no inspect mode, semantic Web state, interaction profile or section camera preset yet; the MCP server exposes 12 tools at version 0.2.0; the live transport is full-session polling every 0.75 s. The third-party dice-roller docs (`usage.md`, `custom-shapes.md`) moved to `addons/dice_roller/docs/`; the empty Copilot audit placeholder and the docs index were deleted.
- [x] Dependencies of `docs/` fixed: `check_structure.py` now requires `README.md`, `TODO.md` and `SKILL.md` instead of two files under `docs/`; `AGENTS.md` became a short pointer; `SKILL.md` no longer calls `docs/` authoritative; the project-status page no longer links the removed audit file.
- [x] Hand and box verbs moved out of `gameplay_state.gd` into `src/core/gameplay_collection_verbs.gd`, with documented `max-returns` lint exemptions on five pre-existing guard-clause validators, so the CI lint gate passes on every changed file.
- [x] Cleanup commits: missing `.uid` files, canonical-session migration (retired `logical_client_runtime`), TEST002 as default game with its test fixed, component error toasts, miniature component and runtime assets.
- [x] Engine extraction map written; its conclusions live in `README.md` and the file classification is in "Engine extraction (E0-E5)" below.
- [x] Studio generator committed (`scripts/build_studio.py`): read-only graph from the 14 component manifests, four zoom levels. Result: 13 components green, 1 yellow (`bgo.player_presence.basic_mask`, no test references it).
- [x] `MODULE.md` concept drafts for hand, player area and asset box (awaiting owner validation).
- [x] Canonical commands added: `object.move` now accepts objects held in a hand or player area, `object.reorder_in_hand`, `object.take_from_box`, `object.return_to_box`; player area lays objects out as a grid on the seated side.
- [x] Quality gate green: 1174 test assertions, `gdformat`, `gdlint` and `check_structure.py` all pass.
- [x] Branch pushed to `origin`.
- [x] `README.md` consolidated as the single source of truth (product, clients and device roles, join flow, modular engine, session modes, decided tabletop rules).

## Next up (in this order)

1. **Studio demo button.** For components with testable behavior, a button that launches a real Godot demo in a basic test table (camera, terminal and whatever structure the component needs). Open question: launch from the browser through a local command, or with a script that runs `godot.exe` directly.
2. **Refresh the three `MODULE.md` files.** Gaps G1 and G2 (place from hand, take out of an area) and the box gaps are resolved by `c194502`. Record the owner decisions listed in `README.md`, and add privacy-flag to-dos per component.
3. **`MODULE.md` for the other 11 components.** Agents infer them from the code; the owner validates. Start with components that have real behavior.
4. **Finish E0.** Migrate the remaining active UI mutations from direct `GameSessionRepository` writes to `GameplayState.execute()`, then remove the obsolete repository mutation methods (the unused `move_piece` is already gone).
5. **One session mode.** Merge `sandbox.enabled` (test001) into `runtime.mode`, and make sandbox a kernel session policy instead of the separate `SandboxState` entry path.
6. **Repeat the multi-client smoke test** (Display + P1 + P2) after the recent camera, UI and runtime refactors.

## Roadmap phases (status checked against the code on 2026-10-04)

The phases are a dependency order. Do not start graphics profiles, billboard generation, top-down rendering or photobooth generation for new content until the package and asset-resolution boundaries are stable (the miniature slice is the agreed exception).

- **Phase 0, stabilize the PoC:** done in substance (TEST001 fixture, Firebase session, display, P1 and P2). Open: repeat the multi-client smoke test (Next up 6) and confirm existing sessions survive schema additions without a destructive reset.
- **Phase 1, quality gate:** done. `quality-gate.yml` runs policy, structure, `gdformat` and `gdlint` on changed files, headless import and parse, tests, Web export, browser E2E and DEV deploy checks; `SKILL.md` is the agent contract. Open: the dependency-direction check only covers core versus Firebase; no automated heuristic report (large files, nesting, dead code); no CODEOWNERS.
- **Phase 2, core logical model:** mostly done (`SessionState`, `FlowState`, `GameplayState`, slots, hand, player area, asset box, grid footprints, owner versus holder). Open: transfer/give and release-neutral verbs; confirm every Checkpoint 2 case has a test (owner moves own object, others cannot, neutral acquire, occupied slot rejected, two logical clients converge).
- **Phase 3, GamePackage:** partial. Games load from `games/<id>/game.jsonh` through `GameDefinitionLoader` (`schema_version` 1, precise errors). Open: package manifest (ID, version, content hash, component dependencies, locales, asset manifest), session pins package identity, loading from outside `games/` or from a remote manifest URL, a test that a copied fixture loads from another directory.
- **Phase 4, conformance suite:** partial. Fixtures: `test001`, `test002`, `table_debug`, `conformance_race` (board, slots, ownership, miniature). Open: cards, decks, discard, dice with seeded results, stacks and counters, hidden information. There are no card, deck or dice components yet. Later: CI fails when a new public component has no conformance coverage.
- **Phase 5, AssetResolver:** partial. `src/network/bgo_asset_resolver.gd` loads one remote GLB with http(s) validation, optional SHA-256 integrity, an on-disk cache keyed by URL hash and a failure signal. Open: logical asset IDs, textures, placeholders while loading, session versus persistent cache policy, mirror lists, on-demand priorities, cold and warm cache tests.
- **Phase 6, asset validation and budgets:** partial. The miniature pipeline reports triangle counts and sizes and fails clearly. Open: a general `AssetValidator` with per-profile budgets and PASS, WARNING, REJECT results; graceful failure when no representation fits the active profile.
- **Phase 7, multiple representations:** partial (`client_render_profile.gd`, miniature `representation.json` with billboards and LOD). Open: a `RepresentationSelector`, two clients with different profiles on one session, a test that switching representation never changes logical state.
- **Phase 8, top-down renderer:** partial (tactical view toggle in the camera). Open: a dedicated orthographic renderer, quantity and stack indicators, coexisting with a 3D client in one session.
- **Phase 9, authoring pipeline and photobooth:** partial (the Dracula pipeline produces GLB, LOD, billboards and portrait). Open: generalize to any miniature (4 and 8 direction billboards, top-down sprite, icon, manifest generation), with generated output passing the same validator.
- **Phase 10, MCP logical control:** DEV prototype exists; see "MCP / external agents". Exit criteria: MCP describes fixture state without reading render nodes, MCP commands emit the same events as UI commands, illegal commands are rejected through the same validation path.

Deferred on purpose, do not pull forward: automatic graphics downgrade from measured FPS, normal and depth billboard relighting, VR presence, rich remote avatars and hands, rollback and prediction networking, real-time physics sync, arbitrary mod scripting, marketplace and payments, cinematics and photo mode, final art direction, the assisted Tabletop Simulator JSON migration wizard (not universal compatibility), and the optional PC-generated board snapshot service (request notification separate from gameplay transport, images expiring in shared object storage).

## Engine extraction (E0-E5)

- [ ] **E0** Route every mutation through the canonical command path (in progress; see Next up 4).
- [ ] **E1** Split a generic structure validator from BGO-specific rules. Add the module-isolation rule (a module imports only the kernel contract and its own files) and detection of writes that bypass the command path.
- [ ] **E2** Kernel: registries, capabilities, command protocol, mode policy. First analyze how to split `gameplay_state.gd` (generic command and turn protocol versus tabletop verbs).
- [ ] **E3** Use `status.json` as the base of the Studio, or retire it (see Hygiene).
- [ ] **E4** Modules outside the tabletop (camera, animation, effects, NPC AI).
- [ ] **E5** Integration validator, `engine watch` and supervisors (orphan events, dependency graph, golden replays). Introduce CODEOWNERS and path-aware CI for module ownership.
- [ ] Core services ring: move console, logger, debug and the base empty-table renderer out of the kernel path; remove the Firebase sink from `src/core/bgo_logger.gd`.
- [ ] `component_registry.gd` hardcodes `res://src/components`; hand module roots to the kernel instead.
- [ ] Deterministic time and IDs: `bgo_logger.gd` and `bgo_activity_log.gd` use wall-clock time (breaks replays); the activity log also reaches the repository through `has_method`.

File classification, observed 2026-10-04 (proposed layer, confirm when extracting):

- Kernel: `session_state.gd`, `flow_state.gd`, `logical_object_state.gd`, `bgo_game_object.gd`, `capability_registry.gd`, `component_registry.gd` (it hardcodes `res://src/components`; the kernel should receive module roots as configuration), `game_event_router.gd`, `game_definition_loader.gd` (validates definitions, including `runtime.mode`).
- Kernel but mixed: `gameplay_state.gd` (about 880 lines) holds the command protocol, permissions and turn checks together with the tabletop verbs, so it needs a split analysis. The hand and box verbs already moved to `gameplay_collection_verbs.gd` as a first step.
- Module family `tabletop`, living inside core today: `tabletop_state.gd`, `table_grid_state.gd`, `hand_state.gd`, `asset_box_state.gd`, `tabletop_definition_builder.gd`.
- Kernel port plus adapter: `bgo_logger.gd` (still owns a Firebase sink) and `bgo_activity_log.gd` (reaches the repository by `has_method` and uses wall-clock time, which breaks deterministic replay).
- Kernel mode policy: `sandbox_state.gd`, a separate class with its own verbs (`sandbox.spawn`, `remove`, `set_property`, `move_to_slot`, `move_free`, `set_score`, `snapshot.save` and `restore`).
- Adapters: `game_api.gd` (the `G` projection), `src/network`, `src/mcp`, `src/runtime`, `src/authoring`.
- Session mode: `runtime.mode` is `match` or `sandbox`. Only `games/table_debug` uses sandbox, and `games/test001` sets a separate `sandbox.enabled` flag so MCP can create objects inside a match: two overlapping ideas to merge. Mode should be a kernel session policy chosen at start, turn enforcement belongs to the match policy and sandbox lifts it, and private non-gameplay actions such as reordering your own hand need no turn even in a match (decided).
- Still missing versus the target engine: a minimal kernel (tabletop concepts remain in core), manifests for core pieces (only components have `component.jsonh`), modules outside the tabletop (camera, animation, effects, NPC AI), an integration validator (orphan events, dependency graph, golden replays, detection of writes that bypass the command path), the Studio watcher (`engine watch`), and deterministic time and IDs in core.

## Clients and product surface

Design is in `README.md` (Clients and device roles, Session and join flow).

- [ ] **W1 lobby and join flow:** create a session, room code and invite link, choose seat and role, launch the Godot runtime with explicit session, package, identity, device role and profile. Decide how the TV shares the code (QR is the proposal).
- [ ] Display (TV) role: presentation-only client with a cinematic camera.
- [ ] Phone player role: 2D-style view (billboards plus orthographic top-down) as viewer and controller with private hand, dice and actions.
- [ ] Orthographic top-down tactical renderer on every platform (roadmap phase 8).
- [ ] Per-client state filtering for private information (hands, non-public areas). Required before phones can be trusted as private controllers.
- [ ] PWA entry point with Mobile, TV/Display and browser-desktop modes.
- [ ] Android and Android TV wrapper of the same runtime, for devices whose browser is insufficient.
- [ ] Separate Windows download with optional companion-enhanced capabilities.
- [ ] Browser and mobile export verification of the client profile contract (only native profile selection has tests today).
- [ ] BGO-011 shared-session persistence: lifecycle, active player, turn number and result survive reconnect; stale or rejected commands never overwrite newer state.

## Gameplay and modules

- [ ] Define the missing verbs: transfer/give, release neutral, `object.place`, a grid-placement verb, `object.split`.
- [ ] Token stacks: a setting for grouped (one object with a count, take 1 to N like a deck) versus individual display. Tune per component when each is tested alone.
- [ ] Privacy flags as per-component to-dos: hand, player area, asset box.
- [ ] Game-driven rules from the game's JSONH: turn structure, phases per turn, ownership and move restrictions, hand ordering overrides.
- [ ] Remove or decide the unused availability modes and quantities (ignored for now).
- [ ] Verbs declared in the capability catalog but not implemented: `object.spawn`, despawn (return to box with history), lock and unlock, transfer owner or holder.
- [ ] Inspect mode: enlarged view with 3D rotation, without moving the object.
- [ ] Hand overlay drawer UX (collapsed handle with count, expandable drawer, enlarged focused item, multi-selection, PLACE).
- [ ] Sections: camera presets per section and section-level visibility and capability restrictions.
- [ ] Capability compatibility report: validate contradictory capability combinations in a package and derive what the configured game permits.
- [ ] First complete playable slice: an abstract chess or checkers-family game with seats, start and finish, turn number, active player, END TURN, result, a board and individually meaningful pieces. The core pieces exist (`SessionState`, `FlowState`, `turn.end`, `match.finish`, slot occupancy); a game package with movement rules does not.
- [ ] Camera and environment tuning toward a seated-human view and a warm horizonless studio look (see `README.md`).
- [ ] Test each component on its own in the demo environment (see Next up 1).
- [ ] Runtime slot-capacity and occupancy authority in the command path.
- [ ] Server-side filtering of private hands and non-public player areas (the privacy flags are only settings today).
- [ ] Interactive instantiation from the Asset Box catalog in the client, and the Asset Box as a viewport drawer.
- [ ] `base_corner` anchor for large surfaces, with an explicit placement migration for existing boards.

## Player client UX

Design is in `README.md` (Player client UX). Implemented today: camera gestures and desktop controls, the left utility strip (reset camera, filters), the right action strip (pick up, place), the long-press context menu, the vertical FILO hand, client settings.

- [ ] Tune the default camera toward a seated-human view: more distance and height, less top-down pitch, a wider field of view, and zoom limits so the camera cannot clip into normal components.
- [ ] Section camera presets and section shortcuts on the left strip.
- [ ] Left strip: Inspect, fullscreen and orientation, return to lobby.
- [ ] Right strip shows only capabilities relevant to the active game and component, and END TURN is read from `SessionState` (disabled unless the participant owns the active turn).
- [ ] Contextual action presentation: emphasize the active object, dim the background, suppress accidental background picking while a menu is open.
- [ ] Safe interaction profiles in the GamePackage contract (`bgo.player.standard`, `direct_interact`, `card_heavy`) with conformance tests.
- [ ] Generalize the floating 3D hand across game profiles and connect catalog instantiation to the Asset Box commands in the client.

## Authoring and node composition

Design is in `README.md` (Authoring). Existing nodes: `BgoGameObject3D`, `BgoBehavior`, plane, model and billboard representations, `BgoPbrMaterial`.

- [ ] Missing representations (box, primitive) and feature nodes (stackable, rotatable, lockable, placeable, flippable, surface, slot layout, stats).
- [ ] Property schema and provenance shown in the inspector for the effective property map.
- [ ] Variant workflow: create base component, create and duplicate variant, add to package, create setup instance, preview and validate.
- [ ] `BgoBehavior` compiled to canonical events with a condition and target language, chain depth and loop limits, and every result recorded in the parent command.
- [ ] BGO dock for package context, variant inheritance, validation and the high-level workflows.

## Open decisions (owner)

- [ ] Who validates commands in multiplayer: the host (assumed by the networking section of `README.md`), each client, or a server.
- [ ] How to track `assets/MINIS/` (344 MB of raw FBX and PNG sources) and `shader/`: both are untracked on purpose and nothing uses them yet.
- [ ] Whether `hosting/project-status/status.json` stays as the operational dashboard. It is dated 2026-08-29 and still lists done work as pending (SessionState lifecycle, Firebase DEV credentials). Either refresh it or retire it so there is one status source.

## Hygiene and known debt

- Godot's headless run rewrites five addon autoloads in `project.godot` (`GodotxToast` and the four `Ambient*`) to `uid://`. Restore explicit `res://` paths before each commit, otherwise `check_structure.py` fails.
- `build/web` exists in the checkout; it is generated output, not source.
- Two overlapping sandbox concepts (see Next up 5).
- `bgo_logger.gd` still owns a Firebase sink inside core.
- Debug console autoload still blocks excluding `src/debug/` from Web builds.
- [ ] Verify the CI result of the pushed commits: the protected policy limits (GDScript files 500 lines, functions 85 lines, decision complexity 10, public functions documented) are enforced by an external job that cannot run locally. `gameplay_state.gd` is about 880 lines and was already over before this work.
- [ ] `AI_BACKLOG.md` and `CHANGES.md` (the changelog of the third-party dice-roller addon) are legacy: fold what is still useful into this file and delete them, or move `CHANGES.md` into `addons/dice_roller/`. Owner decision.
- [ ] Stack splitting on hand pickup (`ONE AT A TIME`) exists only in the legacy direct `GameSessionRepository.pickup_piece`; the canonical command path has no split. Implement the owner's token design (one grouped object carrying a count, taking 1 to N) through a canonical command while finishing E0.
- [ ] Remove or protect the public `debug_public/latest_error/TEST001` RTDB endpoint before enabling RTDB security rules.
- [ ] Review the ReactiveUI Community License before any commercial distribution.
- [ ] Evaluate Deep RayCast 3D for overlapping pieces; keep Lente, GPU Texture Painter and GoBuild as authoring-only experiments.

## Needs owner confirmation (possibly stale)

Older integration items from before the engine work. The branch in use is now `feature/github-transport-ai-timeline`, so confirm whether PR #21 and `feature/reactive-ui` were already merged:

- [ ] Complete the local Quality Gate for the runtime/root-structure refactor.
- [ ] Get PR #21 green in GitHub Actions and merge it into `develop`.
- [ ] Verify the Firebase DEV deployment and the deployed browser E2E.
- [ ] Reconcile the primary local `C:/DEV/BGO` worktree with the integrated `develop` state after deployment.
- [ ] After the runtime evidence gate passes, prepare the focused PR to `develop` for the miniature slice; do not promote to PROD.

## Runtime architecture

- [ ] Continue replacing the transitional `client_runtime_*` inheritance seam with focused composed controllers/services when responsibilities change.
- [x] Retire the competing `logical_client_runtime.gd` entry path; the production runtime now loads shared snapshots through `RuntimeSessionAdapter` into canonical `SessionState` + `FlowState` + `GameplayState`.
- [ ] Migrate the remaining active UI gameplay mutations from direct `GameSessionRepository` writes to canonical `GameplayState.execute()` commands, then remove the obsolete repository mutation methods.
- [ ] Remove or conditionalize the debug console autoload before excluding `src/debug/` from Web builds.
- [ ] Validate the `assets/source`, `assets/authoring`, and `assets/runtime` workflow with real authoring assets.

## Miniature import and rendering profiles

- [x] Complete the Dracula source pipeline from `assets/MINIS/dracula.fbx`; keep FBX as authoring/source input and do not treat the derived GLB as the source of truth. Godot/ufbx exports the source and gltfpack produces non-Draco runtime outputs.
- [x] Verify FBX import/processing produces an optimized high-quality GLB plus an explicit desktop-standard LOD GLB, with measurable validation results and clear failure reporting. Current outputs are 149,994 triangles / 8,561,560 bytes (normal) and 29,998 triangles / 1,812,572 bytes (far LOD), and both pass a Godot 4.7.1 import scan.
- [x] Verify base-pivot placement and billboard calibration from the 31 turntable frames, including transparent background, physical scale, bottom alignment, facing direction and per-frame offsets. The current Dracula calibration uses `front_frame=0`, counter-clockwise order, `+z` source front, `-1 cm` vertical offset and zero per-frame correction after contact-sheet/runtime inspection.
- [x] Verify the checked-in TEST002 definition loads Dracula through the miniature component and `assets/runtime/miniatures/dracula/representation.json` in a rendered Godot runtime. The existing shared Firebase TEST002 snapshot still contains the previous `assets/MINIS/generated/...` path and must be migrated or recreated separately before the normal connected client shows this new definition.
- [x] Define the client profile contract: Windows native selects configurable high-quality 3D/LOD with free camera; Web and Mobile select responsive constrained billboards with fixed-height/fixed-pitch perspective cameras and yaw orbit; every platform exposes orthographic tactical pan/zoom/top-down rendering. Native focused tests cover profile selection; browser/mobile export verification remains a later platform gate.
- [x] Generate the authoring portrait and circular tactical avatar without adding either representation to replicated gameplay state.
- [ ] After the runtime evidence gate passes, prepare the focused PR to `develop`; do not promote to PROD.

## Web platform and environments

Design is in `README.md` (Web platform, Environments and deployment). `hosting/` has a test launcher, error viewer, help page and project status dashboard; there is no public landing page yet.

- [ ] **W0 product shell:** responsive landing page, navigation, basic catalog and demo entry points, design tokens, a persistent DEV URL, launching the current test runtime without account plumbing. Exit: usable on desktop and phone, independently deployable, no login required.
- [ ] **W1 lobby and session UX:** create a session, join by code or link, expose test sessions where appropriate, choose player or display role, launch Godot Web with explicit session context. Exit: a tester goes from the website to a running conformance game without editing URLs (same item as the join flow above).
- [ ] **W2 catalog and GamePackages:** package listing and details, capability and client compatibility display, launch a selected package. Exit: catalog metadata is independent of the BGO executable and points to GamePackage identities.
- [ ] **W3 authentication and account gate (later):** login, registration, recovery, protected routes, consistent identity passed to the launch, an explicit DEV and test authentication path. Do not pull forward.
- [ ] **W4 commercial model decision (deferred):** measure usage and hosting cost, choose a model, document privacy and product implications, design provider-neutral entitlements, only then schedule integrations.
- [ ] **W5 creator and admin surfaces (later):** package publishing, validation reports, asset status, version management, moderation and support.
- [ ] DEV and PROD split is established only when: `develop` and `main` roles are enforced, both builds have distinct persistent URLs, DEV cannot overwrite PROD, promotion needs an explicit owner action, both builds trace to known commits, environment configuration is explicit, and CI reports the commit deployed to each environment. `develop` and `main` exist and the DEV channel deploy is wired; confirm the PROD side and the separate Firebase projects.
- [ ] Owner setup for the automatic DEV deploy: the secret `FIREBASE_DEV_SERVICE_ACCOUNT`, the variable `FIREBASE_DEV_PROJECT_ID`, and `BGO_MCP_DEPLOY_ENABLED` for the DEV MCP function. Confirm they are set.
- [ ] E2E growth once semantic state exists: open the launcher, create or join a fixture session, open Display, P1 and P2 contexts, verify seats, move an object, verify the transition through semantic state, verify the other clients converge, capture screenshots and semantic snapshots. Screenshots complement semantic assertions; compare 3D canvas pixels only where stable. Today there is a single `smoke.spec.mjs`.
- [ ] Failure evidence target for a browser run: commit SHA and tested URL, step outcomes, console and page errors, network failures, Playwright trace, screenshots and video, the BGO flight-recorder snapshot, semantic session state before and after the failing action, and the legal actions visible to the test participant, so AI debugging agents can consume it.
- [ ] Branch hygiene: many stale local and remote branches (`codex/*`, `integration/dev-batch-*`, `respaldo`, `list`, old `feature/*`). Confirm what is merged and delete the rest.
- [ ] Every status-dashboard update belongs in the same change as the checkpoint, blocker or risk it reflects.

## Realtime networking

Rationale and target architecture are in `README.md` (Networking and MCP boundary). Status: planned, nothing implemented; the live transport is still full-session polling every 0.75 s.

- [ ] Quick win: replace full-session polling with Firebase realtime listeners. It is already a clear improvement and the agreed fallback.
- [ ] Create a disposable `spike/realtime-transport` branch from a known-green integrated `develop`; never run the experiment on `develop` or an unrelated feature branch.
- [ ] Define the minimal provider-neutral `RealtimeTransport` boundary (create, join and leave a session, send a command, publish an event, publish transient updates, peer connected and disconnected, message received) so gameplay code never depends on WebRTC, MQTT, Firebase or a plugin API. It carries canonical BGO envelopes, never scene-node state.
- [ ] Compare Freelay, WebRTC Piggyback, Tube and native WebRTC (Godot Web has browser WebRTC; native desktop and mobile may need an extension) with the same proof, using BGO logical object IDs and commands: create a session, join from a second client, confirm peer identity, acquire one component, drag it with transient updates, commit a canonical move, replicate it, release it, confirm both clients converge, then disconnect and reconnect one client and verify recovery.
- [ ] Record for every candidate: Web export compatibility, native feasibility, end-to-end latency, reconnect behavior, behavior when the host disappears, NAT traversal and any TURN or relay need, signaling requirements, dependency size and maintenance health, code volume behind the boundary, reliable commands versus high-rate unreliable updates, encryption assumptions, third-party infrastructure dependence, operating cost, and behavior with 2, 3 and 4 peers. Choose from the proof, not from feature lists.
- [ ] A candidate is viable only if two browser clients join one session, commands reach the authority, accepted state replicates with low latency, leases prevent conflicting control, peers converge, reconnect has a clear path, no heavy dedicated realtime server is needed, and provider code stays in a small adapter.
- [ ] Evaluate optional LAN discovery separately from Internet transport.
- [ ] The spike ends with a short decision record: versions tested, proof results, measured limits, the chosen transport (or the decision to use Firebase listeners), required infrastructure, browser and native support, the adapter API that becomes `RealtimeTransport`, and a migration plan away from polling. Until it exists no candidate is part of the canonical architecture.

## Agent-readable Web

Design is in `README.md` (Agent-readable Web and AI).

- [ ] Semantic snapshot contract in the runtime plus a read-only JavaScript bridge: viewer, session and package identity, filtered visible objects, UI mode and selection, a minimal control descriptor.
- [ ] Links and metadata from the Web shell to public agent and project documentation; Playwright E2E consumes semantic state as well as screenshots.
- [ ] Expose lifecycle, turn, active player, result, event summary and legal actions from the same validator the human UI uses; spectator view; versioned rules and package references instead of embedded rules.
- [ ] Later: well-known agent descriptor, public rules, manual and capability resources per package, MCP projection, AI participant seats, AI-assisted GamePackage authoring.

## Session history and verification

- [ ] Checkpoints and restore for match sessions: checkpoints at setup, turn start and host save; a host-only restore verb that records `session.restored`; restore must cover objects, hands, ownership, counters, deck order, turn and phase, permissions, active player and random state.
- [ ] Display camera modes: Overview, a smart focus camera driven by domain events, and an optional manual or cinematic mode.
- [ ] Player avatar rig for presence (head, pointer, optional hands); today only presence markers exist.
- [ ] End-to-end scenario test: two phones join, the TV renders, each phone navigates its own camera, A picks up an owned object, moves the camera and places it elsewhere, the TV smart camera frames it, A transfers a neutral resource to B, every command is recorded, the host restores the turn-start checkpoint and all clients converge.

## MCP / external agents

Design and the current DEV prototype are in `README.md` (MCP prototype, GitHub Jobs bridge). Phase 10 stays open until MCP and human commands use one validation path and emit the same events.

- [ ] Keep `SessionCommandBridge` separate from `RealtimeTransport`.
- [ ] Route MCP tools through domain commands; never mutate Firebase rows, transport state, or Godot scene nodes directly.
- [ ] Add stable `command_id`, `session_id`, `actor_id`, expiry, result status, idempotency, and deduplication to external commands.
- [ ] Keep Firebase HTTPS Functions as the initial public MCP endpoint even if realtime gameplay leaves RTDB.
- [ ] The DEV MCP endpoint has no authentication yet and is not fit for PROD. Before broader access: pairing (a one-time short-lived code or QR, separate from the public join code, binding session, participant, seat, role, capabilities and expiry, revocable by the host), an identity adapter (Firebase Auth or another provider plus OAuth for persistent authorization, with per-session pairing choosing seat and capabilities), rejecting `dev_direct_no_auth` outside DEV, and private-state filtering before data reaches MCP.
- [ ] Require an expected state revision on MCP mutations (the core envelope supports `expected_revision`; the MCP path does not require it yet) and audit actor, command, result and emitted events.
- [ ] Separate game identity from session identity in the Firebase path and pin package ID, version and hash per session.
- [ ] Multi-host claiming; today a write times out when no host client is open.
- [ ] Remove the legacy creation and move tool aliases and any console compatibility syntax, per the prototype contract policy of keeping one canonical path.
- [ ] Confirm which game ID the deployed function binds (the code default is TEST002).

## Concurrency / authority

- [ ] Implement host-authoritative interaction leases shared by Structured and Sandbox modes.
- [ ] Structured mode applies RuleAuthority plus InteractionAuthority.
- [ ] Sandbox bypasses RuleAuthority but never InteractionAuthority.
