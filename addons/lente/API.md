# Lente public API and UI contract

## Controller methods

### Session

```gdscript
func enter_photo_mode(source_camera: Camera3D = null) -> bool
func exit_photo_mode(immediate := false) -> void
func toggle_photo_mode() -> void
func is_active() -> bool
func set_world_collision_enabled(enabled: bool) -> void
func set_screen_filters_enabled(enabled: bool) -> void
```

When `source_camera` is omitted, Lente uses `get_viewport().get_camera_3d()`. `enter_photo_mode()` returns `false` when no camera is available, this controller is already active, or another controller owns the global photo session. A normal exit performs the configured return flight; an immediate exit restores state synchronously.

`set_world_collision_enabled()` changes solid physics collision immediately. Authored/fallback movement bounds are unaffected.

`set_screen_filters_enabled()` changes whether assigned game-owned screen filters appear in the live photo view and capture viewport for the current session. It is callable by custom UIs even when the default player-facing choice is hidden. Session teardown always restores the assigned nodes' original visibility.

### Lens and interface

```gdscript
func set_parameter(parameter: StringName, value: Variant) -> bool
func reset_parameters() -> void
func focus_at_screen_position(screen_position: Vector2) -> bool
func set_ui_interactive(enabled: bool) -> void
func get_state() -> Dictionary
```

Supported parameter keys and ranges:

| Key | Type | Range / values |
|---|---|---|
| `fov` | float | `minimum_fov` … `maximum_fov` |
| `focus_distance` | float | 0.05 … `maximum_focus_distance` metres |
| `aperture` | float | f/1.4 … f/16 |
| `dof_enabled` | bool | true / false |
| `exposure` | float | −4 … +4 EV |
| `roll` | float | −45° … +45° |
| `filter` | int | 0 Neutral, 1 Cinema, 2 Noir, 3 Warm, 4 Cool, 5 Vintage, 6 Vivid, 7 Bleach Bypass, 8 Teal & Orange, 9 Faded Film, 10 Dream, 11 Night |
| `filter_strength` | float | 0 … 1 |
| `vignette` | float | 0 … 1 |
| `saturation` | float | 0 … 2 |
| `contrast` | float | 0.5 … 1.5 |
| `temperature` | float | −1 … 1 |
| `screen_filters_enabled` | bool | include or remove assigned game-owned `ColorRect` filters |

`get_state()` adds `active`, `exiting`, `ui_interactive`, `capture_in_progress`, `collision_enabled`, `collision_armed`, `collision_started_overlapping`, `boundary`, `screen_filter_choice_available`, `screen_filter_count`, and a sorted `presets` list to the parameter values. `screen_filter_choice_available` is true only when the Inspector allows the player choice and at least one valid filter was resolved for the active session.

### Capture, gallery, and presets

```gdscript
func capture_photo() -> void
func list_photos(limit := 0) -> Array[Dictionary]
func get_gallery_directory() -> String
func save_preset(preset_name: String) -> bool
func load_preset(preset_name: String) -> bool
func delete_preset(preset_name: String) -> bool
func list_presets() -> PackedStringArray
func get_filter_names() -> PackedStringArray
func apply_filter_preset(filter_index: int) -> bool
```

Each `list_photos()` item has `path` and `metadata` keys. Results are newest first. A limit of zero returns every photograph. `get_gallery_directory()` resolves an empty `gallery_directory` to `<OS Documents>/<sanitized project name>/screenshots`, or `user://screenshots` if the system directory is unavailable. A non-empty `gallery_directory` is an explicit override.

`apply_filter_preset()` sets the stable filter index and that look’s recommended `filter_strength`, `vignette`, `saturation`, `contrast`, and `temperature`. `set_parameter(&"filter", index)` has the same preset behavior. Neutral (index 0) restores neutral grade values.

## Game screen-filter integration

The relevant `LentePhotoMode` Inspector properties are:

| Property | Type | Behavior |
|---|---|---|
| `screen_filter_paths` | `Array[NodePath]` | Explicit `ColorRect` paths resolved relative to `LentePhotoMode` when a session begins |
| `include_screen_filters` | bool | Initial fixed/default inclusion value for the session |
| `allow_player_screen_filter_toggle` | bool | Shows the default UI's localized **Keep game filter** control when at least one path resolves |

