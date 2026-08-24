# BGO — TEST001 component-driven vertical slice

TEST001 now validates a shared Firebase-backed board whose static setup comes from `games/test001/game.jsonh` and whose runtime state lives in Firebase RTDB.

The Godot scene is only a generic renderer shell. Physical tabletop components are declared in
`table.instances`: each entry supplies a stable instance ID, public component ID, component
configuration and placement. The runtime resolves each component through the registry, instantiates
it under `Main/Components`, applies its declared properties and records structured load events.

Current TEST001 table instances are:

- `main_board` → `bgo.board.checkered`;
- `player_1_area` → `bgo.player_area.basic`;
- `player_2_area` → `bgo.player_area.basic`.

`main.tscn` must not contain game-specific board or player-area instances. Runtime objects from
`setup.objects` are likewise resolved by component ID and created under `Main/Pieces` from session
state. Components emit their own `component_event` lifecycle events; the composition layer enriches
them with instance/component identity and sends them through `BgoLogger`.

## Game definition

The game file references reusable component IDs rather than redefining component behavior:

- `bgo.board.checkered`
- `bgo.piece.basic_cylinder`
- `bgo.player_area.basic`
- `bgo.slot.basic`

The loader validates the definition before using it. An invalid definition is ignored and reported instead of crashing the runtime. The current file uses strict JSON syntax, which is also valid JSONH; when JsonhGd is present at `res://addons/JsonhGd/JsonhGd.gd`, human-friendly JSONH syntax can be used as well.

## Roles

### Display

`?role=display&game=TEST001`

The display cannot manipulate pieces. It renders synchronized state and follows activity.

### Player 1

`?role=player&game=TEST001&player=player_1`

### Player 2

`?role=player&game=TEST001&player=player_2`

Each player has an independent camera and controls only objects they own or currently hold. Neutral public objects have an empty `owner_id` and can be claimed while unheld.

## Location model

Logical destinations are no longer arbitrary world coordinates.

```text
slot         board/grid placement such as board:3:2
player_area  public/semi-public objects associated with a player
hand         true private/semi-private hand state (cards later)
```

Every checkered-board cell exposes a logical slot id in the form `board:x:y`. `bgo.slot.basic` is available for future markets, resource banks, discard areas, etc.

The TEST001 board defines `grid_points_per_unit: 5`: each logical cell interval
contains five one-centimetre placement intervals. Placement snaps to board
slots first; a slotless surface falls back to this fine grid.

`PlayerArea` and `Hand` are intentionally different concepts. Generic PICKUP sends an eligible object to the viewport-attached hand, not to the physical PlayerArea.

## Current setup

The game definition declares:

- an 8 × 6 checkered board;
- Player 1 and Player 2 colors;
- one Player 1 cylinder token;
- one Player 2 stack;
- one neutral ivory stack.

If TEST001 already exists in Firebase, missing objects from the definition are added without resetting existing piece positions.

## Player controls

- drag: orbit camera;
- PICKUP + tap an allowed object: move it to the player's viewport-attached hand;
- tap any hand item: frame it as the manual selection;
- PLACE + tap a valid board cell: move the framed hand object to that board slot;
- FULL SCREEN: request browser fullscreen and landscape orientation.

The player client renders a vertical FILO hand drawer. Hand objects are not physical 3D bodies and do not participate in tabletop collisions.

## Firebase state

Example:

```json
{
  "component_id": "bgo.piece.basic_cylinder",
  "object_config": { "color_source": "player" },
  "owner_id": "player_1",
  "holder_id": "",
  "quantity": 1,
  "cell": { "x": 1, "y": 2 },
  "location": { "type": "slot", "slot_id": "board:1:2" },
  "revision": 1
}
```

When held in the public player area:

```json
{
  "owner_id": "",
  "holder_id": "player_1",
  "location": { "type": "player_area", "player_id": "player_1" }
}
```

This demonstrates the difference between permanent ownership and current possession.

## Export/deploy

Export Web to:

`build/web/index.html`

For the temporary Firebase Test Mode prototype, deploy Hosting only:

```bash
firebase deploy --only hosting
```

Do not deploy the repository database rules yet.

## Test checklist

1. Run locally first and confirm there are no GDScript parse errors.
2. Display, Player 1 and Player 2 all render the same board state.
3. A neutral ivory stack appears after Firebase synchronizes the definition.
4. Player 1 cannot pick up Player 2's owned stack.
5. Either player can pick up the neutral stack while it is unheld.
6. PICK UP animates the object to that player's public area.
7. The mobile panel lists it under PLAYER AREA, while HAND remains separate.
8. PLACE only resolves to a board slot and synchronizes/animates on every client.
9. Firebase events/logging record the interaction.

## Still staged

- transfer/give UI between players;
- runtime slot-capacity/occupancy authority;
- true private card-hand renderer/security;
- anonymous authentication and production RTDB rules;
- realtime Firebase/WebSocket adapter instead of polling;
- presence avatars/pointers;
- MCP tools over the logical game model;
- snapshots/rewind UI.
