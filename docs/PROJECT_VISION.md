# BGO — Project Vision & Architecture

## 1. Idea

BGO is a Godot-based online virtual tabletop platform designed primarily for turn-based board games.

The core experience is meant to work naturally in two modes:

- **Shared-room play:** a TV, monitor, or large display shows the common board while each player uses their own phone as their private controller/interface.
- **Remote play:** players can join the same game session from different locations while still seeing the same authoritative game state.

The large display is primarily a presentation surface. It renders the table, board, pieces, effects, camera, lighting, and overall game state. Player interaction is mainly performed from mobile devices.

The same application should support multiple client roles rather than being developed as unrelated applications.

---

## 2. Product principles

### One game state, many views

A match is one logical game instance viewed through multiple devices.

Different clients can have different cameras, UI layouts, permissions, and private information, but all of them observe and manipulate the same shared game state.

Examples:

- TV client: public board, cinematic camera, no direct interaction required.
- Mobile client: player-specific controls, private hand, dice, actions, targeting, and camera.
- Remote desktop client: complete player interface if desired.
- AI host: game-management tools exposed through MCP rather than a visual interface.

### Turn-based first

The platform is not intended to synchronize high-frequency action gameplay.

Most board-game interactions can be represented as discrete commands or events:

- move piece
- play card
- roll die
- draw card
- end turn
- modify counter
- reveal object
- spawn object
- refresh market

This dramatically reduces networking requirements compared with real-time action games.

### Client-heavy architecture

Whenever possible, rendering and game execution should happen on player devices rather than on expensive centralized game servers.

The platform backend should primarily provide coordination, persistence, identity, discovery, synchronization, and access control.

### Provider-independent architecture

Networking, persistence, authentication, rendering, and AI integration must be separated behind interfaces.

Firebase may be used initially, but game-domain code must not depend directly on Firebase APIs.

This makes it possible to replace Firebase Realtime Database with another transport or message-broker solution later without rewriting the game engine.

---

## 3. Initial technical direction

### Engine

**Godot** is the main runtime and rendering engine.

Godot is suitable because it can provide:

- attractive 2D and 3D board presentation
- lighting
- shadows
- post-processing
- camera effects
- animation
- particles
- shaders
- desktop builds
- Android builds
- Android TV builds
- web exports

The platform should take advantage of this so that a board game can feel more physical and atmospheric than a conventional browser tabletop.

### Web / PWA

The primary frictionless entry point should be a web build.

Where supported, the web application can behave as a PWA so users can launch it without a traditional installation flow.

### Native wrapper / Android TV

Some Smart TVs have poor or outdated browsers even when they run Android TV.

For those devices, the same frontend/runtime can be distributed as an Android TV application or wrapper.

The intended hierarchy is:

1. Try the web/PWA version.
2. If the device browser is insufficient, install the Android/Android TV application.

The product should preserve the same game model and communication protocol across both cases.

---

## 4. High-level architecture

```text
                        ┌───────────────────────┐
                        │   Public Web Entry    │
                        │ lobby / auth / games  │
                        └───────────┬───────────┘
                                    │
                         session discovery
                                    │
                     ┌──────────────▼──────────────┐
                     │      Shared Game Session     │
                     │   state + event coordination │
                     └───────┬───────────┬──────────┘
                             │           │
                    events   │           │ events
                             │           │
                ┌────────────▼───┐   ┌───▼──────────────┐
                │ Large Display  │   │ Mobile Player A  │
                │ Godot client   │   │ Godot/web client │
                └────────────────┘   └──────────────────┘
                             │
                             │ same session
                             │
                         ┌───▼──────────────┐
                         │ Mobile Player B  │
                         └──────────────────┘

                                    │
                                    │ game tools
                                    ▼
                             ┌──────────────┐
                             │ MCP Server   │
                             └──────┬───────┘
                                    │
                              user-provided AI
                                    │
                     ChatGPT / Claude / Gemini / etc.
```

---

## 5. Game session model

The system should treat a match as a **shared logical session**.

Each connected device is a view/controller for that session.

A session contains at least:

- session ID
- game definition
- player list
- ownership/permissions
- authoritative game state
- turn state
- object state
- event history
- optional random seed
- optional persistence metadata

Clients should send **intentions or commands**, not arbitrary state replacements.

Example:

```json
{
  "type": "MOVE_OBJECT",
  "player_id": "p2",
  "object_id": "piece_17",
  "destination": "cell_24"
}
```

The session logic validates the action and produces the resulting event/state update.

