# BGO — Realtime Transport Spike

Status: **planned architecture spike; not yet implemented**  
Planned branch: **`spike/realtime-transport`**, created from an integrated and green `develop` branch.  
Scope: live peer/session synchronization only. This is deliberately separate from MCP / external-agent ingress.

## Why this spike exists

The current prototype synchronizes a Firebase Realtime Database session through `GameSessionRepository`. The current implementation performs periodic REST reads of the session, historically at roughly 0.75 seconds.

That implementation is acceptable as a proof of concept, but it is not the intended long-term realtime architecture:

- polling the full session produces network traffic even when nothing changes;
- latency is bounded by the polling interval rather than by actual events;
- each connected client repeats reads independently;
- high-frequency transient interaction such as drag/pose updates is a poor fit for repeated durable-database snapshots;
- the networking mechanism becomes too easy to confuse with the authoritative game model.

BGO Core must remain independent from any one transport. Rules, permissions and game truth belong to the domain model. A transport carries commands/events/state projections; it must not decide whether a move is legal.

The spike therefore compares practical Godot transports that can synchronize active clients without requiring BGO to operate a dedicated realtime game server.

## Architectural question

Can an active BGO session use a lightweight peer/realtime transport for live traffic while keeping durable persistence independent?

Target separation:

```text
                         BGO Core
                 State + Command -> Events
                           |
                host/domain authority
                           |
          +----------------+----------------+
          |                                 |
          v                                 v
   RealtimeTransport                 Persistence
   live session traffic              durable snapshots
   WebRTC / relay                    Firebase RTDB initially
          |
          +--> connected clients
```

Firebase is therefore **not automatically removed from BGO** by this experiment.

The likely target is:

- realtime transport: active-session commands/events, interaction leases, transient drag/pose updates and fast replication;
- Firebase or another persistence adapter: durable session snapshot, recovery, asynchronous play, session catalog/metadata and other state that must survive all clients disconnecting;
- MCP / GitHub / other agent ingress: separate command bridges that submit normal domain commands and do not become the peer networking layer.

The persistence implementation may later change too, but that is a separate decision.

## Important distinction: Firebase listeners vs replacing realtime transport

There are two independent improvements:

1. **Firebase event/listener approach** — keep Firebase RTDB as the live transport but subscribe to changes instead of polling the complete session repeatedly.
2. **Realtime transport spike** — test moving active gameplay traffic away from Firebase RTDB to a peer/realtime transport.

Using Firebase listeners would already be materially better than full-session polling and is a valid fallback/intermediate implementation.

The spike exists because BGO may benefit further from keeping high-frequency gameplay traffic off the durable database entirely.

## Transport boundary

Introduce or preserve a provider-neutral concept such as:

```text
RealtimeTransport
  create_session(...)
  join_session(...)
  leave_session(...)
  send_command(...)
  publish_event(...)
  publish_transient(...)
  peer_connected
  peer_disconnected
  message_received
```

Exact method names are not fixed by this document. The important rule is that gameplay code depends on the abstraction, not directly on WebRTC, MQTT, Firebase or a plugin API.

The transport must carry canonical BGO envelopes rather than Godot scene-node state.

## Authority model for the first spike

The initial proof should be **host authoritative**, not unrestricted peer mutation.

```text
client intent
    |
    v
host receives command
    |
    v
BGO Core validates command / interaction authority
    |
    v
new logical state + events
    |
    v
host broadcasts accepted result
    |
    v
peers converge
```

Sandbox may bypass game-rule authority, but it must still enforce interaction authority/leases so two peers cannot control the same object simultaneously.

A later architecture may support authority migration or a different topology, but the spike should not solve that before basic synchronization is proven.

## Candidates to compare

The current candidate set is intentionally small and should be tested against the same proof rather than integrated deeply one by one.

### Freelay

Candidate relay/realtime solution using public relay infrastructure and WebRTC-oriented session connectivity. Evaluate how much infrastructure it removes, Web compatibility, reconnect behavior and whether its public-relay assumptions are acceptable for BGO.

### WebRTC Piggyback

Candidate WebRTC approach intended to avoid operating a dedicated BGO signaling/matchmaking server by piggybacking on distributed/public signaling infrastructure. Evaluate NAT traversal, dependency weight, browser/native parity and operational assumptions.

### Tube

Candidate Godot-friendly P2P/WebRTC session layer. Evaluate API simplicity, browser support, signaling requirements, reconnect/host behavior and how cleanly it can sit behind `RealtimeTransport`.

### Native WebRTC support

Godot Web has browser WebRTC available through the platform. Native desktop/mobile clients may require an appropriate native WebRTC extension. This must be included in the comparison because BGO targets both browser and native clients.

