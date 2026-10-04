---
module: bgo.player_area.basic
status: draft
written_by: Claude, inferred from code - pending owner validation
inferred_from: player_area.gd, src/core/gameplay_state.gd (_move_to_collection)
---
# Player area

## What it is for
A zone on the table that belongs to one player, where they keep objects in front of them in the open (unlike the hand, which is private). The component is the visible surface. There is no separate "area state": an object is in an area when its own location says `player_area` plus that player's id.

## Rules (reply with the number to change one)
- A1. An area belongs to one player id and has a label, a color and a size (default 1.55 x 0.06 x 7.2). All of these can be changed at runtime without moving any object.
- A2. To move an object into an area (`object.move_to_collection`, collection `player_area`): you are an active participant, the object exists, and you may control it (C rules).
- A3. When it moves in, it leaves the table slot, grid cell or hand it was in, you become its holder, and its location becomes your area.
- A4. The area marks itself as a placeable surface and declares whether its objects are public (default yes).
- A5. Slot positions inside an area are spaced 0.85 units apart along its length, starting 2.3 units from the center.
- A6. A color is refused if it cannot be read (except "transparent"). A size is refused unless all three axes are positive.

## Control rules (shared by hand, player area and asset box)
Repeated in each module until the kernel owns them; they are written once in `gameplay_state.gd` (`_can_control`).

- C1. Only an *active participant* (someone whose turn it currently is) may use these commands through the command path.
- C2. The **holder** of an object (whoever is holding it right now) may act on it.
- C3. If nobody holds it, its **owner** may act on it.
- C4. The **host** may act on any owned or held object. A neutral object (no owner) that nobody holds can only be touched if the command explicitly says "acquire neutral".

## Commands and events
- `object.move_to_collection` with collection `player_area` emits `object.moved` (from where it was, to the area).
- Console methods: set player id, label, color, size, visibility, public flag, and get the world position of an area slot.

## Gaps found while writing this (not decided, for you)
- G1. **The area has no capacity or occupancy rule.** Any number of objects can be moved in, onto the same spot.
- G2. **Nothing takes an object back out.** `object.move` only works for objects in a slot, so leaving the area has no command.
- G3. The public flag (A4) is only stored. In the files I read I found nothing that hides area contents from other players when it is false.
- G4. Only `test001` uses this component; no game rule file yet says what an area means for scoring or turns.

## Questions for the owner
- Q1. Should an area have a limit (for example "max 5 objects" from the game's rule file)?
- Q2. Can other players take objects out of someone else's public area?
