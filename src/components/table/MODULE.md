---
module: bgo.table.basic
status: draft
written_by: Claude, from the owner's design (mesa.md in the general repo, 2026-10-18) - pending owner validation
---
# Table

## What it is for
The table is where the game happens. It decides what may be placed and where, how the surface looks and which lights shine on it. It holds zones (areas of the table) and slots (places that accept certain kinds of objects). The table belongs to the **game definition** (`g`); what happens on it during a match belongs to the **match** (`m`).

## Rules (reply with the number to change one)
- T1. The table has a mode. In `free` mode objects may be put anywhere a zone allows. In `closed` mode objects may only be put in slots.
- T2. Closed mode refuses free poses and grid drops. It does not move anything already placed.
- T3. The surface has a preset name, a tint (a color) and a texture scale. A bad value changes nothing: the whole change is refused.
- T4. Lights are extra to the studio lights. Each has a unique id, a type (point, spot, directional), a position, an intensity above zero and a color.
- T5. A zone is `public` or `private`, may have an owner, and can be resized. A resize that would leave a placed object outside the zone is refused.
- T6. A slot says what it accepts and where it is anchored: the table, a zone, a board cell or a card. A board cell `[x, y]` counts from the board's center, x to the right and y upward.
- T7. Only an empty slot can be removed.
- T8. Only the host may change the table. A player gets `host_only`.
- T10. The table has a grid whose cell is `cell_size_cm` (default 5). A size in centimetres covers the cells it needs, rounded up: a poker card is 2 x 2, a token is 1.
- T11. A drop near a slot (within one cell) snaps to it; on a closed table a drop with no slot is refused with `closed_table_needs_a_slot`; on an open table it stays loose, centered in its cell.
- T12. Containment links are two-way and never loop: an object is inside at most one container.
- T13. Players other than the owner do not see a private zone, what sits in its slots, or what is inside those objects.
- T9. Every accepted change emits one event and shows on all screens at once. A refused change emits nothing and does not move the revision.

## Commands and events
| Command | Arguments | Event |
|---|---|---|
| `table.set_mode` | mode | `table.mode_changed` |
| `table.set_surface` | preset, tint, uv_scale (any) | `table.surface_changed` |
| `table.add_light` | id, type, position, intensity, color | `table.light_added` |
| `table.remove_light` | id | `table.light_removed` |
| `zone.set_visibility` | zone_id, visibility | `zone.visibility_changed` |
| `zone.resize` | zone_id, width, depth | `zone.resized` |
| `slot.add` | slot_id, zone_id, capacity, accepted_kinds, pose, anchor | `slot.added` |
| `slot.remove` | slot_id | `slot.removed` |
| `table.set_cell_size` | cell_size_cm | `table.cell_size_changed` |

Reasons for a refusal: `host_only`, `session_not_active`, `invalid_mode`, `nothing_to_change`, `invalid_surface`, `invalid_light`, `unknown_light`, `invalid_zone_visibility`, `invalid_size`, `zone_resize_rejected`, `slot_rejected`, `slot_remove_rejected`.

A game definition can set the starting values in its `table` block: `mode`, `surface` (`preset`, `tint`, `uv_scale`) and `lights`.

## Files
- `table_config_state.gd`: the logical settings (mode, surface, lights), with validation.
- `table_verbs.gd`: the commands above, host only.
- `table.gd` and `table.tscn`: the visible part. It shows the lights and announces the surface.
- `table_cell_math.gd`: the 5 cm grid (cells covered by a size, cell of a position, centers).
- `table_containment_state.gd`: who is inside whom (card in deck, deck in box), both directions, no loops.
- `table_locator.gd`: "where is this object?" and "what is in this cell?".
- `table_dropper.gd`: dropping with magnet to slots, refusal on a closed table, loose drops snapped to a cell.
- `table_visibility.gd`: hides the contents of private zones from other players.
- `table_texts.gd`, `table_log.gd`, `tests/`: sentences, log and tests.
- Children of the table (each self-contained): `grid/` (point grid for free placement) and `slots/` (slot marker).
- The player's pieces (`area/`, `hand/`, `presence/`) live in `src/components/player/`; the table never imports them.
- Zones and slots live in `src/core/tabletop_state.gd`.
- `src/runtime/table_state_controller.gd` connects the state to the screen.

## Gaps found while writing this (not decided, for you)
- G1. The surface preset is stored and announced, but only the tint is painted so far. Applying a PBR preset (marble, wood, metal) needs the world's material code to listen to the signal.
- G2. (Partly done: `table_visibility.gd` filters a snapshot per viewer and is tested; it is not yet used by the real client or MCP snapshots.) A private zone is stored, but nothing yet hides its contents from other players. That is the per-client state filter.
- G3. `zone.set_visibility` and `zone.resize` run on the table state, but the player area component does not yet redraw itself when its zone is resized.
- G4. Anchored slots are stored with their anchor. The world does not yet compute their position from the board cell.
- G6. `TableDropper`, `TableLocator`, `TableContainmentState` and `TableVisibility` are tested against the real game (`test001`) and real verbs, but the product does not call them yet. Today a drop goes through `object.move` and the grid magnet of `table/grid`; containment has no verbs (`container.put_inside`, `container.take_out`) and no one asks the locator. Wiring them to real verbs is the next slice.
- G7. The viewer filter removes objects, slots and poses of a private zone, but the real snapshot also carries `hands` and the `events` history. Those can leak what the filter hides and must be filtered too.
- G8. Only the active player may move (a real game rule). Players cannot arrange their own private zone out of turn; decide if the private zone is exempt.
- G5. In `closed` mode `take_from_box` is refused when it drops onto the grid. A closed game must take objects into slots.

## Decided by the owner (2026-10-18)
- D1. **Private zone:** the other players see nothing at all. Its contents are invisible to them (for now).
- D2. **Closed table:** a drop outside a slot is refused. **Open table:** a drop near a slot snaps to it (magnet); a drop elsewhere stays loose, but it still snaps to the grid so the table always knows its cell.
- D3. **Player zone template:** each game defines it. By default it is a delimited area around the public zone of the table, as in real life. Reference for doubtful cases: Tabletop Simulator.
- D4. **Surface:** uses PBR textures downloaded from ambientCG (the project already has the ambientCG add-on).
- D5. **Grid and scale:** the table has a grid of cells with a cell size in centimetres (default 5; see Q1). A cell holds one small object (token, die, miniature); larger things (cards, boards) cover a group of cells.
- D6. **Pivot:** whatever sits in a cell or a group of cells is centered by its pivot on the center of that cell or group, unless the game says otherwise.
- D7. **Everyone knows where everything is, both ways:** the table knows which object is in each cell and slot; each object knows its cell, its slot and what holds it. The chain works in both directions: cell -> slot -> deck -> cards, and card -> deck -> slot -> cell. Example: "in cell (1,1) there is a slot with the event deck; the deck knows its cards".

## Questions for the owner
- Q1/Q2 are answered and built (owner, 2026-10-18): 5 cm default, per-game `cell_size_cm`, objects declare their size in cm. Kept below for the analysis.
- Q1. Which default cell size: 5 cm (now), 4 cm or 3 cm? Analysis for a poker card (63 x 88 mm): at 5 cm it covers 2 x 2 cells; at 4 cm it needs 2 x 3; at 3 cm it needs 3 x 3. A token, die or miniature (up to about 3 cm of base) fits one cell at 3, 4 and 5 cm. Proposal: keep 5 cm as the default and let each game set its own `cell_size_cm`.
- Q2. Objects declare their size in centimetres and the table works out how many cells they cover (rounding up). Is that right?