Candidate names are not architecture commitments. If a candidate is abandoned or replaced, update this document and preserve the same test contract.

## Where the experiment happens

Do **not** implement the experiment on `develop` or on an unrelated feature branch.

Create:

```text
spike/realtime-transport
```

from a known-green integrated `develop`.

The spike is disposable. It may contain temporary adapter code and instrumentation that would not be acceptable in production. The purpose is to generate evidence for a transport decision.

Only the chosen abstraction/implementation should later be integrated through a normal feature/PR flow.

## Minimal proof

Use the same two-client/browser test for every candidate.

```text
Client A (host)                  Client B
      |                              |
      +------ create / join ---------+
      |                              |
      +------ acquire object -------->
      |                              |
      +------ drag / transient ------>
      |                              |
      +------ commit move ----------->
      |                              |
      +------ release object -------->
      |                              |
      +<----- same final state ------+
```

Required proof steps:

1. Create a session.
2. Join from a second client.
3. Confirm peer identity/connectivity.
4. Acquire/lease one component.
5. Move/drag it with transient updates.
6. Commit a canonical logical move.
7. Replicate resulting state/event to the other peer.
8. Release the component.
9. Confirm both clients converge to the same logical state.
10. Disconnect/reconnect one client and verify recovery behavior.

The proof should use BGO logical object IDs and commands, not direct node transforms as authoritative state.

## Measurements

Record the same measurements for every candidate:

- browser/Web export compatibility;
- native feasibility;
- end-to-end update latency;
- reconnect behavior;
- behavior when the host disappears;
- NAT traversal and whether TURN or other relay infrastructure is required;
- signaling requirements;
- dependency/plugin size and maintenance health;
- implementation/code volume behind `RealtimeTransport`;
- ability to send reliable commands/events;
- ability to send high-rate transient/unreliable updates if useful;
- security/encryption assumptions;
- public third-party infrastructure dependencies;
- operational cost to BGO;
- behavior with 2, 3 and 4 peers if practical.

Do not choose a transport from feature lists alone. Choose from this proof and measurements.

## Success criteria

A candidate is viable if it can demonstrate all of the following without coupling domain rules to the provider:

- two browser clients join the same BGO session;
- canonical commands reach the authority client;
- accepted state/events replicate with perceptibly low latency;
- object interaction leases prevent conflicting simultaneous control;
- peers converge deterministically after an accepted move;
- reconnect has a clear recovery path;
- the solution does not require BGO to operate a heavy dedicated realtime game server;
- the provider-specific code remains behind a small transport adapter.

## Failure / fallback paths

If none of the P2P/relay candidates is sufficiently reliable, BGO should not retain full-session REST polling as the fallback.

Preferred fallback order:

1. Firebase RTDB realtime listeners/subscriptions for live state;
2. a lightweight managed relay/realtime service behind `RealtimeTransport`;
3. only then reconsider a dedicated BGO realtime service if product requirements justify it.

Periodic polling may remain for a transport that inherently requires it (for example the current GitHub Jobs bridge), but it must be scoped to that transport, enabled only while needed, and must not poll the complete gameplay session as the normal synchronization mechanism.

## Relationship to GitHub Jobs / MCP

`RealtimeTransport` and external AI command transport are separate interfaces.

```text
peer/player traffic ---> RealtimeTransport ---+
                                             |
MCP/GitHub agent ---> SessionCommandBridge ---+--> domain command authority
                                             |
                                             +--> logical state/events
```

An AI command must go through the same validation and authority path as a human command. GitHub, MCP or Firebase must never gain a second set of gameplay semantics.

The GitHub Jobs bridge may continue using a lease plus polling because GitHub itself is not a realtime peer transport. That does not justify polling Firebase for ordinary gameplay.

## Relationship to persistence and asynchronous play

A session must survive all peers disconnecting. Therefore a pure ephemeral P2P mesh is not, by itself, sufficient as BGO persistence.

Before peers disappear, authoritative durable state must be persisted through the persistence abstraction. A returning client can recover a durable snapshot and then rejoin/reform the realtime session.

This separation also allows asynchronous turn-based games: no active peer mesh is required while everyone is offline.

## Decision output of the spike

The spike is complete only when it produces a short decision record containing:

- candidate versions tested;
- proof results;
- measured limitations;
- chosen transport or explicit decision to use Firebase listeners instead;
- required infrastructure such as signaling/TURN/relay;
- browser/native support decision;
- adapter API that will become the canonical `RealtimeTransport` boundary;
- migration plan away from the current full-session polling implementation.

Until that decision exists, no candidate plugin is considered part of BGO's canonical networking architecture.
