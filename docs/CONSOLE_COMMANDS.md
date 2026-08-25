# BGO developer console commands

The `Console` addon is enabled for development builds. `BgoGameCommandConsole`
bridges the console to live BGO game objects without making the console part of
the gameplay authority.

## Implementation status â€” 2026-08-24

Integrated in the current development branch:

- `addons/console` is enabled as the `Console` autoload.
- `src/debug/bgo_game_command_console.gd` is the autoload facade; focused `bgo_console_*` services own discovery, API projection, invocation/conversion and
  lifecycle cleanup.
- `BGOGameObject`, `GameSessionRepository`, and component scripts are the
  supported command hosts.
- `tests/console_command_bridge_test.gd` runs as part of the headless test
  runner and covers discovery, invocation, type conversion, help, both arity
  errors, and unregistering freed objects.

The bridge is intentionally a developer tool. It does not replace or bypass
the logical command validation layer and remains disabled for release builds.

## Fluent game-definition builder (usable DEV API)

The console accepts curated fluent expressions directly. This is a restricted
parser, not GDScript `eval`: only registered builders, registered methods,
literals, and `System.constants.*` values can execute.

Start from an empty definition:

```text
Game.create().setId("test001_console").setName("BGO Component Test").setPlayerCount(2).setTurnBased(true).setSandboxEnabled(true)
Game.current().setTable(Game.Table.create().setWidth(15.5).setDepth(9.8).addComponent(Game.CheckeredBoard.create().setId("main_board").setColumns(8).setRows(6).setCellSize(1.2).setGridCellSizeCm(5).setGridPointsPerUnit(5).setGridVirtualInfinite(true)))
Game.current().addPlayer(Game.Player.create().setName("Player 1"))
Game.current().addPlayer(Game.Player.create().setName("Player 2"))
Game.current().addCatalogEntry(Game.CatalogEntry.create().setId("basic-miniature").setComponent(System.constants.COMPONENT_BASIC_CYLINDER).setRadius(0.38).setHeight(0.32))
Game.current().setAssetBox(Game.AssetBox.create().setId("game_box").setLabel("ASSET BOX"))
Game.current().addObject(Game.BasicCylinder.create().setOwner(1).setInitialSlot("1,2"))
Game.current().addObject(Game.BasicCylinder.create().setOwner(2).setAvailability(System.constants.AVAILABILITY_FINITE).setQuantity(3).setInitialSlot("6,3"))
Game.current().addObject(Game.BasicCylinder.create().setOwner("").setAvailability(System.constants.AVAILABILITY_FINITE).setQuantity(5).setColorSource(System.constants.COLOR_SOURCE_FIXED).setColor("#E7E0CF").setInitialSlot("3,2"))
Game.current().validate()
Game.current().build()
Game.current().saveAs("res://games/test001_console/game.jsonh")
Game.load("res://games/test001/game.jsonh").migrateToCurrent().build()
```

Every `setX` and `addX` returns the same parent builder, so nested and
multi-line chains are equivalent. `build()` returns `{ok, data, errors}` and
does not produce a successful result unless `BgoGameDefinitionLoader` accepts
the complete definition. `saveAs()` repeats validation. It accepts `user://`
and, only in DEV, the local package catalog under `res://games/`; traversal or
writes elsewhere are rejected. `Game.load()` uses the same restricted roots.

Player IDs are optional and generated as `player_1`, `player_2`, etc. For two
players, the default preset places red and blue players opposite each other.
`setPosition` rounds logical grid points to integers; `setRotation` rounds and
normalizes degrees; physical decimal values are stored with at most three
decimal places. Use `getWarnings()` to inspect automatic normalization.

Discover the API without reading source code:

```text
System.builders.getTypes()
System.builders.describe("Game.Player")
System.constants.getAll()
System.api.describe("Match.piece_1", "getOwner")
```

`Tab` completes fluent factories and methods contextually. For example,
`Game.` proposes its factories and authoring types; `Game.Player.` proposes
`create()`; and `Game.Player.create().setN` completes to
`Game.Player.create().setName`. `Match.*` completes live entities and their
methods with parentheses. Nested expressions complete from the innermost builder.

