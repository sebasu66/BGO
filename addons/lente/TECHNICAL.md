# Lente technical documentation

This document describes Lente 0.9999’s runtime and editor architecture, state ownership, movement math, collision behavior, rendering pipeline, persistence formats, and extension points. The public surface is summarized separately in [API.md](API.md).

## Supported environment

- Godot 4.4.1 is the validated baseline.
- Forward+ is the primary renderer. Compatibility capture is also validated, but Godot does not provide depth of field in Compatibility.
- The add-on is pure GDScript and standard Godot resources. It installs no autoload and ships no native library.
- The root viewport must have an active `Camera3D` unless one is passed explicitly to `enter_photo_mode()`.

## Source layout

| Path | Responsibility |
|---|---|
| `lente.gd` | `EditorPlugin`: gizmo/Inspector registration, toolbar button, persistent default input actions |
| `runtime/lente_photo_mode.gd` | Session controller, runtime rig, state restoration, movement, lens, capture, presets/gallery |
| `runtime/lente_input.gd` | Idempotent default Input Map creation |
| `runtime/lente_localization.gd` | Add-on-local locale selection, catalog registration, and English fallback |
| `runtime/bounds/lente_bound_volume.gd` | Bound-volume interface and shared utilities |
| `runtime/bounds/lente_*_bound.gd` | Box, sphere, and Curve3D corridor signed-distance implementations |
| `editor/lente_bounds_gizmo.gd` | 3D editor visualization and selection collision segments |
| `editor/lente_inspector.gd` | Inspector quick-add controls with UndoRedo support |
| `ui/lente_default_ui.gd` | Default signal/command UI, gallery, preset controls, translations |
| `ui/lente_post_process.gdshader` | Live-view and capture color-filter shader |
| `locales/*.po` | Runtime-registered translations |

## Runtime ownership

`LentePhotoMode` is the only node developers place. Session-only children are created on entry and queued for deletion on teardown:

```text
LentePhotoMode
├─ LenteRuntimeRig (CharacterBody3D, top-level, PROCESS_MODE_ALWAYS)
│  ├─ CameraCollision (CollisionShape3D / SphereShape3D)
│  └─ LenteCamera (Camera3D)
├─ LentePostProcess (CanvasLayer 90)
│  └─ ColorRect + ShaderMaterial
├─ LenteInterface (CanvasLayer 100, unless custom UI is already a CanvasLayer)
│  └─ instantiated UI scene
└─ LenteShutter (AudioStreamPlayer / generated AudioStreamGenerator)
```

The rig is `top_level`, so transforms on the authored controller node do not alter the captured gameplay-camera transform.

## Session state machine

```text
INACTIVE ── enter_photo_mode() succeeds ──► ACTIVE
   ▲                                          │
   │                                          │ exit_photo_mode()
   │                                          ▼
   └──────── teardown/restoration ◄─────── EXITING
                         immediate exit skips the animated interval
```

A static weak reference arbitrates ownership across every `LentePhotoMode` instance. A second controller returns `false` from `enter_photo_mode()` while another session is active. Weak ownership avoids retaining freed scenes.

### Entry ordering

1. Resolve and validate the supplied/current gameplay camera.
2. Record global ownership, camera transform/FOV, `SceneTree.paused`, mouse mode, and GUI focus owner.
3. Build the initial lens/filter state and deep-copy source `CameraAttributes` when present.
4. Resolve assigned game screen-filter paths, record original visibility, and apply the configured initial include/remove policy.
5. Create the runtime `CharacterBody3D`, spherical collision shape, and copied `Camera3D`.
6. Discover descendant bound volumes and validate whether the entry point is inside their union.
7. Create post-processing, UI, and procedural shutter-audio nodes.
8. Record and promote keep-alive group process modes.
9. Pause the tree if configured, capture the mouse, and make the Lente camera current.
10. Connect source-camera destruction handling, load presets, emit state, then emit `entered`.

