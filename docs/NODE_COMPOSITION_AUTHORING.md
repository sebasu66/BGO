# BGO — Node Composition, Variants and Declarative Behaviors

Status: architecture direction for the desktop authoring workflow.

## Goal

BGO game components should follow Godot's composition model instead of growing into monolithic scenes/scripts. A game-specific component is assembled from reusable BGO custom nodes plus declarative properties. Game packages should not require arbitrary trusted GDScript for ordinary component variants.

## Root game-object node

A game-specific scene should normally have one `BgoGameObject3D` root. The root coordinates presentation/features and exposes an editable property bag for authored values.

Do not collapse all data into one untyped dictionary. Keep three namespaces conceptually distinct:

- `definition`: authored defaults/variant properties that belong to the GamePackage;
- `state`: per-instance mutable Match state synchronized by the domain model;
- `variables`: game/match/player variables owned by the appropriate Game/Match/System scope rather than by a render node.

The editor may present definition properties as an ergonomic key/value map, but every reusable child feature/representation should publish a schema/descriptor so keys remain typed, discoverable and validated.

Conceptual root:

```text
BgoGameObject3D
├── Representation
├── Pivot
├── Features...
├── Behaviors...
└── Surface / SlotLayout ... (optional)
```

The root remains a presentation/interaction adapter. `LogicalObjectState` and canonical Game/Match/System state remain authoritative.

## Property bag and child-node binding

The root owns the effective authored property set for the component definition. Child nodes declare the keys they consume and their schema. This gives authoring one coherent property surface while keeping behavior modular.

Example:

```text
definition properties
  width = 0.63
  height = 0.88
  front_texture = cards/rifleman.webp
  billboard_mode = y_axis
  roughness = 0.75
```

A `BgoPlaneRepresentation` can bind to `width`, `height`, `front_texture`; a `BgoPbrMaterial` can bind to `roughness`; a `BgoBillboardRepresentation` can bind to `billboard_mode`.

Inspector/editor tooling should show provenance (which child declares each property), type, allowed range/enum, description and default.

## Representation nodes

Representation is composed through reusable custom nodes, for example:

```text
BgoRepresentation3D
├── BgoPlaneRepresentation      # cards/tokens/flat art
├── BgoBoxRepresentation        # deck/box/block
├── BgoPrimitiveRepresentation  # cylinder/cube/cone/sphere
├── BgoModelRepresentation      # GLB/GLTF props, miniatures, dice
└── BgoBillboardRepresentation  # comic-book characters etc.
```

Representations are interchangeable visual adapters and must not own authoritative gameplay state.

PBR-capable representations/surfaces should use a reusable material descriptor/node supporting albedo, normal, roughness, metallic, AO, height where supported, UV scale and scalar overrides.

## Pivot / anchor

Every physical/presentation object should have an explicit configurable pivot/anchor. Common presets may include `base_center`, `center`, and `custom`, with a `Marker3D` for custom placement. Slots, snapping, rotation and animation should use the logical placement anchor rather than assuming the mesh origin is correct.

## Feature nodes

Behaviors/capabilities that have configuration, runtime behavior or presentation should normally be reusable BGO child nodes rather than inheritance layers.

Examples:

```text
BgoStackable
BgoRotatable
BgoLockable
BgoPlaceable
BgoFlippable
BgoSurface
BgoSlotLayout
BgoStats
```

A feature node publishes its properties/capabilities and integrates with canonical domain commands. It must not silently mutate authoritative state.

Pure domain constraints do not need a Node merely to store a boolean. Examples such as uniqueness/max instances/spawn policy may remain declarative GamePackage constraints unless they need local editor/runtime behavior.

## Component definitions, variants and instances

Keep three levels distinct:

### Base component

A reusable BGO composition/scene defining representation/features and a typed property contract.

### Variant

A GamePackage-owned specialization of a base component. Normally it changes definition properties without adding trusted code.

```text
Base: bgo.character.billboard
Variant: wasteland.raider_rifleman
Overrides:
  image = raider_rifleman.webp
  height = 1.82
  shadow_radius = 0.42
```

Variants may also compose permitted BGO feature nodes when authoring needs a genuinely different capability set.

### Instance

A concrete object in setup/Match state with stable instance ID, owner/location/current state, etc. Multiple instances may share one variant. Instance state must not be copied back into the variant definition accidentally.

Authoring should provide explicit operations such as:

- Create Base Component (BGO/core authoring only)
- Create Variant from Component
- Duplicate Variant
- Add Variant to GamePackage
- Create Setup Instance from Variant
- Preview / Validate

