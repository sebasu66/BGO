# BGO Agent Development Contract

Read this file before modifying BGO. It is the short operational contract for AI coding agents and human contributors.

For the staged implementation plan, read `docs/IMPLEMENTATION_ROADMAP.md`. For the public-facing web application, read `docs/WEB_PLATFORM.md`. For branch/deployment rules, read `docs/DEPLOYMENT_ENVIRONMENTS.md`. For the project health overview contract, read `docs/PROJECT_STATUS_DASHBOARD.md`. For deeper product rationale, read `docs/PROJECT_VISION.md` only when the task requires it.

## Project goal

BGO is a Godot-based virtual tabletop runtime for turn-based board games, surrounded by a separate web product surface for onboarding, catalog, session launch, account management later, and administration later. One logical session can be viewed by Web, mobile, TV, desktop, and later MCP clients. Clients may render the same logical object differently.

## Non-negotiable architecture boundaries

1. **BGO Core is not a game.** Real games are external declarative packages/mods.
2. **The public web platform is not the game runtime.** Product/catalog/session workflows belong in the web app; gameplay rendering and interaction belong in Godot clients.
3. **Game packages do not define component internals.** They reference stable component IDs and allowed configuration.
4. **Do not reference internal `.gd` or `.tscn` paths from external game definitions.** Resolve implementations through the component registry.
5. **Do not execute arbitrary remote GDScript from game packages.** External packages are untrusted/declarative content.
6. **Domain state must not depend on rendering.** Camera, meshes, UI, lighting, billboards, etc. are representations only.
7. **Domain rules must not depend directly on Firebase.** Networking/persistence belongs behind adapters/repositories.
8. **Synchronize logical game objects, not graphics.** Different clients may choose different representations.
9. **Prefer logical slots/zones over arbitrary Vector3 positions.** Free-form positioning is an explicit future capability.
10. **Hand and PlayerArea are distinct concepts.** Do not collapse them into a generic held collection.
11. **Owner, holder/controller, location, and visibility are separate concepts.** Neutral ownership must remain representable.
12. **Secrets are not protected by render layers.** Private information eventually requires per-client state filtering.
13. **MCP operates on logical concepts and validated commands, never raw Godot nodes.**
14. **Do not prematurely introduce auth/billing complexity.** Authentication is a later web checkpoint; monetization comes only after the commercial model is explicitly selected.
15. **Future billing/entitlement state must not be trusted from clients.** Provider secrets and authoritative commercial state belong server-side.
16. **Web, Godot, and future native clients share contracts, not implementation details.** Do not invent incompatible session/package/identity schemas per client.
17. **DEV and PROD are separate release channels.** `develop` may deploy DEV; only an explicit owner-approved promotion may advance the stable `main`/PROD build.
18. **Project health must stay visible.** Material checkpoint changes, blockers, implementation-order changes, and quality risks must be reflected in the project status dashboard data/documentation.

## Layering

Preferred dependency direction:

```text
BGO Core domain
    ↓
Component contracts / component library
    ↓
Game package definitions

Networking adapters consume domain results.
Rendering consumes domain state.
Neither networking nor rendering decides game legality.
```

The public web platform consumes stable session/package contracts and later identity/entitlement contracts, but must not duplicate gameplay-domain rules in frontend code.

A useful design target is:

```text
State + Command -> New State + Events
```

Keep domain operations pure or close to pure whenever practical.

## Game packages

Core conformance games may be versioned under tests/fixtures, but they MUST use the same `GamePackage` contract that external mods use.

Real games are not bundled/versioned as part of BGO Core.

A package should eventually contain or reference:

- manifest/package metadata
- game definition
- locales
- logical asset manifest
- optional remote asset sources

Sessions should pin package ID, version, and definition/content hash.

## Components

Every public component must have a stable ID such as:

```text
bgo.board.checkered
bgo.piece.basic_cylinder
bgo.slot.basic
bgo.card.basic
bgo.deck.standard
```

A public component should eventually have:

- implementation owned by its component folder/module
- defaults/config contract
- validation
- focused tests
- at least one conformance game exercising meaningful public capabilities

Adding a component should not require large `match component_id` switches throughout the core. Extend the registry/contract instead.

## Assets and rendering

Game logic references logical asset IDs rather than scattered URLs.

Planned representation types include:

- high-detail 3D mesh
- low-detail 3D mesh
- multi-angle billboard
- top-down sprite
- icon/thumbnail

Do not implement all representation modes prematurely. Follow the roadmap checkpoints.

Remote assets must eventually be validated and cached. A large or invalid model must not be allowed to destroy Web/mobile performance merely because a mod references it.

## Web platform

The public-facing web application is developed as a parallel track. It may use conventional web tooling or AI-assisted builders, but it must preserve shared contracts.