The camera is copied at the gameplay camera’s exact transform before it becomes current. Neutral post-processing is mathematically a no-op, so the initial frame does not intentionally recompose the view.

### Exit and restoration ordering

A normal exit interpolates the rig transform and FOV to the current source-camera view with a smoothstep curve. Teardown then:

1. disconnects the source-camera signal;
2. restores or clears the active camera;
3. restores every keep-alive node’s exact prior `process_mode`;
4. restores every surviving assigned screen filter’s exact prior local visibility;
5. restores the prior `SceneTree.paused` value rather than assuming it was `false`;
6. restores mouse mode and the previous valid focus owner;
7. queues every runtime child for deletion;
8. clears static ownership and emits `exited`.

If the source camera is destroyed, teardown runs immediately without trying to dereference it. If capture is in progress, a normal exit is deferred until the image operation finishes.

## Input architecture

`LenteInput.ensure_defaults(true)` runs in the editor plugin. For every absent action, it writes a deadzone and default events to `ProjectSettings` and `InputMap`; it never changes an existing action. `ensure_defaults(false)` also runs at runtime as a resilience measure for projects that instantiated the script without first enabling the editor plugin.

The entry listener reads the exported `activation_action`, which defaults to `lente_toggle`. It is therefore safe to:

- rebind `lente_toggle` in the Input Map;
- point `activation_action` at a game-owned action;
- use an empty action to disable automatic entry;
- call `enter_photo_mode()`, `exit_photo_mode()`, or `toggle_photo_mode()` from an external router.

Steam Input and similar platform APIs should call `toggle_photo_mode()` on a digital-action pressed edge unless the integration already emits real Godot `InputEvent`s.

## Flight motion

Mouse motion updates target yaw/pitch. Right-stick action strength applies angular velocity. Pitch is clamped to ±89 degrees; roll is clamped to ±45 degrees. The rig’s current quaternion is slerped toward the target using an exponential response:

```text
weight = 1 - exp(-rotation_smoothing × delta)
```

Movement combines camera-local right/forward directions with world-space vertical movement. Input is normalized, scaled by normal/boost/slow speed, and approached with `acceleration` or `deceleration` using `Vector3.move_toward()`.

## Solid-world collision

World collision uses a floating `CharacterBody3D` with:

- `collision_layer = 0`: the camera is not an obstacle to other bodies;
- `collision_mask = collision_mask` only when armed;
- a spherical shape sized by `collision_radius`;
- `safe_margin = collision_safe_margin`;
- `max_slides = collision_max_slides`.

The sphere is rotation-invariant and has no corners, which makes it appropriate for a freely rolling camera.

### Sliding

After velocity smoothing and soft-boundary damping, the controller calls `CharacterBody3D.move_and_slide()`. For a surface normal `n`, the conceptual tangent response is:

```text
normal_component  = velocity · n
tangent_velocity  = velocity - n × normal_component
```

Godot performs this response and may repeat it for up to `collision_max_slides` contacts during the move. Motion into a wall is removed while motion along it remains. In floating motion mode every contact is treated as a wall; floor-specific gravity/slope behavior does not apply.

### Initial-overlap bypass

A source camera is commonly a child of a player `CharacterBody3D`, which means the camera point begins inside the player capsule. Enabling the camera body immediately would invoke penetration recovery and can produce a visible shove, jitter, or sticky first movement.

At rig creation, Lente performs a `PhysicsShapeQueryParameters3D` overlap query using the camera sphere and `collision_mask`. When an overlap exists:

- `collision_started_overlapping` becomes `true`;
- the body mask remains zero (`collision_armed = false`);
- each physics tick repeats the read-only sphere query;
- once the sphere is clear, the configured mask is assigned and sliding arms permanently for that session.

This lets the player fly out of their own capsule without a teleport. It intentionally applies to any initial body overlap, including a gameplay camera already embedded in a wall.

### Why sliding can still feel awkward

