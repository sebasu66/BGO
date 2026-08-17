# BGO Agent Development Contract

Read this file before modifying BGO. It is the short operational contract for AI coding agents and human contributors.

For the staged implementation plan, read `docs/IMPLEMENTATION_ROADMAP.md`. For deeper product rationale, read `docs/PROJECT_VISION.md` only when the task requires it.

## Project goal

BGO is a Godot-based virtual tabletop runtime for turn-based board games. One logical session can be viewed by Web, mobile, TV, desktop, and later MCP clients. Clients may render the same logical object differently.

## Non-negotiable architecture boundaries

1. **BGO Core is not a game.** Real games are external declarative packages/mods.
2. **Game packages do not define component internals.** They reference stable component IDs and allowed configuration.
3. **Do not reference internal `.gd` or `.tscn` paths from external game definitions.** Resolve implementations through the component registry.
4. **Do not execute arbitrary remote GDScript from game packages.** External packages are untrusted/declarative content.
5. **Domain state must not depend on rendering.** Camera, meshes, UI, lighting, billboards, etc. are representations only.
6. **Domain rules must not depend directly on Firebase.** Networking/persistence belongs behind adapters/repositories.
7. **Synchronize logical game objects, not graphics.** Different clients may choose different representations.
8. **Prefer logical slots/zones over arbitrary Vector3 positions.** Free-form positioning is an explicit future capability.
9. **Hand and PlayerArea are distinct concepts.** Do not collapse them into a generic held collection.
10. **Owner, holder/controller, location, and visibility are separate concepts.** Neutral ownership must remain representable.
11. **Secrets are not protected by render layers.** Private information eventually requires per-client state filtering.
12. **MCP operates on logical concepts and validated commands, never raw Godot nodes.**

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

## Testing and quality expectations

Before considering a change complete, preserve a clean quality gate:

- formatting/lint checks
- project structure checks
- architecture/dependency checks
- Godot headless import/parse
- unit/domain tests
- relevant conformance fixture tests
- Web export smoke test

Objective violations may block CI. Heuristic smells may initially warn rather than fail.

Do not optimize for SOLID ceremony. Optimize for clear responsibilities, low coupling, testability, readable code, and explicit dependencies.

## Current implementation sequence

Do not jump ahead without a reason. Current order is:

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

If a requested feature belongs to a later phase, document it rather than pulling all of its implementation forward.

## Firebase constraints for the current prototype

Firebase is currently coordination/persistence infrastructure, not the game engine.

For the existing prototype:

- project ID: `board-game-online-68c3f`
- Web build output: `build/web/index.html`
- deploy Hosting only with `firebase deploy --only hosting`
- do NOT deploy production database rules while the prototype intentionally uses temporary Test Mode

Never replace this with a plain unrestricted `firebase deploy` unless the deployment policy is explicitly changed.

## Agent workflow

For each task:

1. Inspect the current branch/files before modifying them.
2. Identify the active roadmap checkpoint.
3. Make the smallest coherent vertical change.
4. Preserve architecture boundaries above.
5. Add/update tests for new public behavior.
6. Update docs when a contract or roadmap decision changes.
7. Do not silently introduce a second competing abstraction for an existing concept.
8. Do not hide migration/schema errors; fail safely with precise messages.
9. Do not destructively reset existing session state merely to accommodate a schema addition.
10. Leave the repository in a state that can pass the quality gate.

When uncertain, prefer a smaller reversible implementation that preserves the public contracts.
