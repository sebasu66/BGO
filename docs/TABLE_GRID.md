# Table grid and Asset Placer integration

BGO exposes a logical point grid through `TabletopState.grid`. The grid is
independent from Godot's 3D nodes and uses centimetres as its domain unit.
Renderers choose their own world-unit scale.

```gdscript
table.configure_grid(16, 10, Vector2(5.0, 5.0))
table.place_object_at_grid("token", Vector2i(2, 3), Vector2i(2, 1))

table.objects_at_grid_point(Vector2i(3, 3))
table.objects_in_grid_area(Vector2i(0, 0), Vector2i(5, 5))
table.object_grid_points("token")
```

An object has one origin point and a rectangular footprint. Placements are
non-overlapping by default; callers can explicitly opt into overlap for future
stack/container behaviors.

## Placeable representation anchors

Every placeable 3D representation uses its root origin on its supporting base;
runtime placement therefore never needs a guessed vertical offset. Small
objects such as pieces, miniatures, dice, cards, tokens and decks use
`base_center`: the horizontal origin is the centre of the base. Large authored
surfaces such as boards should use `base_corner`, aligned with their logical
grid origin. Existing centred board definitions require an explicit placement
migration before changing anchor mode; renderers must not silently move them.

The scene component
`res://src/components/grids/table_grid/table_grid.tscn` provides the editor
and 3D representation. It draws point markers, converts between world space and
grid coordinates, and stores `bgo_table_grid` metadata for editor adapters.

`BgoCheckeredBoard` separates a logical board unit from its centimetre grid.
`grid_cell_size_cm` defines the physical size of one unit and
`grid_points_per_unit` defines its placement resolution. TEST001 uses `5` for
both, producing five one-centimetre points per board unit. Points are centred
inside each centimetre subdivision, so the complete surface is covered without
extending beyond its edges. An `8 x 6` board therefore exposes `40 x 30` points.

Runtime placement is magnetic and deterministic. A board with named slots
resolves to the nearest slot first. If the surface has no slots, it resolves to
the nearest valid fine-grid point and persists a `grid` location with an origin
and footprint. This policy is shared by mouse/touch placement and remote state;
it is not inferred from the rendered mesh.

The main tabletop grid is logically unbounded: signed coordinates remain valid
beyond any board component. Rendering stays sparse for performance. With Visual
Debug enabled, small point patches appear only around physical game objects;
overlapping patches are deduplicated and follow objects as they move. The large
table plane is a visual/picking surface, not a finite logical boundary.

The installed Godot Asset Placer plugin is integrated through
`res://src/editor/bgo_asset_placer_grid_bridge.gd`:

- when a `BgoTableGrid` exists in the edited scene, preview positions snap to
  its points;
- the table grid remains authoritative even if Asset Placer's generic snapping
  option is disabled;
- newly placed nodes receive `bgo_grid_origin`, `bgo_grid_footprint`,
  `bgo_grid_path`, and `bgo_placeable` metadata;
- scenes without a BGO table grid keep the original Asset Placer behavior.

The Asset Placer remains an editor tool. It does not become part of the runtime
domain model; runtime occupancy and range queries use `TabletopState` and
`TableGridState`.

## Asset Box

`AssetBoxState` is the logical catalog/reserve container for assets declared by
a game package. It does **not** track physical positions or occupancy. Asset
Placer's 2D palette/grid is the authoring and presentation surface for that
catalog; the runtime box is only membership, quantity, availability and
ownership data.

The Asset Placer remains an editor tool. At runtime the intended representation
is a viewport-attached drawer/catalog, not a Node3D placed on the tabletop. In
the current TEST001 slice the `ASSET BOX` control toggles the catalog state and
status; interactive instantiation of new copies from the catalog is a next
vertical slice. When an item leaves the box, its physical placement is
validated by `TabletopState.grid`.

Game definitions may declare the catalog and place objects there with an
`initial_location` of type `asset_box`:

```json
"asset_box": {
  "id": "game_box",
  "label": "ASSET BOX"
}
```