Sliding works against the physics representation, not the visible art. Dense triangle meshes, small props, invisible gameplay blockers, doorway trim, or an oversized sphere can produce many rapidly changing normals. Velocity inertia can also continue pressing into a wall for several frames, leaving only the tangent component and making the motion feel magnetized.

Recommended production setup:

- create a dedicated photo-camera collision layer with simplified walls and major level shells;
- omit characters, foliage, tiny props, triggers, and navigation blockers;
- use `collision_radius` around `0.10–0.22` depending on scene scale;
- keep `collision_safe_margin` close to `0.003`;
- use two to four maximum slides;
- disable collision entirely if authored bounds already prevent undesirable framing.

`set_world_collision_enabled(false)` changes the mask immediately. It does not disable movement bounds.

## Movement bounds

Bounds and solid collision run independently. Bound volumes return a signed margin:

- positive inside the volume;
- zero on its surface;
- negative outside.

The union margin is the maximum margin returned by all volumes. A point is allowed when any child volume contains it.

| Volume | Margin model | Closest-point model |
|---|---|---|
| Box | distance to nearest oriented box face; negative Euclidean distance outside | component-wise clamp in local space |
| Sphere | `radius - distance(center, point)` | radial projection to the shell |
| Path | `radius - distance(closest Curve3D sample, point)` | radial projection around the closest baked curve point |

When there are no authored volumes, the same operations use a sphere centered at the session entry position with `fallback_radius`.

### Soft edge

Inside `soft_boundary_distance`, Lente estimates the inward signed-distance gradient with centered finite differences on X/Y/Z. Only the outward component of velocity is attenuated using `smoothstep(0, soft_boundary_distance, margin)`. Tangential and inward motion remain available. If numerical integration reaches a negative margin, the camera is projected to the closest point in the union and only remaining outward velocity is removed.

This “thick glass” effect can resemble collision. Set `soft_boundary_distance = 0` during diagnosis to separate the two systems.

## Lens and post-processing

The runtime camera copies projection, FOV/size, clip planes, aspect behavior, cull mask, offsets, environment, compositor, and duplicated attributes from the gameplay camera.

When practical lens controls are first required, Lente uses `CameraAttributesPractical`:

- exposure multiplier is `source_multiplier × 2^EV`;
- focus distance and aperture derive near/far DOF thresholds, transitions, and blur amount;
- DOF is disabled until explicitly enabled or a focus ray hits a subject.

The full-screen shader samples `hint_screen_texture`, applies the selected predefined filter, blends it using `filter_strength`, then applies temperature, saturation, contrast, and radial vignette. Filter indices are stable and exposed by `get_filter_names()`.

Filter selection is intentionally an operation rather than a cosmetic menu change. `apply_filter_preset()` copies the selected look’s recommended strength, vignette, saturation, contrast, and temperature into `_settings`, normalizes them, refreshes the shader uniforms, and emits one state update. The default UI therefore updates every affected slider. Direct `set_parameter(&"filter", index)` calls use this same path. Later individual adjustments remain independent.

## Game-owned screen filters

Lente never discovers arbitrary `ColorRect` nodes automatically. The developer supplies `screen_filter_paths`, an ordered array of paths relative to the `LentePhotoMode` node. Explicit ownership prevents HUD backgrounds, fades, menus, and unrelated overlays from entering photographs accidentally.

At session entry, `_collect_screen_filters()` validates each path and accepts only `ColorRect` instances. Every accepted record contains:

- a weak reference, so Lente does not retain a filter whose gameplay scene is freed;
- its original local `visible` value, used for live-view changes and exact teardown restoration;
- its entry-time `is_visible_in_tree()` result, used to decide whether the pass belongs in captures.

The active value begins from `include_screen_filters`. `_apply_screen_filter_visibility()` uses `original_visible && screen_filters_enabled`, so enabling the feature cannot reveal a rectangle that the game had already hidden. Missing/freed nodes are skipped safely. `_restore_screen_filters()` runs before the original pause state is restored and writes back the saved local visibility for every surviving node.

