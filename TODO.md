# TODO

## Current integration

- [ ] Complete the local Quality Gate for the runtime/root-structure refactor.
- [ ] Commit and push the validated PR #21 changes to `feature/reactive-ui`.
- [ ] Get PR #21 green in GitHub Actions and merge it into `develop`.
- [ ] Verify the Firebase DEV deployment and deployed browser E2E.
- [ ] Reconcile the primary local `C:/DEV/BGO` worktree with the integrated `develop` state after deployment.

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

## Realtime networking

Architecture and rationale: [`docs/REALTIME_TRANSPORT_SPIKE.md`](docs/REALTIME_TRANSPORT_SPIKE.md).

- [ ] Create a disposable `spike/realtime-transport` from the integrated `develop` branch.
- [ ] Define the minimal `RealtimeTransport` abstraction without coupling game rules to a provider.
- [ ] Compare Freelay, WebRTC Piggyback, and Tube with the same two-browser proof.
- [ ] Proof: create/join session, acquire one component, drag it, publish transient pose, release it.
- [ ] Measure Web compatibility, latency, reconnect behavior, host loss, NAT/TURN needs, dependency weight, and code volume.
- [ ] Evaluate optional LAN discovery separately from Internet transport.
- [ ] Do not treat full-session REST polling as the target architecture; Firebase realtime listeners are the fallback/intermediate option if the transport spike does not replace RTDB live traffic.

## MCP / external agents

- [ ] Keep `SessionCommandBridge` separate from `RealtimeTransport`.
- [ ] Route MCP tools through domain commands; never mutate Firebase rows, transport state, or Godot scene nodes directly.
- [ ] Add stable `command_id`, `session_id`, `actor_id`, expiry, result status, idempotency, and deduplication to external commands.
- [ ] Keep Firebase HTTPS Functions as the initial public MCP endpoint even if realtime gameplay leaves RTDB.

## Concurrency / authority

- [ ] Implement host-authoritative interaction leases shared by Structured and Sandbox modes.
- [ ] Structured mode applies RuleAuthority plus InteractionAuthority.
- [ ] Sandbox bypasses RuleAuthority but never InteractionAuthority.
