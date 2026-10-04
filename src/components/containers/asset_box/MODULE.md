---
module: bgo.container.asset_box
status: draft
written_by: Claude, inferred from code - pending owner validation
inferred_from: asset_box.gd, src/core/asset_box_state.gd, src/core/gameplay_state.gd (box functions)
---
# Asset box

## What it is for
The stockroom of a game: everything the game declares that is not on the table yet (pieces, boards, tokens). Players take things out onto the table and can put them back. The 3D box on screen is only an authoring surface; the real box is a catalog with no positions.

## Rules (reply with the number to change one)
- B1. The box is a **catalog**. It records which objects are inside, how many, whether they are available, and who owns them. It does not know where anything is inside it. The old physical-grid questions remain only as empty compatibility stubs.
- B2. A box needs a non-empty id and can only be reconfigured while it is empty. Existing assets are never dropped silently.
- B3. To add an asset: it needs an object id and a component id, quantity of at least 1, and an id not already in the box. Available quantity defaults to the full quantity. Availability mode defaults to "unique".
- B4. To add an object to the game box, its id must be new to the game. If the object cannot take the box as its location, the addition is undone.
- B5. To take an object out onto the table: the session is active, you are an active participant, the object is really in the box, and you may control it (C rules). If you give no position, the first free cell is used. The footprint defaults to one cell, must fit the grid, and may not overlap other objects unless overlap is explicitly allowed.
- B6. Taking is all-or-nothing. If any step fails, the box and the object are put back exactly as they were.
- B7. Taking a neutral object (no owner) does not claim it unless the command explicitly allows it. For the box this is off by default.
- B8. To store an object back: it must be on the table (slot or grid), you are an active participant, and you may control it. It leaves the table and enters the box.
- B9. Listing the box is always in alphabetical id order.
- B10. On screen, the box can be open or closed and has a color and a 5 cm point grid for the Asset Placer. None of that changes game state.

## Control rules (shared by hand, player area and asset box)
Repeated in each module until the kernel owns them; they are written once in `gameplay_state.gd` (`_can_control`).

- C1. Only an *active participant* (someone whose turn it currently is) may use these commands through the command path.
- C2. The **holder** of an object (whoever is holding it right now) may act on it.
- C3. If nobody holds it, its **owner** may act on it.
- C4. The **host** may act on any owned or held object. A neutral object (no owner) that nobody holds can only be touched if the command explicitly says "acquire neutral".

## Commands and events
- Direct methods: `take_object_from_box` (event `object_taken_from_asset_box`) and `store_object_in_box` (event `object_stored_in_asset_box`).
- Console methods: configure, open or close, set colors, grid size and spacing, and get the world position of a point.

## Gaps found while writing this (not decided, for you)
- G1. **Taking and storing are not registered commands.** They exist only as direct methods, so the console, MCP and AI cannot use them through the normal command path.
- G2. **Availability is stored but never used.** `availability_mode` and `available_quantity` are saved and copied around, but I found no rule that reads them, and no game file sets them.
- G3. Taking an object with quantity above 1 moves the whole stack. Nothing takes "one of N".

## Questions for the owner
- Q1. What should the availability modes mean (for example unique, unlimited, limited stock)?
- Q2. When a game declares 10 identical tokens, should taking one leave 9 in the box?
