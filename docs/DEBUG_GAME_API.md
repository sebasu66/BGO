# Game definition and debug API

BGO loads one installed JSONH game definition without recompiling the project.

- Web: `/?game=table_debug`
- Godot/desktop: `--game=table_debug`
- Definition: `games/<game_id>/game.jsonh`

`table_debug` is the first table-only conformance scene. It intentionally has no board. Its four colored areas exercise free placement, slot-only placement, accepted component kinds and mixed placement. `table.debug: true` enables the diagnostic area overlays and labels.

It runs in `sandbox` mode: there is no Firebase persistence, turn flow, event history, winner or terminal match state. Participants are optional. Named snapshots are explicit in-memory restore points and may be discarded with the running sandbox.

The global Godot singleton `G` is the root of the development-console API:

```gdscript
G.help()
G.games()
G.definition()
G.definition("table.areas")
G.components()
G.components("bgo.slot.basic")
G.state()
G.state("tabletop.zones")
G.execute({"verb": "sandbox.snapshot.save", "args": {"name": "layout-a"}})
G.execute({"verb": "sandbox.snapshot.restore", "args": {"name": "layout-a"}})
G.export_initial_state()
G.execute({"verb": "turn.end", "actor_id": "player_1"})
```

Definition and state reads return copies. Runtime mutation never exposes raw property setters: `G.execute()` uses the same validated command path as UI, automation and future MCP clients, so accepted changes remain evented, synchronized and replayable.