`allow_player_screen_filter_toggle` controls presentation, not the underlying API. The default UI shows **Keep game filter** only when the property is enabled and the active session resolved at least one rectangle. Custom integrations may always call `set_screen_filters_enabled()` or set the `screen_filters_enabled` state parameter directly.

### Capture reproduction

The main gameplay `CanvasLayer` tree is not part of a `SubViewport` that merely shares its `World3D`. For every originally visible assigned filter, `_add_screen_filters_to_capture()` therefore creates a capture-local, full-rect `ColorRect` and copies:

- `color`, `modulate`, and `self_modulate`;
- `material` (the same live resource, including current shader parameters);
- `texture_filter` and `texture_repeat`.

These passes are inserted in the developer-supplied path order before Lente's own capture grading pass. This matches the common arrangement where the game's filter layer is below Lente's runtime post-process layer 90. If exact compositing parity matters, keep the source filter `CanvasLayer` below layer 90 and place multiple paths in their intended draw order.

Only the visual pass owned by the rectangle is reproduced. Children, scripts, parent transforms, parent `CanvasLayer` settings, `BackBufferCopy` siblings, and other external canvas dependencies are deliberately not cloned. A conventional full-screen `ShaderMaterial`, including one using `hint_screen_texture`, is the supported design: its screen texture is evaluated against the high-resolution capture viewport.

When the player choice is disabled, preset saves remove `screen_filters_enabled` and preset loads ignore that key. This preserves the developer-fixed policy even when an old or externally edited preset contains a conflicting value. Capture metadata still records the effective value through the complete settings snapshot.

## Localization

`LenteLocalization` loads the `en`, `it`, and `es` PO resources once and registers them with `TranslationServer`. Its own lookup uses the language component of `TranslationServer.get_locale()` (`es_MX` → `es`) and selects `en` for unsupported languages. This guarantees Lente’s English fallback without mutating the host project’s global fallback setting.

The default UI resolves strings while it is built. Games that change `TranslationServer` locale at runtime should do so before entering photo mode; a newly created Lente interface uses the new locale.

## Capture pipeline

1. Derive target resolution from root viewport size × `capture_scale`.
2. Reduce proportionally if either axis exceeds `maximum_capture_dimension`.
3. Create a session child `SubViewport` sharing the main `World3D`.
4. Apply configured MSAA and copy the live Lente camera.
5. Reproduce every enabled, originally visible assigned game screen filter in configured path order.
6. Add Lente's capture-local post-process rectangle using a fresh material with current uniforms.
7. Wait for a bounded number of process frames for `RenderingServer.frame_post_draw`.
8. Read the `ViewportTexture` into an `Image`, save PNG, then write the JSON sidecar.

The bounded draw wait matters because `--headless` deliberately has no rendering backend and never emits a normal drawn frame. Lente reports an empty-capture failure instead of suspending the coroutine forever.

### Metadata schema

Sidecars use `format_version: 1` and contain:

```text
plugin, engine, project, captured_at, path, resolution,
camera { position, rotation_degrees, near, far, cull_mask },
settings { all lens/filter values }, boundary
```

PNG and JSON share a timestamped basename. The gallery scans PNG files newest-first and reads an optional matching JSON file.

An empty `gallery_directory` is automatic. `get_gallery_directory()` requests `OS.SYSTEM_DIR_DOCUMENTS`, appends the sanitized `application/config/name` and lowercase `screenshots`, and returns that absolute path. `OS.get_system_dir()` is important: it honors the actual Windows Known Folder, Linux XDG user-directory configuration, and macOS Documents location, so translated display names must never be guessed. If the API returns no directory—or recursive creation fails—the capture retries under `user://screenshots`. An explicit non-empty `gallery_directory` bypasses automatic resolution.

## Preset persistence

