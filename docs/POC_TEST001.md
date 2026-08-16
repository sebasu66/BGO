# BGO PoC 01 — TEST001

This proof of concept validates one shared Firebase-backed board viewed by two roles from the same Godot Web build.

## Roles

### Display

Open:

`?role=display&game=TEST001`

The display cannot manipulate pieces. It renders Firebase state and automatically focuses the camera toward pieces whose state changes.

### Player

Open:

`?role=player&game=TEST001&player=player_1`

Controls:

- drag: orbit camera around the table
- tap owned piece while in `PICK UP`: select it
- press `PLACE`
- tap a board cell: place selected piece there

The move is written to Firebase RTDB and an immutable-style event entry is pushed to `/games/TEST001/events`.

## Firebase paths used

```text
/games/TEST001
  /metadata
  /pieces
    /player_1_piece
    /player_2_stack
  /events
```

Example piece:

```json
{
  "owner_id": "player_1",
  "holder_id": "player_1",
  "quantity": 1,
  "cell": { "x": 1, "y": 2 },
  "revision": 1
}
```

## First run behavior

If `/games/TEST001` does not exist, the first connected client seeds the demo session automatically.

## Export

Use the committed `Web` export preset. Output is configured as:

`build/web/index.html`

From Godot Editor: Project → Export → Web → Export Project.

Or from a Godot executable with export templates installed:

```bash
godot --headless --export-release Web build/web/index.html
```

## Firebase deployment

For this prototype the Realtime Database is currently using Firebase console Test Mode. Do **not** deploy the repository's production-oriented database rules yet.

Deploy only Hosting:

```bash
firebase login
firebase use board-game-online-68c3f
firebase deploy --only hosting
```

Then test two URLs based on the Hosting URL shown by Firebase:

```text
https://<hosting-domain>/?role=display&game=TEST001
https://<hosting-domain>/?role=player&game=TEST001&player=player_1
```

Open the first on the PC/TV and the second on the phone.

## Expected result

1. Both clients show the same 3D table.
2. The phone can orbit its own camera.
3. The display remains non-interactive.
4. The phone selects the yellow `player_1` piece in PICK UP mode.
5. Switch to PLACE and tap another board cell.
6. The move appears on the display after the next Firebase poll (normally under one second).
7. The display camera shifts focus toward the changed piece.
8. Firebase contains the new piece position and a `PIECE_MOVED` event.

## Deliberate prototype limitations

- RTDB polling is used instead of the future realtime Web adapter.
- Authentication is not enabled yet; this depends on temporary Firebase Test Mode.
- Only player 1 manipulation is intended for the first phone test.
- Hand/private-object visibility is not part of PoC 01 yet.
- MCP is intentionally not deployed yet.

These are staged limitations, not intended production architecture.