`Game.definition` is the older read-only view of the definition currently
loaded by the runtime. Its `getName`, `getDesc`, `getWidth` and
`getDepth` methods inspect metadata and table dimensions; it is not the
authoring factory. It is one valid `Game.*` entity alongside `Game.Player`,
`Game.Table`, and the other authoring types.

Current builder types are `Game`, `Game.Table`, `Game.Player`,
`Game.CheckeredBoard`, `Game.PlayerArea`, `Game.CatalogEntry`, `Game.AssetBox`,
and `Game.BasicCylinder`. Roots such as `Player.create()` are rejected by the
public parser. This surface
authors and serializes package definitions; it does not bypass validated
`Match.*` commands or silently replace the active match.

## Built-in BGO commands

- `game.objects` lists live command hosts.
- `game.commands` lists the public commands currently registered.
- `game.refresh` rescans the scene tree.
- `game.call <object> <method> "arg 1 arg 2"` calls a discovered command when
  the direct command form is inconvenient.

The `game.*` reflection bridge is retained temporarily for DEV compatibility.
New public API work must use the curated contract below.

## Curated public API

Public entities are deliberately declared through `console_api()`. The
descriptor maps stable camelCase API methods to internal GDScript callables;
an undeclared public method is not exposed accidentally.

The three canonical roots are:

- `Game.*`: declarative game definition and catalog.
- `Match.*`: current match state, entities and validated actions.
- `System.*`: BGO runtime capabilities, diagnostics and API discovery.

Methods use a flat, predictable vocabulary:

```text
Game.definition.getName()
Game.definition.getWidth()
Game.definition.isTurnBased()
Match.piece_1.getOwner()
Match.piece_1.getQuantity()
Match.piece_1.isStackable()
```

Naming rules:

- `getX` reads a value without side effects.
- `setX` requests a validated mutation when that property is intentionally writable.
- `isX` and `hasX` return boolean state.
- all other methods use an explicit verb such as `moveToGrid`, `roll`, `shuffle` or `delete`.
- camelCase is the public API spelling; internal GDScript may remain snake_case.

Discovery commands are themselves part of `System.*`:

```text
System.api.getEntities()
System.api.getMethods("Match.piece_1")
System.api.describe("Game.definition", "getWidth")
System.constants.getAll()
System.constants.get("LOCATION_PLAYER_AREA")
```

Public constants use flat `UPPER_SNAKE_CASE` names under `System.constants`:

```text
System.constants.COMPONENT_BASIC_CYLINDER
System.constants.PLAYER_COLOR_RED
System.constants.LOCATION_PLAYER_AREA
System.constants.ROLE_HOST
```

The older `G.*` spelling is confined to the legacy whitespace-command adapter;
the public expression parser rejects it and canonical discovery omits it. The
console resolves constants to stable string IDs before typed method invocation.
Unknown constants are rejected. The IDE preview and API
descriptions color entity/class names, methods, strings, numbers, booleans and
constants independently.

## Automatic commands

Public methods declared by a `BGOGameObject`, the live
`GameSessionRepository`, or a component script under `res://src/components/`,
are registered automatically as:

```text
game.<object>.<method> [arguments...]
```

The object name comes from `entity_id`, `entity_id` metadata, or the node name.
Methods beginning with `_` and inherited Godot engine methods are excluded.
Argument values are converted from console strings for common Godot scalar and
math types (`bool`, `int`, `float`, vectors, colors, arrays, and dictionaries).

## Per-object help

An object may define either `consoleHelp()` or the idiomatic GDScript
`console_help()` with no arguments. It can return a summary string or a
dictionary whose keys are method names and whose values are descriptions:

```gdscript
func consoleHelp() -> Dictionary:
	return {
		"_summary": "Developer actions for this piece.",
		"configure": "Updates the logical identity and visual setup.",
	}
```

The bridge uses those descriptions in `commands_list` and adds
`game.<object>.help`. A command with too few or too many parameters is rejected
with an explicit error; extra parameters are never silently discarded.

New game-object instances are discovered when they enter or leave the scene
tree. Use `game.refresh` after a script reload or an explicit scene mutation.

This bridge is debug-only. Commands still call the target object's public API;
they do not bypass domain validation or authorize production gameplay actions.
