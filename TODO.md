# TODO

## Current integration

- [ ] Complete the local Quality Gate for the runtime/root-structure refactor.
- [ ] Commit and push the validated PR #21 changes to `feature/reactive-ui`.
- [ ] Get PR #21 green in GitHub Actions and merge it into `develop`.
- [ ] Verify the Firebase DEV deployment and deployed browser E2E.
- [ ] Reconcile the primary local `C:/DEV/BGO` worktree with the integrated `develop` state after deployment.

## Runtime architecture

- [ ] Continue replacing the transitional `client_runtime_*` inheritance seam with focused composed controllers/services when responsibilities change.
- [ ] Deliberately integrate or retire `logical_client_runtime.gd`; do not leave competing runtime entry paths.
- [ ] Remove or conditionalize the debug console autoload before excluding `src/debug/` from Web builds.
- [ ] Validate the `assets/source`, `assets/authoring`, and `assets/runtime` workflow with real authoring assets.

## Miniature import and rendering profiles

- [ ] Complete the Dracula source pipeline from `assets/MINIS/dracula.fbx`; keep FBX as authoring/source input and do not treat the derived GLB as the source of truth.
- [ ] Verify FBX import/processing produces an optimized high-quality GLB plus an explicit desktop-standard LOD GLB, with measurable validation results and clear failure reporting.
- [ ] Verify base-pivot placement and billboard calibration from the turntable frames, including scale, bottom alignment, facing direction and per-frame offsets.
- [ ] Verify TEST002 loads Dracula through the miniature component and its representation manifest in a live Godot runtime; local file/import checks alone are insufficient.
- [ ] Define the client profile contract after the miniature slice is verified: Windows native selects configurable high-quality 3D/free camera; Web and Mobile select responsive constrained billboard/2D representations with fixed-height/fixed-pitch perspective cameras; every platform exposes orthographic tactical pan/zoom/top-down rendering.
- [ ] Keep generated portrait avatars in the later authoring/import output contract; do not add them to gameplay state.
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
