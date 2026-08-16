# BGO Add-on Evaluation

This document records candidate Godot add-ons considered for BGO. The guiding constraints are:

- Godot Web export remains a first-class target.
- The current Web renderer is Compatibility.
- BGO core should stay lightweight and component-driven.
- Authoring-only tools are kept separate from runtime dependencies whenever possible.

## Recommended now

### JsonhGd

Use the GDScript JSONH implementation for game-definition files.

Reason: it stays in GDScript and avoids introducing a native GDExtension or a .NET requirement into the Web-first runtime.

Planned use:

- game definitions
- component configuration documents
- human-editable localization/configuration where appropriate
- validation input before constructing a normalized internal model

### Deep RayCast 3D

Promising for object selection where pieces overlap or occlude one another. BGO can keep its normal single-hit raycast as the fast path and expose deep selection as an optional interaction strategy/component.

## Recommended experiment

### Lente — Photo Mode for Godot

Useful for camera authoring, composition experiments, color grading, lens controls and presentation work.

Important: BGO's Web build currently uses the Compatibility renderer. Lente itself supports Compatibility, but engine depth-of-field is not available there. Therefore Lente can still help with camera movement, framing, grading and captures, while DOF experiments should be considered native/Forward+ experiments unless BGO later adds a separate rendering profile.

Do not couple core camera logic to Lente. Integrate it as an optional authoring/presentation layer.

### GPU Texture Painter

Potentially useful for future authoring tools and player customization of 3D pieces. It supports runtime and editor painting and does not require physics collisions.

Keep it out of core for now. It requires suitable mesh UV2 data and introduces an overlay-atlas/material pipeline that should be tested with Web/mobile performance before becoming a supported BGO capability.

### GoBuild

Interesting as an editor-side mesh authoring tool for creating/modifying simple board-game geometry without leaving Godot.

Treat as an authoring dependency only, not a runtime dependency. Review GPLv3 implications before redistributing it as part of an editor/tooling package.

## Not recommended for core right now

### xpTURN.Klotho

Technically strong deterministic simulation/rollback framework, but it is centered on Godot .NET/C#, fixed-tick deterministic simulation and multiplayer prediction/rollback. BGO's current turn-based Firebase architecture does not need this complexity, and adopting it would force a .NET-oriented runtime architecture.

Revisit only if BGO later supports games requiring deterministic lockstep or rollback.

### Card Combat Engine

Well-engineered but intentionally specialized around card-combat concepts such as mana, battle phases, creatures, attacks and card zones. BGO should implement generic board-game components rather than making a TCG combat engine a core dependency.

It may still be useful as a reference or as a future optional game-specific module.

### Mesh Tools

Useful editor/geometry utilities, especially CSG cleanup and physics-body generation, but not a general runtime mesh-combining optimization layer for BGO.

Use selectively in authoring workflows if a concrete need appears.

## Localization note

JSONH Translations is attractive as a format, but the current published add-on requires Godot .NET/C#. For the Web-first GDScript runtime, prefer keeping localization data portable and avoid making the runtime depend on .NET solely for translation import.

A future BGO localization loader can use JsonhGd directly, validate translation dictionaries, then feed Godot Translation resources/TranslationServer as part of the import or startup pipeline.
