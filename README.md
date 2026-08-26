# BGO

BGO is a reusable virtual tabletop runtime built with Godot 4.7.1. BGO Core is not a bundled board game: games are declarative packages that describe components, setup, state and rules against stable BGO contracts.

The same logical session can be viewed from a shared display/TV, a player phone/browser, desktop clients and future agent/MCP clients. Rendering is a projection of authoritative logical state; it is not the source of truth.

## Current project truth

Keep current project state deliberately small:

- `README.md` - product/architecture overview and repository map.
- `TODO.md` - current work, blockers and next implementation steps.
- `SKILL.md` - coding-agent engineering contract, workflow and machine-enforced conventions.

Files under `docs/`, plus `AGENTS.md`, `AI_BACKLOG.md` and `CHANGES.md`, are useful reference/history but must not become competing current-state sources.

Contributors and coding agents must read `SKILL.md` before modifying the project.

## Repository structure

```text
BGO/
|-- src/
|   |-- runtime/        # client runtime, composition and bgo_client.tscn
|   |-- core/           # domain state, definitions, registries and command API
|   |-- components/     # reusable tabletop/UI components + component.jsonh
|   |-- network/        # persistence/realtime adapters and repositories
|   |-- ui/             # reusable client-side UI controllers
|   |-- mcp/            # MCP/domain command projection
|   |-- debug/          # runtime diagnostics still required by current autoloads
|   |-- authoring/      # authoring-only; excluded from Web runtime export
|   |-- editor/         # editor-only; excluded from Web runtime export
|   `-- demo/           # demonstrations/prototypes only
|-- games/              # declarative GamePackages / fixtures
|-- assets/
|   |-- source/         # original sources; ignored by Godot and not shipped
|   |-- authoring/      # authoring library; excluded from Web
|   `-- runtime/        # assets intentionally shippable with the runtime
|-- addons/             # installed Godot runtime/editor plugins
|-- backend/
|   `-- functions/      # Firebase HTTPS Functions, including the MCP endpoint
|-- hosting/            # static Firebase Hosting source surfaces
|-- examples/           # third-party/reference examples; ignored by Godot
|-- scripts/            # development/build/deploy tooling
|-- tests/              # automated tests; not shipped in the Web PCK
|-- docs/               # design/history/reference material
|-- fastlane/           # Android/store/release metadata
|-- build/              # generated export output; gitignored
`-- artifacts/          # generated browser/CI evidence; gitignored
```

`examples/.gdignore` prevents downloaded examples from entering the active Godot project. `assets/source/.gdignore` does the same for original source material such as Blender files. `assets/authoring/` may remain importable in the editor/authoring application but is excluded from the Web export; `assets/runtime/` is the place for resources intentionally shipped to clients.

## Runtime entry point

`project.godot` starts `src/runtime/bgo_client.tscn`, whose root script is `src/runtime/bgo_client_runtime.gd`.

The historical production code under `src/demo/main_*` was moved to `src/runtime/` and split into policy-sized responsibility layers:

```text
client_runtime_base
  -> client_runtime_state_sync
  -> client_runtime_interaction
  -> client_runtime_composition
  -> client_runtime_gameplay
  -> client_runtime_camera
  -> bgo_client_runtime
```

This chain is a migration seam, not a pattern to extend. New camera, networking, shell, session, interaction and UI responsibilities should preferentially become focused controllers/services composed by the runtime instead of adding another orchestration inheritance layer.

Runtime inheritance is one-way: a parent layer may call only methods declared by itself or an ancestor. It must never depend on a method first introduced by a child. After moving or renaming GDScript files, or changing class_name/inheritance, validate once from a clean .godot cache because stale class metadata can hide an invalid dependency direction.

`Logical_client_runtime.gd` contains the structured logical-session path while that path is integrated deliberately.

## Runtime rules

BGO supports two product modes:

- **Structured games:** domain rules, turns, ownership and legal commands are enforced.
- **Sandbox:** turn/rule restrictions are bypassed, but interaction authority is not. Concurrent clients still need acquire/lease/release semantics so two users cannot manipulate the same component simultaneously.

`Hand` and `PlayerArea` are separate concepts. Owner, holder/controller, location and visibility are also separate state dimensions.

Game packages reference stable component IDs such as `bgo.<family>.<name>`; they do not reference internal `.gd` or `.tscn` implementation paths.

## Web export boundary

The Web PCK is a runtime artifact, not a copy of the repository.

It includes runtime/core/components/UI/network/MCP resources required by the client, required runtime add-ons, declarative `games/*/*.jsonh`, the runtime capability catalog `src/capabilities/*.jsonh`, and component `component.jsonh` contracts.

It excludes generated output, docs, examples, source/authoring assets, backend functions, development scripts, tests, static hosting sources, authoring/editor code and editor-only add-ons.

`src/debug/` is not excluded yet because `project.godot` still autoloads `BgoGameCommandConsole`; remove or conditionalize that dependency before excluding debug code.

Sandbox is part of the Web runtime. Authoring/editor tooling is not.

JSON/JSONH files loaded with `FileAccess` must be explicitly covered by the export preset and verified in the generated `index.pck`.

## Networking and MCP boundary

Realtime gameplay transport and external AI commands are separate concerns:

```text
RealtimeTransport          SessionCommandBridge
(peer gameplay)            (HTTPS/MCP ingress)
        \                    /
         -> host/domain command authority
                    |
             canonical logical state
```

MCP tools operate on domain concepts such as `piece.move`, `deck.shuffle` and `game.get_state`; they never directly mutate Firebase rows, WebRTC/MQTT peers or Godot scene nodes. The host validates accepted commands and broadcasts resulting state/events.

Firebase Functions can continue hosting the public HTTPS MCP endpoint even if high-frequency gameplay later moves away from Firebase RTDB.

The current full-session Firebase REST polling is a prototype mechanism, not the target realtime architecture. The planned comparison of Firebase realtime listeners versus peer/realtime transports, including Freelay, WebRTC Piggyback and Tube, is documented in [`docs/REALTIME_TRANSPORT_SPIKE.md`](docs/REALTIME_TRANSPORT_SPIKE.md). The experiment must occur on the disposable `spike/realtime-transport` branch created from a green integrated `develop` branch.

## Development flow

```text
feature branch
      |
      v
   develop
      |
      v
Firebase DEV + remote E2E

main = PROD only by explicit owner promotion
```

The integration Quality Gate covers protected project policy, structure, GDScript format/lint, Godot import/parse, core tests, validated Web export, browser E2E and DEV deployment checks.

Godot can return process exit code 0 while its log still contains SCRIPT ERROR: Parse Error: or Failed to load script. Project import/export checks must scan for those signatures instead of trusting only the process code. Execution errors emitted solely by explicitly editor-only add-ons such as asset_placer are classified separately and do not justify widening the Web PCK.

Do not stage incidental `.godot`, `.import` or newly generated `.gd.uid` noise. Generated `build/`, `artifacts/` and `.firebase/` content is not source.

Copilot Cloud project-audit automation is disabled because the project is not using that paid capability. A future local agent may perform repository-wide advisory analysis.

## Technology baseline

- Godot `4.7.1-stable`
- Node.js `22` in CI
- Playwright version pinned by `package.json`
- Firebase project `board-game-online-68c3f`
- Firebase Functions source `backend/functions/`
- Static Hosting source `hosting/`
- Web build output `build/web/`