Current early responsibilities include:

- landing/product explanation
- catalog/discovery
- create/join/resume session UX
- device-role selection and runtime launch

Registration/login/account management is a later checkpoint. Billing/ads/paid plans are deferred until a commercialization model is selected.

Keep secrets server-side. Do not put gameplay legality into the web frontend. Launch Godot using explicit session/package/context rather than hidden coupling.

## Project status dashboard

The development overview lives under `web/project-status/` and is documented in `docs/PROJECT_STATUS_DASHBOARD.md`.

Rules:

- `docs/IMPLEMENTATION_ROADMAP.md` remains the authoritative roadmap.
- `web/project-status/status.json` is the operational projection shown by the dashboard.
- do not mark a checkpoint complete merely because code exists; use its exit criteria.
- update dashboard status when a checkpoint completes, a material blocker/risk is discovered or resolved, or implementation order changes.
- Phase 1 CI should inject transient test/build results without requiring generated CI state to be committed back to Git.
- DEV and PROD dashboards must identify their own commit/environment once separate deployments exist.

## DEV / PROD release policy

Follow `docs/DEPLOYMENT_ENVIRONMENTS.md`.

Intended steady state:

```text
feature/* -> develop -> [manual owner promotion] -> main
```

Rules:

- DEV and PROD remain separately accessible.
- `develop` is the integration source for DEV.
- `main` is the stable source for PROD.
- AI agents and CI must never autonomously promote DEV to PROD.
- a normal `develop` push must not overwrite PROD.
- both environments must identify the Git commit they run.
- environment-specific Firebase/config values belong in explicit configuration, not domain logic.
- Firebase recommends separate projects for true DEV/PROD backend isolation; multiple Hosting sites in one project do not isolate RTDB/Auth/Storage.

During the prototype, `PROD` means the manually chosen stable/public build, not that all production security/commercial systems are complete.

## Testing and quality expectations

Before considering a change complete, preserve a clean quality gate:

- formatting/lint checks
- project structure checks
- architecture/dependency checks
- Godot headless import/parse
- unit/domain tests
- relevant conformance fixture tests
- Web export smoke test
- web-platform tests for important session flows; auth tests once auth exists

Objective violations may block CI. Heuristic smells may initially warn rather than fail.

Do not optimize for SOLID ceremony. Optimize for clear responsibilities, low coupling, testability, readable code, and explicit dependencies.

## Current implementation sequence

Do not jump ahead without a reason. Core runtime order is:

1. stabilize the current PoC
2. CI/lint/tests/headless Web export
3. finish slots/zones/ownership/commands/transfers
4. formalize external GamePackage
5. grow focused conformance games
6. remote asset resolver/cache/streaming
7. asset validation and platform budgets
8. multiple visual representations
9. top-down renderer
10. photobooth/authoring pipeline
11. MCP logical control MVP

In parallel, the Web Platform may progress through its own checkpoints documented in `docs/WEB_PLATFORM.md`, as long as it does not force premature changes to unstable core contracts.

If a requested feature belongs to a later phase, document it rather than pulling all of its implementation forward.

## Firebase constraints for the current prototype

Firebase is currently coordination/persistence infrastructure, not the game engine.

For the existing prototype:

- project ID: `board-game-online-68c3f`
- Web build output: `build/web/index.html`
- project status source: `web/project-status/`
- project status Firebase path after sync/deploy: `/project-status/`
- sync dashboard after Web export with `./scripts/sync_project_status.ps1`
- deploy Hosting only with `firebase deploy --only hosting`
- do NOT deploy production database rules while the prototype intentionally uses temporary Test Mode

Never replace this with a plain unrestricted `firebase deploy` unless the deployment policy is explicitly changed.

When DEV/PROD targets are added, deployment commands/workflows must name their destination explicitly and make accidental PROD deployment difficult.

## Agent workflow

For each task:

1. Inspect the current branch/files before modifying them.
2. Identify the active roadmap checkpoint and product surface (core runtime vs web platform vs shared contract).
3. Make the smallest coherent vertical change.
4. Preserve architecture boundaries above.
5. Add/update tests for new public behavior.
6. Update docs when a contract or roadmap decision changes.
7. Update project-status data/documentation when the task changes checkpoint status, blockers, implementation order, or material health risks.
8. Do not silently introduce a second competing abstraction for an existing concept.
9. Do not hide migration/schema errors; fail safely with precise messages.
10. Do not destructively reset existing session state merely to accommodate a schema addition.
11. Do not promote a DEV build to PROD unless the project owner explicitly requested that promotion.
12. Leave the repository in a state that can pass the relevant quality gate.

When uncertain, prefer a smaller reversible implementation that preserves the public contracts.
