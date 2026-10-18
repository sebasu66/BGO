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

Reasons for a refusal: `host_only`, `session_not_active`, `invalid_mode`, `nothing_to_change`, `invalid_surface`, `invalid_light`, `unknown_light`, `invalid_zone_visibility`, `invalid_size`, `zone_resize_rejected`, `slot_rejected`, `slot_remove_rejected`.

A game definition can set the starting values in its `table` block: `mode`, `surface` (`preset`, `tint`, `uv_scale`) and `lights`.

## Files
- `table_config_state.gd`: the logical settings (mode, surface, lights), with validation.
- `table_verbs.gd`: the commands above, host only.
- `table.gd` and `table.tscn`: the visible part. It shows the lights and announces the surface.
- Zones and slots live in `src/core/tabletop_state.gd`.
- `src/runtime/table_state_controller.gd` connects the state to the screen.

## Gaps found while writing this (not decided, for you)
- G1. The surface preset is stored and announced, but only the tint is painted so far. Applying a PBR preset (marble, wood, metal) needs the world's material code to listen to the signal.
- G2. A private zone is stored, but nothing yet hides its contents from other players. That is the per-client state filter.
- G3. `zone.set_visibility` and `zone.resize` run on the table state, but the player area component does not yet redraw itself when its zone is resized.
- G4. Anchored slots are stored with their anchor. The world does not yet compute their position from the board cell.
- G5. In `closed` mode `take_from_box` is refused when it drops onto the grid. A closed game must take objects into slots.

## Questions for the owner
- Q1. In a private zone, do the other players see that objects exist, or nothing at all?
- Q2. In closed mode, should an object dropped outside a slot go back where it was, or should the gesture be refused?
- Q3. Does each game define the player-zone template, or is there a default?