## Declarative Behavior node

BGO needs a reusable `BgoBehavior` (or equivalent) node for game-specific effects without arbitrary GDScript.

A behavior is conceptually:

```text
WHEN event
IF conditions
THEN actions
```

It subscribes to canonical BGO events and submits normal canonical commands/actions back through the same authority/validation path as UI, console and AI. It never directly edits another Godot node, Firebase row, or logical-state dictionary.

### Event triggers

Human-friendly authoring names such as:

- `onPlay`
- `onDiscard`
- `onTake`
- `onTurnStart`
- `onTurnEnd`
- `onEnterSlot`
- `onLeaveSlot`
- `onAcquire`
- `onRelease`

should compile/map to canonical event types rather than creating a second event vocabulary. For example `onDiscard` may map to a canonical `object.moved_to_collection` event filtered to the discard collection.

The behavior editor should allow both friendly presets and advanced selection of the underlying canonical event/filter.

### Conditions

Conditions should be declarative expressions over authorized state, for example:

```text
actor == owner
Match.variables.radiation > 3
source.tags contains "weapon"
player.resources.ammo >= 1
object.properties.faction == "raider"
```

Conditions are side-effect free.

### Actions / effects

Actions may target any canonical scope through validated operations:

- object/component instance properties/state;
- players / ownership / resources;
- Match variables and flow;
- Game-defined runtime variables where allowed;
- System/environment presentation controls where explicitly exposed (lighting, camera effects, ambience, etc.);
- spawn/despawn/move/flip/draw/discard/shuffle and other registered verbs.

Examples:

```text
onPlay -> Match.variables.alert += 1
onDiscard -> source.owner.resources.scrap += 1
onTurnStart where player.faction == "raider" -> player.resources.ammo += 1
onTake -> System.environment.fog_intensity = 0.6
```

The actual implementation must translate these to registered canonical commands/setters; examples above are authoring shorthand.

### Targets

Behaviors need a compact target language, such as:

- `self`
- `actor`
- `owner`
- `holder`
- `source`
- `target`
- explicit object/player ID
- objects by tag/component/slot/zone query
- `Match`
- `Game`
- `System.environment`

Queries must resolve deterministically and be visibility/permission aware.

### Chaining and safety

Declarative behavior chains must be ordered, bounded and observable. Required protections:

- maximum chain depth / action count;
- loop detection or event-causality IDs;
- deterministic ordering;
- idempotency where external commands can retry;
- all resulting commands/events recorded in the parent command result/history;
- precise validation errors for invalid targets/properties/actions.

This follows the existing BGO rule that listeners consume canonical events and issue normal commands rather than mutating state directly.

## Authoring UX in Godot desktop

Prefer leveraging Godot's existing Scene Tree, Inspector, gizmos and `@tool` nodes instead of rebuilding a full scene editor.

Initial BGO authoring UI should focus on:

```text
Create/Open GamePackage
Component / Variant browser
Create Variant
Add/remove BGO feature nodes
Editable effective property map
Behavior editor (event / condition / actions)
Validate
Create setup instances
Preview / Play Sandbox
Export GamePackage
```

The Inspector can remain the detailed editor for custom nodes. A BGO dock provides game-package context, variant inheritance, validation and high-level workflows.

## Example: post-apocalyptic terrain game

```text
WastelandTileVariant
└── BgoGameObject3D
    ├── BgoModelRepresentation
    ├── BgoPbrMaterial
    ├── BgoPlaceable
    └── BgoSurface
        └── BgoSlotLayout

RaiderVariant
└── BgoGameObject3D
    ├── BgoBillboardRepresentation
    ├── BgoPlaceable
    ├── BgoRotatable
    ├── BgoStats
    └── BgoBehavior
        onTake -> Match.variables.alert += 1
```

The table itself may expose a staggered slot layout for large terrain tiles; each terrain tile may expose a secondary layout for units. Composition is recursive, while domain placement/occupancy remains authoritative.

## Non-negotiable boundary

Node composition is the Godot authoring/presentation model. It must not become a second source of gameplay truth.

- Game = definitions, component variants, authored behaviors/rules.
- Match = current instances, players, variables, flow and state.
- System = environment/application-level capabilities.
- Godot custom nodes = editor/runtime adapters that expose and render those concepts.

All mutations caused by Behavior nodes, UI, MCP, GitHub or human interaction converge on the same canonical command/property validation layer.
