---
module: bgo.hand.vertical
status: draft
written_by: Claude, inferred from code - pending owner validation
inferred_from: vertical_hand.gd, src/core/hand_state.gd, src/core/gameplay_state.gd
---
# Vertical hand

## What it is for
A participant's private pile of objects they have picked up and not yet put down. The component only draws the pile. The real contents and the rules live in the game state (`HandState` and `GameplayState`), not in the component.

## Rules (reply with the number to change one)
- H1. Every participant has exactly one hand, created the first time it is needed.
- H2. A hand holds each object at most once. Picking up an object already in your hand is rejected.
- H3. Newest on top (FILO): the last object picked up is the first one in the hand and is drawn in front.
- H4. To pick up: the session is active, the object exists, you may control it (C rules), and your hand is available.
- H5. Picking up from the table removes the object from its slot or grid cell and sets its location to "hand". If it was neutral and the command allowed claiming, you become its holder.
- H6. To place from the hand: the session is active, the object is in YOUR hand, you may control it, and the destination slot accepts it. If the slot refuses, nothing changes. If it accepts, the object leaves your hand, loses its holder and sits in the slot.
- H7. What others can see of your hand is a setting: owner sees faces and others see hidden (default), owner only, or public. Any other value is refused.
- H8. The drawing shows the pile vertically, tilts items alternately 4 degrees, enlarges the selected item, and shows an "xN" badge when an object has quantity above 1.
- H9. If the selected item disappears, selection falls back to the first item. The interaction mode is pickup, place or none; anything else becomes none.

## Control rules (shared by hand, player area and asset box)
Repeated in each module until the kernel owns them; they are written once in `gameplay_state.gd` (`_can_control`).

- C1. Only an *active participant* (someone whose turn it currently is) may use these commands through the command path.
- C2. The **holder** of an object (whoever is holding it right now) may act on it.
- C3. If nobody holds it, its **owner** may act on it.
- C4. The **host** may act on any owned or held object. A neutral object (no owner) that nobody holds can only be touched if the command explicitly says "acquire neutral".

## Commands and events
- `object.move_to_collection` with collection `hand` picks an object up and emits `object.moved`.
- Direct methods `pickup_object_to_hand` and `place_object_from_hand` emit older events (`object_picked_up`, `object_placed_from_hand`). Two event vocabularies coexist.

## Gaps found while writing this (not decided, for you)
- G1. **Placing from the hand is not a command.** `object.move` only accepts objects that are currently in a slot, so a hand object can only be placed through the direct method. The console, MCP and AI cannot do it through the command path.
- G2. **There is no command to reorder your own hand.** The order only changes by picking up or placing.
- G3. The direct `pickup_object_to_hand` does not check "active participant" itself; the command path does (C1). Same action, different strictness.
- G4. Privacy (H7) is a client presentation setting. I found no server-side filtering of other players' hands in the files I read.

## Questions for the owner
- Q1. Should reordering your own hand be allowed at any time, even out of turn, since it changes nothing on the table?
- Q2. Is FILO fixed for every game, or should the game's rule file choose (stack, fan, free order)?
