# MCP prototype contract

## Current boundary

BGO currently has one development session namespace (`TEST001`) and no user
authentication. The initial integration therefore declares the explicit
`dev_direct_no_auth` policy in `src/mcp/mcp_prototype_access_policy.gd`.

This is local/DEV behavior, not production authentication. One persistent MCP
server serves every game session; a server is not created per match. Its bound
context contains session ID, participant ID and role.

The developer console and MCP are separate adapters over the same typed logical
command API:

```text
Developer Console ─┐
                   ├─> BGO logical command API -> validated state + events
Remote MCP Server ─┘
```

The MCP does not invoke console command strings, expose Godot nodes, or mutate
game objects directly. Transport permission checks never replace domain
validation. Mutations are written as pending commands; the active Godot host
reconstructs logical state, calls `BgoMcpGameApi`, and atomically persists the
accepted object projection plus command result.

## Canonical API vocabulary

The intentional public API is organized under `Game.*` for definition data,
`Match.*` for current-match state/actions, and `System.*` for runtime
capabilities and discovery. Entity methods use flat camelCase names such as
`getName`, `setName`, `isActive` and explicit action verbs. Public constants use
flat `System.constants.UPPER_SNAKE_CASE` names. The canonical callable syntax is
Python-like: `Game.Player.create()`, `Match.piece_1.getOwner()` and
`System.api.describe("Game.Player")`. Legacy `G.*` symbols and whitespace-style
console commands are compatibility adapters, not the public contract.

The developer console implements the first descriptor-driven vertical slice
and a restricted fluent game-definition builder. MCP now exposes the same
canonical `Game.*`, `Match.*` and `System.*` vocabulary through a compact entity
API. MCP requests remain structured tool arguments and never evaluate console
command strings.

The four primary discovery/control tools are:

- `bgo_get_entities`: lists authorized canonical entity paths and commands.
- `bgo_get_properties`: returns values, writable schema and commands.
- `bgo_set_properties`: changes only properties declared writable by the schema.
- `bgo_execute`: executes only registered domain commands for that entity.

Example flow:

```text
bgo_get_entities()
bgo_get_properties(entity="Match.objects.miniature_1")
bgo_set_properties(
  entity="Match.objects.miniature_1",
  changes={"visibility":"owner_only"}
)
bgo_execute(
  entity="Match.objects.miniature_1",
  command="moveToPoint",
  arguments={"x":5,"y":2}
)
```

This is not a generic reflection endpoint. Property names are allowlisted,
configuration is validated by the component registry, and command names must
be advertised for the target entity. Raw Godot nodes, arbitrary method names,
scene paths and Firebase paths are never accepted.

## Games and sessions

One active session does not imply one hard-coded game. BGO can load different
declarative definitions from `games/<game-id>/game.jsonh`. The prototype still
uses game ID in its Firebase path, so game and session identity are not fully
separated yet.

The target session pins:

```text
session_id
game_package_id
game_package_version
game_package_hash
```

This permits multiple sessions of one package and different games without
changing BGO Core.

## Prototype flow

1. Configure the BGO MCP endpoint once in the MCP client.
2. Bind DEV access to `TEST001`, a participant and a role.
3. Read the authorized session projection and available actions.
4. Submit mutations through the Firebase command queue.
5. Keep one Godot host client open so it can validate and apply pending commands.

## Remote DEV server

The remote transport is a stateless Streamable HTTP MCP server implemented as
the Firebase Function `bgoMcpDev` under `backend/functions/`. It exposes:

- context, definition, session and grid reads
- object inspection and point queries
- canonical entity discovery and property schemas
- validated generic property updates
- registered entity command execution
- host-only sandbox creation from the package catalog
- host-only movement by logical grid point

The expected endpoint after deployment is:

```text
https://us-central1-board-game-online-68c3f.cloudfunctions.net/bgoMcpDev/mcp
```

The non-secret DEV binding used by non-interactive deploys is explicit in
`backend/functions/.env.board-game-online-68c3f`. Production must never reuse this
`dev_direct_no_auth` host binding.

The health route is the same URL ending in `/health`. The function is deployed
without RTDB rules and without Hosting by this explicit command:

```text
firebase deploy --only functions:bgo-mcp-dev:bgoMcpDev --project board-game-online-68c3f
```

Pushes to `develop` run the complete quality gate. They deploy this function
only when the repository variable `BGO_MCP_DEPLOY_ENABLED` is `true`; pull
requests only build and test it. Firebase Hosting DEV remains independent and
`main`/PROD is never promoted by this workflow.

The owner enabled the required Firebase plan on 2026-08-24. Version 0.2.0 was
then deployed successfully and verified through `/health`, MCP `initialize`,
`tools/list`, live entity discovery, and a completed property command consumed
by a Godot host. Artifact Registry retains build images for seven days.

## First logical API slice

`BgoMcpGameApi` is the transport-neutral first slice. It exposes definition and
authorized state, complete grid state, entity/property discovery, validated
property updates, registered commands, host sandbox creation from the package
catalog, and validated grid movement.
Coordinates are logical table points; MCP never needs camera or world-space
coordinates.

`BgoMcpCommandProcessor` is the Firebase/Godot adapter for legacy create/move
tools and the compact `set_properties`/`execute` write tools. It intentionally
supports host mutations only in the remote no-auth prototype. The underlying
logical API distinguishes host and owner capabilities; remote owner bindings
require pairing/authentication before they can safely be enabled.

## Current limitations

- `dev_direct_no_auth` means anyone who receives the endpoint can act as its
  configured host. Do not publish it as a production connector.
- There is one fixed session and host binding per deployment.
- A write returns `timeout` if no host client is open; the pending command can
  still be consumed when the host reconnects.
- The prototype assumes one active host authority. Multi-host claiming and
  expected-revision conflict detection are deferred.
- Definition, private-state filtering, pairing, revocation and OAuth must be
  completed before broader access.

## Migration

### Pairing

- Lobby creates a one-time short-lived code or QR.
- Pairing code is separate from the public join code.
- It binds session, participant, seat, role, capabilities and expiry.
- Host can revoke the binding.

### Identity

- Add Firebase Auth or another provider behind an identity adapter.
- Add OAuth for persistent account authorization.
- Keep per-session pairing to select the current seat/capabilities.
- Reject `dev_direct_no_auth` outside DEV.

### Authoritative commands

- Put command validation behind a shared/server-side domain boundary.
- Require expected state revision for mutations.
- Audit actor, command, result and emitted events.
- Filter hidden information before it reaches MCP.

Roadmap Phase 10 remains incomplete until MCP and human commands use the same
validation path and produce the same events.
