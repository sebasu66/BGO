# UI tooling evaluation

## Goal

Recover UI quality without coupling BGO's logical gameplay model to presentation code. Any UI framework or asset pack must remain a projection layer over the existing domain contracts.

## Recommended direction

### Pilot: Reactive UI Toolkit — Godot

Use Reactive UI Toolkit as the first serious pilot for new/rewritten UI surfaces. It provides React-style function components, hooks, keyed reconciliation, routing, typed styling, `.guitkx` markup that compiles to GDScript, and Fast Refresh while still producing real Godot `Control` nodes.

Pilot it on one contained surface first (for example the player HUD / turn strip / action panel), not by rewriting the entire runtime UI at once.

Constraints:

- keep `SessionState`, `GameplayState`, `TabletopState`, Firebase repositories and command validation outside the UI framework;
- UI receives state/projections and emits requests/commands only;
- preserve touch/mobile input paths;
- add Web + mobile-sized E2E coverage before expanding adoption;
- generated `.gd` siblings from `.guitkx` should follow the toolkit's documented source-control policy;
- document the toolkit's non-MIT community/commercial license before any production release decision.

The toolkit is currently verified by its project on Godot 4.7 and requires Godot 4.4+, which matches BGO's 4.7.1 baseline.

### Do not combine reactive frameworks initially

Spark is a capable lightweight reactive state/binding addon, but it overlaps materially with Reactive UI Toolkit's hooks/reconciliation/state model. Do not introduce both in the same pilot. Revisit Spark only if the React-style toolkit proves too invasive and a smaller binding layer is preferable.

### Styling

GDSS is attractive for CSS-like theming, variables, states, transitions, classes and hot reload, and explicitly targets Godot 4.7. It is still early beta/unstable. Do not stack it on the first Reactive UI pilot. First determine whether Reactive UI Toolkit's own styling + normal Godot Themes are sufficient. Evaluate GDSS later as an independent styling experiment.

## Supporting UI assets/addons

### Casual UI Pack

Good candidate for visual assets. It is CC0, includes 600+ vector/cartoon UI elements, and includes mobile-oriented resolutions. Treat it as an art source/theme kit, not an architectural dependency.

### GodotX Toast

Good candidate for transient feedback such as rejected moves, connection state, join/leave notifications and command errors. MIT, Godot 4.5+, responsive/UI-scale aware, with swipe-to-dismiss support. Integrate behind a small BGO notification adapter so application code does not depend directly on the addon API.

### Radial Menu Control

Potentially useful for contextual tabletop actions. MIT and compatible with Godot 4.x, but the published feature list explicitly calls out keyboard/mouse/gamepad and does not claim touch support. Do not adopt for player mobile UX until a touch acceptance test proves tap/drag selection, cancellation, submenu navigation and safe-area behavior on mobile-sized Web/touch input.

## Developer tooling

### DCKit

Useful as a DEV-only in-game console for session inspection, test commands and diagnostics. MIT, Godot 4.5–4.8.x, modular and programmatically invokable. It must never become a gameplay authority or expose unsafe production commands. If adopted, production export behavior must either exclude it or register no privileged commands outside DEV builds.

### Graphics Settings 3D Demo

Use as reference/sample code rather than importing the whole demo as a runtime dependency. It is an MIT Godot Foundation project for Godot 4.7 and covers UI scale, resolution scale, fullscreen, V-Sync, AA, FOV and expensive 3D effects. Extract only the settings architecture needed by BGO and adapt it for Web/mobile/TV profiles.

## Adoption order

1. Reactive UI Toolkit isolated pilot on one player-facing UI surface.
2. GodotX Toast through a BGO-owned notification adapter.
3. Casual UI Pack assets/theme exploration.
4. Radial Menu touch/mobile proof before adoption.
5. DCKit DEV-only diagnostic integration.
6. Graphics settings implementation derived from the Godot Foundation demo.
7. Reconsider GDSS only after the first UI pilot; do not add Spark unless replacing, rather than stacking with, the chosen reactive approach.

## Success criteria for the UI pilot

- visibly cleaner player UI on desktop and mobile-sized Web;
- no domain state moved into UI components;
- accepted/rejected gameplay commands behave identically before and after the UI rewrite;
- touch interaction remains first-class;
- local and deployed DEV E2E stay green;
- the pilot is easy to remove if the framework proves brittle;
- no production licensing ambiguity is left unresolved before release.
