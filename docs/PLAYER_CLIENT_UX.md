# BGO Player Client UX

## Purpose

The player client is a landscape-first Web/mobile controller for a continuous shared tabletop. It must stay usable with both thumbs while preserving most of the screen for the actual game.

The runtime should not divide one game into artificial disconnected screens when the same content would physically coexist on a real tabletop.

## Continuous tabletop navigation

The table is one continuous logical plane containing named sections defined by the game.

Examples:

- main board
- auxiliary boards/tracks
- dice area
- shared reserves/markets
- player areas/tableaux

Sections are physical/logical locations on the same table, not separate copies of game state and not separate UI pages.

Players can reach sections naturally by panning the camera. A section may also expose a camera preset so the player can jump/focus to it quickly.

A camera preset is therefore a navigation shortcut, not a different game view.

## Camera gestures

Player camera defaults are defined by the seat/player side and may later be overridden/tuned by the GamePackage.

Baseline gesture profile:

- One-finger drag: pan/translate camera focus in the table plane.
- Two-finger pinch: zoom in/out with runtime limits.
- Two-finger drag: rotate around the fixed vertical axis.
- Reset Camera: restore the original seat camera preset.
- Section shortcuts: move smoothly to a declared section camera preset.
- Tap without drag remains object/slot interaction.

Display clients do not inherit these player gestures by default.

Camera tuning direction:

- greater default distance/height than the current close prototype framing;
- less top-down pitch so tall components and remote player-presence markers remain visible;
- somewhat wider, human-like FOV;
- sensible min/max zoom so the camera cannot clip into normal tabletop components.

## Landscape thumb zones

### Left utility strip

Secondary/global actions live on the left edge and can collapse to a small handle:

- Reset Camera / camera presets
- Filters
- Inspect mode later
- Fullscreen/orientation
- Return to lobby

These controls are intentionally separate from game actions.

### Right game strip

Primary match interaction belongs on the right edge:

- Pick Up when the game/component supports it
- Place when armed/appropriate
- End/Next Turn when SessionState exists
- contextual actions for the current selection

END TURN must remain disabled unless the current participant owns the active turn. The UI reads this from logical SessionState; it must not infer it locally.

The right strip should only expose capabilities relevant to the active game/component. BGO should avoid a giant universal object menu.

## Table sections

A GamePackage may declare sections of the continuous table. Each section may provide:

- stable id and label
- rectangular/circular footprint initially
- position/orientation on the table plane
- public/private/hidden visibility policy
- participant/seat association where relevant
- child zones/slots
- camera preset/focus target
- allowed interaction/capability restrictions

Sections can be adjacent, above/below/around the main board, like areas on a real table.

A player's personal tableau is normally a table section. It is not the same concept as Hand.

## Hand model

Hand remains semantically distinct from PlayerArea/table sections.

Hand has no physical footprint on the tabletop. It is a viewport-attached overlay representing what the player is holding privately.

Default presentation direction:

- collapsed: bottom hand icon plus item count;
- expanded: horizontal ordered strip;
- centered item is the implicit focused item;
- neighboring items progressively scale down away from the center;
- horizontal drag scrolls through the hand;
- explicit tap toggles selection;
- multiple selection may be supported;
- if nothing is explicitly selected, PLACE may act on the centered item;
- after placing the centered item, remaining items close the gap so repeated board taps can place successive items efficiently.

The visual carousel is client presentation. Hand ownership, visibility, order, selection commands and placement remain logical concepts.

## Contextual object actions

Components may expose one or more validated actions. UI shows only actions currently relevant/legal for that component, state and player.

When an object opens a contextual action menu, presentation should:

- keep the active object emphasized;
- dim/de-emphasize background table content;
- suppress accidental background picking while the contextual interaction is open;
- display only runtime-owned validated actions.

A future blur/depth treatment is presentation polish; interaction isolation is the functional requirement.

Examples:

- deck: draw, draw N, deal, shuffle where configured;
- miniature: move/rotate where allowed;
- aggregate stack: split/add/remove where allowed;
- static scenery: no normal gameplay manipulation.

## Inspect mode

A future INSPECT mode provides a non-destructive enlarged view of selected content.

Useful for:

- reading cards/text-heavy components;
- seeing component details/properties;
- inspecting pieces without moving them;
- examining remote player-presence markers.

Inspect presentation is screen-oriented and informational; it must not alter the object's logical tabletop transform.

## Filters

Camera/object filters remain a per-client presentation convenience.

Examples:

- show only my pieces;
- hide/de-emphasize another owner;
- filter by component type/capability.

Filtered-out objects may remain faintly visible while becoming non-interactive. This is not a privacy mechanism; true hidden information must be filtered from logical client state.

## Interaction profiles

Games may request a safe declarative interaction profile instead of executable scripts.

Conceptual examples:

- `bgo.player.standard`: tap select, one-finger pan, contextual actions.
- `bgo.player.direct_interact`: taps invoke direct component actions; pickup controls may be hidden.
- `bgo.player.card_heavy`: hand drawer emphasized and rapid placement enabled.

A profile may configure mappings such as:

```jsonh
{
  interactions: {
    tap_object: "select",
    tap_empty: "place_if_armed",
    drag_one_finger: "camera_pan",
    drag_two_fingers: "camera_rotate",
    pinch: "camera_zoom",
    show_pickup: true,
    show_hand_drawer: true,
    inspect_mode: true
  }
}
```

GamePackages must not provide arbitrary GDScript for gesture handling. Profiles resolve to runtime-owned capabilities and validated commands.

## Implementation stages

1. Stabilize camera gesture baseline and tune distance/pitch/FOV for tabletop use.
2. Formalize SessionState/seat/turn/result so the player is always inside a real session.
3. Introduce continuous tabletop sections + section camera presets + logical child slots/zones.
4. Build the first complete abstract-game fixture (chess/checkers class) using individual miniature/piece components and capacity-1 board slots.
5. Refactor right controls to expose only relevant capabilities and add END TURN from SessionState.
6. Replace current flat hand controls with the collapsible viewport-attached hand drawer when a supported game actually needs Hand.
7. Add contextual action presentation and INSPECT mode.
8. Formalize safe interaction profiles in the GamePackage contract and conformance tests.

The game definition describes tabletop structure, rules/capabilities and presentation intent; it should not encode device-specific pixel layouts.