Assign only full-screen `ColorRect` nodes that form part of the desired photograph. Lente does not search for rectangles automatically, because doing so could capture HUD panels or other unrelated controls. Invalid paths and paths to other node types produce runtime warnings and are skipped.

For every valid path, Lente records the node's local `visible` value and whether it was visible in the tree at entry. Disabling the setting hides only filters that Lente manages. Enabling it never forces a rectangle that was originally hidden to appear. Exit restores each surviving node's original local visibility.

The capture viewport reproduces each originally visible assigned rectangle as a full-screen pass, copying its color, modulation, texture sampling settings, and material. Only the `ColorRect` pass is reproduced; its children, script behavior, parent `CanvasLayer`, and unrelated sibling controls are not copied.

When `allow_player_screen_filter_toggle` is false, new presets omit `screen_filters_enabled` and loading a preset ignores any older value for that key. This prevents player presets from overriding a developer-fixed capture policy. When the player choice is enabled, the value participates in preset save/load normally.

## Input actions

The editor plugin installs actions only when their names are absent. The entry action is `lente_toggle`; `LentePhotoMode.activation_action` selects which action the node listens to. Set it to an empty `StringName` to disable automatic toggling.

The complete action family is `lente_toggle`, `lente_exit`, `lente_move_forward`, `lente_move_back`, `lente_move_left`, `lente_move_right`, `lente_move_up`, `lente_move_down`, `lente_look_left`, `lente_look_right`, `lente_look_up`, `lente_look_down`, `lente_boost`, `lente_slow`, `lente_capture`, `lente_focus`, `lente_roll_left`, `lente_roll_right`, `lente_ui`, `lente_gallery`, `lente_reset`, `lente_zoom_in`, and `lente_zoom_out`.

Platform input systems do not need to synthesize a Godot action. Calling `toggle_photo_mode()` on a Steam Input digital-action pressed edge is a supported first-class integration.

## Signals

```gdscript
signal entered(source_camera: Camera3D)
signal exit_started
signal exited
signal state_changed(state: Dictionary)
signal focus_changed(distance: float, world_position: Vector3)
signal capture_started
signal photo_captured(path: String, metadata: Dictionary)
signal capture_failed(reason: String)
signal message_requested(message: String)
```

Use `exited` when gameplay must wait for the return flight rather than forcing an immediate exit.

## Replaceable UI contract

The root of a custom `ui_scene` should expose:

```gdscript
signal command_requested(command: StringName, payload: Variant)

func bind_lente(controller: LentePhotoMode) -> void:
	# Connect any controller signals needed by the view.
	pass
```

The root runs with `PROCESS_MODE_ALWAYS`. Lente wraps a `Control` root in a high-layer `CanvasLayer`; a `CanvasLayer` root is mounted directly.

Commands accepted by the controller:

| Command | Payload |
|---|---|
| `set_parameter` | `{ "name": StringName, "value": Variant }` |
| `capture` | ignored |
| `focus` | optional `Vector2` screen position; defaults to mouse position |
| `exit` | ignored |
| `reset` | ignored |
| `apply_filter_preset` | filter index (`int`) |
| `set_ui_interactive` | bool |
| `save_preset` | String name |
| `load_preset` | String name |
| `delete_preset` | String name |

The default UI additionally exposes `toggle_gallery()` and `show_toast(message)` for the controller’s default shortcuts and feedback.

## Localization

The default interface uses `TranslationServer.get_locale()` and ships `en`, `it`, and `es` gettext catalogs. Regional variants use their base language; unsupported locales use the English catalog. Set the project locale before `enter_photo_mode()` if the game provides an in-game language selector.

## Typical integration

```gdscript
@onready var photo_mode: LentePhotoMode = $LentePhotoMode

func _on_photo_button_pressed() -> void:
	if photo_mode.enter_photo_mode():
		photo_mode.photo_captured.connect(_on_photo_captured)

func _on_photo_captured(path: String, metadata: Dictionary) -> void:
	print("New photograph: ", path)
```

No autoload is installed. Multiple nodes can exist across scenes, but static session arbitration permits only one active controller at a time.

See [TECHNICAL.md](TECHNICAL.md) for architecture, lifecycle, physics, capture, persistence, and extension details.
