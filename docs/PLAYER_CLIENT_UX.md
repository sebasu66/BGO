# BGO Player Client UX

## Purpose

The player client is a landscape-first Web/mobile controller for the shared tabletop. It must stay usable with both thumbs while preserving enough screen area for the actual game.

This document separates immediate controls from GamePackage-driven presentation so the runtime does not hard-code one board-game layout.

## Camera gestures

Player camera defaults are defined by the seat/player side and may later be overridden by a GamePackage view.

Baseline gesture profile:

- One-finger drag: pan/translate the camera focus in the table plane. Camera height, pitch and yaw are preserved.
- Two-finger pinch: zoom in/out with runtime limits.
- Two-finger drag: rotate around the table on the fixed vertical axis. Pitch remains fixed.
- Reset Camera: restore the original seat camera focus, yaw, pitch and zoom.
- Tap without drag remains object/cell interaction.

Display clients do not inherit these player gestures.

## Landscape thumb zones

### Left utility strip

Secondary/global actions live on the left edge and can collapse to a small handle:

- Reset Camera
- Filters
- Fullscreen/orientation
- Return to lobby

These controls are intentionally separate from game actions.

### Right game strip

Primary match interaction belongs on the right edge:

- Pick Up
- Place
- End/Next Turn when the session turn model exists
- Player Area / view navigation
- contextual actions for the current selection

END TURN must remain disabled unless the current participant owns the active turn. The UI must read this from logical SessionState; it must not infer it locally.

## Game views

A GamePackage may define one or more logical views. A view is a camera/presentation target over one or more board/zone groups, not a separate copy of game state.

Example conceptual configuration:

```jsonh
{
  player_interface: {
    profile: "bgo.player.standard",
    views: [
      {
        id: "shared_table",
        label: "TABLE",
        includes: ["main_board"],
        camera: "seat_default"
      },
      {
        id: "player_board",
        label: "MY AREA",
        includes: ["player_area", "player_board"],
        camera: "fit_contents"
      }
    ],
    view_mode: "auto"
  }
}
```

`view_mode` is declarative presentation guidance, not rules logic. Candidate values:

- `single`: one shared view is enough.
- `tabs`: switch one view at a time.
- `combined`: multiple compatible sections share one camera.
- `auto`: runtime chooses based on screen size and the declared content footprint.

A chess-like game may expose only the shared board. A game with a large personal tableau may expose a shared-table view and a dedicated player-board view. A game where the personal tableau dominates may make that the primary player view.

Switching views should use a short slide/camera transition and must not mutate logical object locations.

## Hand model

Hand remains semantically distinct from PlayerArea and from board views.

On the player client, the default hand presentation is a collapsible bottom drawer:

- collapsed: hand icon plus item count;
- expanded: horizontal ordered strip;
- centered item is the implicit focused item;
- neighboring items progressively scale down away from the center;
- horizontal drag scrolls through the hand;
- explicit tap toggles selection;
- multiple selection is allowed;
- if nothing is explicitly selected, PLACE acts on the centered item;
- after placing the centered item, the remaining items close the gap so repeated board taps can place successive items efficiently.

The visual carousel is client presentation. Hand ownership, visibility, order, selection commands and placement remain logical concepts.

## Interaction profiles

Games may request a safe declarative interaction profile instead of executable scripts.

Conceptual examples:

- `bgo.player.standard`: tap select, one-finger camera pan, pick/place actions.
- `bgo.player.direct_interact`: taps primarily invoke component interaction; pickup controls may be hidden.
- `bgo.player.card_heavy`: hand drawer emphasized and rapid repeated placement enabled.

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
    show_hand_drawer: true
  }
}
```

GamePackages must not provide arbitrary GDScript for gesture handling. Profiles resolve to runtime-owned capabilities and validated commands.

## Implementation stages

1. Camera gesture baseline + reset + left utility strip.
2. Refactor current right panel into a compact thumb-oriented action strip.
3. Add logical SessionState turn ownership, then enable END TURN conditionally.
4. Add declarative view definitions and animated view switching.
5. Replace the current flat hand controls with the collapsible bottom hand drawer/carousel.
6. Add multi-selection and rapid sequential placement.
7. Formalize safe interaction profiles in the GamePackage contract and conformance tests.

The runtime should choose layout from GamePackage declarations plus viewport capabilities; the game definition should describe intent and content grouping, not pixel coordinates.