Presets default to `user://lente/presets.json` as a dictionary keyed by user-visible name. Each value is a snapshot of the settings dictionary. Loading clamps every value through current controller limits, making old or externally edited presets safe. The game screen-filter choice is persisted only when `allow_player_screen_filter_toggle` is enabled; otherwise save/load cannot override the Inspector's fixed policy.

## Default UI contract

The assigned scene root may be `Control` or `CanvasLayer`. If it is a `Control`, Lente wraps it in CanvasLayer 100. The root receives `PROCESS_MODE_ALWAYS` and should provide:

```gdscript
signal command_requested(command: StringName, payload: Variant)
func bind_lente(controller: LentePhotoMode) -> void
```

The controller remains authoritative. UIs consume `state_changed` and other signals, then send commands; they do not need paths to internal camera or rig nodes. See [API.md](API.md) for command payloads.

## Extending Lente

### Add a bound type

Inherit `LenteBoundVolume` and implement:

```gdscript
func get_margin(world_position: Vector3) -> float
func get_closest_point(world_position: Vector3) -> Vector3
```

Positive-inside margin semantics are required for union and soft-gradient behavior. Register editor visualization in `lente_bounds_gizmo.gd` if desired.

### Add a predefined filter

Maintain the same append-only index in four places:

1. `LentePhotoMode.FILTER_NAMES` and `FILTER_PRESETS`;
2. `LenteDefaultUI.FILTER_TRANSLATION_KEYS`;
3. the matching branch in `grade_filter()` in `lente_post_process.gdshader`;
4. the filter label in all three PO catalogs.

Appending preserves stored preset indices. Reordering or deleting an existing index is a preset-format breaking change.

### Replace capture storage

Connect `photo_captured` to upload, index, or copy saved files. For a completely different renderer/storage pipeline, fork `capture_photo()` while preserving its capture guard, pending-exit behavior, and `capture_failed` signal semantics.

## Failure handling and invariants

- Only one global Lente session may be active.
- Failure to find a source camera never mutates pause or mouse state.
- Authored bounds that miss the entry point fall back rather than teleporting.
- An already-paused game remains paused after exit.
- Keep-alive process modes are restored individually.
- Destroying the gameplay camera ends the session safely.
- Destroying the controller invokes synchronous teardown from `_exit_tree()`.
- A capture request is ignored while another capture is active.
- A requested normal exit waits for an in-progress capture.

## Performance notes

- Movement uses one `move_and_slide()` call per physics tick.
- The initial-overlap query runs only until collision arms.
- Soft bounds use six margin samples per physics tick near an edge; Curve3D queries use its baked cache.
- Lente grading is one full-screen shader pass in the live viewport and capture viewport. Every enabled assigned game screen filter adds one capture-only full-screen pass.
- Capture memory grows with pixel count and MSAA; `maximum_capture_dimension` is the primary allocation guard.
- Gallery thumbnails resize loaded images to 320 pixels wide and show at most 24 in the default UI.

## Validation

Development checks are under `res://tests`:

```powershell
godot --headless --path . --script res://tests/validate_loads.gd
godot --headless --path . --script res://tests/runtime_smoke.gd
```

`runtime_smoke.gd` covers state restoration, an already-paused tree, duplicate controllers, source-camera destruction, preset round-trips, bound geometry, runtime collision disable, initial player-collider overlap bypass, screen-filter state, and original-visibility restoration. `capture_smoke.gd` requires a real graphics backend and verifies that assigned game filters, Neutral, and Teal & Orange produce distinct pixels. `demo_ui_capture.gd` also requires a real graphics backend.

Useful engine references: [Editor plugins](https://docs.godotengine.org/en/4.4/tutorials/plugins/editor/making_plugins.html), [CharacterBody3D](https://docs.godotengine.org/en/4.4/classes/class_characterbody3d.html), [CameraAttributesPractical](https://docs.godotengine.org/en/4.4/classes/class_cameraattributespractical.html), and [Viewports/capture](https://docs.godotengine.org/en/4.4/tutorials/rendering/viewports.html).