```json
{
  "type": "OBJECT_MOVED",
  "object_id": "piece_17",
  "from": "cell_18",
  "to": "cell_24"
}
```

Every interested client receives that update.

---

## 6. Networking and Firebase

For the first implementation, **Firebase Realtime Database** is a reasonable synchronization mechanism.

It can initially serve as:

- ephemeral session-state store
- event channel
- presence system
- lightweight synchronization mechanism

Its role should be hidden behind an abstraction such as:

```text
SessionTransport
 ├── FirebaseRealtimeTransport
 ├── WebSocketTransport
 ├── MessageBrokerTransport
 └── LocalTransport
```

The core engine should interact only with `SessionTransport`.

A future implementation could replace Firebase with:

- NATS
- Redis Streams
- RabbitMQ
- WebSockets
- another realtime datastore
- custom peer/host transport

without changing game logic.

---

## 7. Backend responsibilities

The public backend should remain lightweight.

It is primarily a rendezvous and persistence layer, not a server that renders or simulates every frame of every match.

Responsibilities may include:

- authentication
- users
- game catalog
- game packages
- mods
- matchmaking / invitations
- room discovery
- session metadata
- permissions
- save games
- asset metadata
- MCP endpoint routing

Expensive visual processing remains on client hardware.

---

## 8. AI integration through MCP

BGO should **not require the platform owner to pay for an AI API for every active game**.

Instead, BGO exposes game functionality through an **MCP server**.

Users can connect their own AI client or subscription.

Possible compatible clients/providers may include systems such as ChatGPT, Claude, Gemini, and other MCP-capable agents.

The platform provides the interface; the user provides the intelligence.

### Example MCP tools

Read tools:

```text
get_session_state
get_players
get_current_turn
get_board_objects
get_player_hand
get_available_actions
get_game_rules
```

Write tools:

```text
create_game
setup_game
move_object
spawn_object
shuffle_deck
draw_card
play_card
roll_dice
modify_counter
advance_turn
refresh_market
end_game
```

This allows an AI to function as:

- game host
- rules assistant
- setup assistant
- automated opponent
- referee
- storyteller
- tutorial system
- game master

### AI philosophy

AI integration is optional and external to the deterministic core.

The AI should generally act through the same command interfaces available to players or automation systems.

It should not directly mutate arbitrary engine state.

---

## 9. Component-based game-object architecture

The engine should model board-game concepts as reusable components instead of hardcoding specific games.

A base object may contain identity and composition only.

```text
GameObject
 ├── identity
 ├── definition_id
 ├── owner
 ├── transform
 └── components[]
```

Possible components:

```text
Renderable
Movable
Ownable
Stackable
Rotatable
Flippable
Selectable
Draggable
Counter
Card
Deck
Dice
Container
BoardSlot
GridPosition
TurnParticipant
HiddenInformation
RuleTrigger
Automatable
```

A chess pawn, a miniature, a wooden cube, and a token can therefore share the same underlying movement or ownership behavior while using different renderers and definitions.

---

## 10. Logical object vs rendered representation

Game logic and rendering must be independent.

A logical object describes **what exists**.

A renderer decides **how it looks**.

For example:

```text
Logical Token Stack
quantity = 18
resource = "wood"
owner = "player_2"
```

could render as:

- one token with the number `18`
- a small stack of 5 visible pieces plus a counter
- eighteen individual physical pieces
- a 2D icon
- a 3D pile

The game state remains identical.

This is especially useful because board games can easily contain more than one hundred physical objects.

The renderer should therefore be free to aggregate objects where appropriate for performance and readability.

---

## 11. Data-driven game definitions

Game-specific content should be loaded from external definitions wherever practical.

JSON is a natural initial format.

Example:

```json
{
  "id": "red_token",
  "type": "piece",
  "renderer": {
    "model": "res://games/sample/assets/red_token.glb",
    "icon": "res://games/sample/assets/red_token.png"
  },
  "components": {
    "movable": true,
    "stackable": {
      "max": 99
    },
    "ownable": true
  }
}
```

This separation is important for future modding.

The engine implements concepts; a game package combines those concepts.

---

## 12. Modding and community content

The architecture should be designed from the start so user-created games and components can eventually be distributed as packages.

This does **not** mean implementing a complete mod marketplace in the MVP.

It means avoiding architectural decisions that would make modding impossible later.

A game package could eventually contain:

```text
/game.json
/objects/
/boards/
/rules/
/assets/
/ui/
/localization/
```

The long-term goal is that creating another game should primarily involve composing reusable components, writing declarative definitions, adding assets, and implementing only truly unique rules.

