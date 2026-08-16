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

---

## 21. Player interaction model

The mobile device is not intended to behave as a miniature copy of the TV. It is the player's **private controller, camera and inventory surface**.

The shared TV remains the primary communal presentation surface, especially for players in the same room.

### Shared display camera

The display camera should support multiple behaviors and allow cycling between them with a remote or simple controls.

Initial camera modes:

- **Overview:** shows the complete board/table and prioritizes readability.
- **Focus / smart camera:** automatically frames the region where a relevant action is occurring.
- **Optional manual/cinematic mode:** later allows direct control or predefined viewpoints.

The smart camera should react to domain events such as piece movement, card placement, dice rolls, reveals and other significant actions rather than requiring the user to manually steer the TV camera.

### Mobile camera

The player's phone uses a constrained free camera above the table, conceptually similar to a helicopter/orbit camera.

Primary gestures should control the camera, not immediately manipulate objects:

- drag: pan/orbit the camera
- pinch: zoom
- optional rotate gesture: adjust viewing angle
- camera movement is constrained so the player cannot accidentally leave the useful table area

This avoids overloading drag gestures with both camera and object manipulation.

### Tap and long-press interaction

Game objects expose semantic actions through their components.

A normal tap should invoke or expose the object's most common interaction.

A long press should open an extended contextual menu for less frequent or administrative actions.

Example for a deck:

Normal actions may include:

- draw one card
- draw N cards
- inspect top card when allowed

Extended actions may include:

- move deck
- shuffle
- split deck
- give cards to player
- delete/remove object when permissions allow

The available actions are determined by the object's components and current permissions, not hardcoded globally into the UI.

### Interaction modes: Pick Up and Place

Direct drag-and-drop of arbitrary 3D objects is not the primary interaction model on mobile.

Instead, the player can switch between explicit manipulation modes.

#### Pick Up mode

When Pick Up mode is active, tapping an eligible object transfers it into the player's hand/container.

Typical flow:

```text
navigate camera to source area
    ↓
enable Pick Up mode
    ↓
tap one or more owned/available objects
    ↓
objects enter player's hand
```

This supports quickly collecting several miniatures, tokens or resources without requiring precise dragging.

#### Place mode

When Place mode is active, tapping a valid table location places the currently selected object from the player's hand.

The hand preserves ordering, allowing repeated taps to place objects sequentially when useful.

Typical flow:

```text
navigate camera to destination area
    ↓
enable Place mode
    ↓
select object or ordered group from hand
    ↓
tap destination(s)
    ↓
objects are placed sequentially
```

This is particularly useful for moving groups of miniatures, setup components or resource tokens.

### The hand is a generic container

A player's hand is **not limited to cards**.

It is a private or semi-private container that can hold any portable game object:

- cards
- miniatures
- resource tokens
- coins
- dice
- markers
- temporary game objects

Objects in the hand move conceptually with the player/camera rather than remaining fixed to a table coordinate.

The renderer may show hand objects in different ways depending on visibility rules:

- fully visible to the owner
- card-back / masked representation to other players
- hidden completely from other players
- visible only as an object count

### Ownership vs possession

Ownership and possession are distinct concepts.

An object may be associated permanently with a player color/faction, or it may simply be in a player's current possession.

Examples:

- a red miniature may be permanently owned by the red player
- a coin may have no permanent owner but may currently be possessed by player 2
- a shared resource may move between players many times during a game

The engine should therefore model at least:

```text
owner_id      // persistent game ownership, optional
holder_id     // current possession/controller, optional
```

This distinction enables natural interactions such as giving another player money, cards or shared resources.

### Player-to-player transfers

Objects and resources in a player's hand may expose transfer actions such as:

- give selected object to player
- give N resource units to player
- trade selected objects
- return object to common supply

These operations should be represented as commands and validated by game rules/permissions.

---

## 22. Player presence and shared-table feeling

BGO should preserve the feeling that multiple people are physically present around the same table.

A player camera is therefore not only a viewport; it can also represent the player's **presence** in the shared 3D space.

Each connected player can publish lightweight presence state such as:

```text
player_id
camera_transform
pointer_transform
selected_object_id
interaction_state
```

Remote clients can render this as an avatar rig attached conceptually to the player's viewpoint:

```text
RemotePlayer
 └── AvatarRig
     ├── Head
     ├── Pointer
     ├── OptionalLeftHand
     └── OptionalRightHand
```

This allows players to perceive that someone else is looking at, pointing toward or interacting with a particular region of the table.

The system does not need to stream remote camera video. Only the lightweight transform and interaction state need synchronization.

This model also creates a future-compatible path toward VR, where headset and controller transforms could replace approximate desktop/mobile presence transforms without changing the domain concept.

### Visibility layers

Godot render layers and camera culling masks can be used to control visual presentation.

Conceptually:

```text
Layer 1 = public table
Layer 2 = player 1 private visuals
Layer 3 = player 2 private visuals
Layer 4 = player 3 private visuals
Layer 5 = player 4 private visuals
Layer N = host/debug visuals
```

A player's camera sees the public layer plus its own permitted private layers.

The shared TV normally sees only public layers.

These layers are a **rendering mechanism**, not a security boundary. Secret information that a client is not authorized to know should not be transmitted to that client merely because its camera does not render it.

---

## 23. Commands, event log, checkpoints and restoration

Every meaningful game action should be represented as a high-level command and recorded as a resulting event from the beginning of the project.

Examples:

```text
DRAW_CARD
MOVE_OBJECT
PICK_UP_OBJECT
PLACE_OBJECT
TRANSFER_OBJECT
SHUFFLE_DECK
ROLL_DICE
END_TURN
CHANGE_COUNTER
```

The system should maintain both:

1. **Current state** for efficient rendering and synchronization.
2. **Append-only event history** for traceability and reconstruction.

A simplified Firebase structure may resemble:

```text
/games/{game_id}/state
/games/{game_id}/events/{event_id}
/games/{game_id}/checkpoints/{checkpoint_id}
```

The event log provides several capabilities:

- inspect what happened during a game
- debug desynchronization or rule problems
- replay a match
- provide a readable history to players
- let AI analyze previous actions
- reconstruct state when useful
- support controlled restoration

### Checkpoints

The engine should periodically or semantically create checkpoints, especially at useful boundaries such as:

- game setup completed
- beginning of turn
- beginning of round
- before a complex resolution
- explicit host save point

A checkpoint stores a complete serializable game state together with enough metadata to resume consistently.

### Restoration / rewind

Restoration should not behave as an unrestricted local undo button.

It is a session-level administrative action that restores the complete logical state to a selected checkpoint or event boundary.

A restoration must include all relevant state:

- board objects and transforms
- hands/containers
- ownership and possession
- counters/resources
- deck order when deterministic restoration requires it
- turn and phase state
- permissions
- current active player
- random state/seed when applicable

This ensures that rewinding to the beginning of a previous turn also restores who may interact and what each player possessed at that moment.

Restoration permissions should normally belong to the host/referee role and may optionally require player consensus depending on the game/session settings.

A restoration itself should also be recorded as an event rather than silently deleting history.

Example:

```json
{
  "type": "SESSION_RESTORED",
  "actor_id": "host_1",
  "checkpoint_id": "turn_08_start",
  "previous_revision": 312,
  "new_revision": 313
}
```

The original event history remains available for audit/review even after the active state has been restored.

---

## 24. Updated vertical-slice target

The first meaningful BGO prototype should demonstrate the interaction philosophy as well as synchronization.

Target scenario:

```text
Shared TV
  ├── 3D table
  ├── overview camera
  └── smart focus camera

Player A phone
  ├── constrained table camera
  ├── private hand/container
  ├── Pick Up mode
  ├── Place mode
  └── contextual actions

Player B phone
  └── equivalent independent player interface

Firebase RTDB
  ├── shared state
  ├── presence
  ├── event history
  └── checkpoints
```

Minimum demonstration:

1. Two players join one session.
2. The TV renders the shared table.
3. Each phone can navigate its own camera.
4. Player A picks up an owned object into their hand.
5. Player A moves the camera and places the object elsewhere.
6. The TV smart camera notices and frames the relevant action.
7. Player A transfers a neutral resource to Player B.
8. All resulting commands/events are recorded.
9. The host restores the session to the beginning-of-turn checkpoint.
10. All clients return to the same restored state.

If this works cleanly while the domain model remains independent from Firebase and rendering, BGO's foundational architecture is validated.