This enables community-created content and gives BGO platform/network effects beyond individual bundled games.

---

## 13. Smart board-game components

A virtual tabletop does not need to reproduce every inconvenience of physical board games.

The platform should preserve the tactile conceptual model of board games while automating mechanical housekeeping.

Examples:

- automatic setup
- automatic cleanup
- replenish markets
- refill card rows
- reshuffle discard piles
- maintain counters
- enforce ownership
- calculate legal moves
- advance phases
- reveal scheduled information
- distribute resources
- resolve repetitive upkeep

These behaviors should remain modular.

A component or rule can therefore contain limited intelligence without turning the platform into a conventional scripted videogame.

The design goal is:

> Preserve the freedom and clarity of board games while removing repetitive physical administration.

---

## 14. Rendering philosophy

A major advantage over physical tabletop simulators should be presentation.

The logical game state must not be coupled to one visual representation.

A game could potentially provide multiple presentation modes:

- lightweight 2D
- stylized 2.5D
- full 3D tabletop
- cinematic 3D
- accessibility-focused view
- future VR view

The same logical token may be represented using sprites, meshes, icons, simplified counters, or animated miniatures.

Godot's scene system should be used primarily as the presentation layer around an engine state that remains serializable and deterministic.

---

## 15. Testing strategy

Because behavior is component-based, components should be testable independently.

Examples:

```text
/tests/components/movable
/tests/components/stackable
/tests/components/ownership
/tests/components/deck
/tests/components/dice
/tests/network/session_sync
```

Each component should have a small isolated sandbox scene when visual interaction is useful.

This prevents the common prototype problem where every new mechanic can only be tested by launching an entire game.

---

## 16. MVP scope

The first prototype exists to prove the architecture, not to ship a complete tabletop simulator.

### Required

- Godot project
- one simple board
- two players
- movable pieces
- ownership
- turn state
- one shared session
- large-display mode
- mobile/player mode
- different cameras per client
- synchronized actions
- serializable state
- abstract transport interface
- Firebase Realtime Database transport prototype

### Useful but optional for the first milestone

- dice component
- stackable pieces
- basic cards
- reconnection
- session invite code or QR

### Explicitly later

- sophisticated game editor
- public mod marketplace
- complex deck-building UI
- VR
- complete AI host
- advanced physics sandbox
- large library of implemented games

---

## 17. Recommended first vertical slice

The first playable test should intentionally resemble a tiny board game rather than trying to emulate a complex commercial title.

Example:

```text
Board: small grid
Players: 2
Pieces: 3–5 per player
Turns: alternating
Action: select owned piece → move to valid position
Display: shared board
Phone: player controls + private identity
```

This proves the entire path:

```text
player input
   ↓
command
   ↓
validation
   ↓
shared state mutation
   ↓
event publication
   ↓
all clients update
   ↓
rendering
```

Once this works reliably, cards, dice, stacks, automated setup, richer rules, and MCP can be layered on top.

---

## 18. Suggested module boundaries

```text
/core
  /state
  /objects
  /components
  /commands
  /events
  /rules

/network
  /transport
  /firebase

/render
  /2d
  /3d
  /camera

/ui
  /display
  /mobile
  /shared

/games
  /sample

/modding
  /definitions
  /loader

/mcp
  /tools
  /session_bridge

/tests
```

Dependencies should generally point inward toward core abstractions.

The core module should have no Firebase, MCP, UI, or renderer dependencies.

---

## 19. Long-term vision

BGO should evolve from a single tabletop application into a reusable **board-game runtime**.

A mature version would allow developers and players to define a game from reusable primitives such as:

- boards
- areas
- grids
- tokens
- miniatures
- cards
- decks
- dice
- counters
- containers
- ownership
- hidden information
- turns
- phases
- triggers
- automated maintenance

The same runtime can then provide:

- local shared-screen sessions
- online sessions
- mobile controllers
- Android TV display
- web/PWA access
- AI-hosted sessions via MCP
- community-created games

The central architectural principle is therefore:

> **BGO implements board-game concepts, not individual board games.**

Individual games should be compositions of reusable concepts plus data, assets, and only the minimum custom logic necessary.

---

## 20. Immediate implementation objective

Do not begin by creating a general-purpose editor or a complete networking platform.

Build one end-to-end vertical slice with clean module boundaries.

The first success criterion is simple:

> A player opens BGO on a phone, joins a session displayed on another device, moves an owned piece, and every connected client immediately renders the resulting shared state.

If this works while the domain model remains independent from Firebase and rendering, the foundation is correct.