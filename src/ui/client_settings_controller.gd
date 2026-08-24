class_name BgoClientSettingsController
extends Node

signal settings_changed(values: Dictionary)

const SETTINGS_PATH := "user://client_settings.cfg"
const SECTION := "client"
const DEFAULTS := {
	"dynamic_resolution": true,
	"resolution_scale_min": 0.60,
	"resolution_scale_max": 1.0,
	"quality_3d": 1,
	"lighting_intensity": 1.0,
	"ui_theme_profile": 0,
	"ui_font_scale": 1.0,
	"ui_accent_color": Color("#d7aa4c"),
	"hand_pickup_mode": 0,
	"visual_debug": false,
}
const QUALITY_MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const QUALITY_SHADOW_ATLAS := [1024, 2048, 4096]

var values := DEFAULTS.duplicate(true)
var persistence_enabled := true
var _scene_root: Node3D
var _key_base_energy := 0.85
var _fill_base_energy := 0.65
var _ambient_base_energy := 0.42
var _resolution_timer := 0.0
var _visual_debug_layer: BgoVisualDebugLayer


## Connects settings to a rendered scene, loads persisted values and applies them.
func initialize(scene_root: Node3D) -> void:
	_scene_root = scene_root
	_capture_lighting_baseline()
	_load()
	apply_all()


## Updates one supported setting, applies it immediately and persists the profile.
func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	values[key] = value
	_normalize()
	apply_all()
	_save()
	settings_changed.emit(values.duplicate(true))
	return true


## Restores and persists the default client presentation profile.
func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	apply_all()
	_save()
	settings_changed.emit(values.duplicate(true))


## Applies the complete current profile to viewport quality and scene lighting.
func apply_all() -> void:
	_normalize()
	_apply_resolution()
	_apply_quality()
	_apply_lighting()
	_apply_visual_debug()


func _process(delta: float) -> void:
	if not bool(values["dynamic_resolution"]):
		return
	_resolution_timer += delta
	if _resolution_timer < 1.0:
		return
	_resolution_timer = 0.0
	var viewport := get_viewport()
	var scale := viewport.scaling_3d_scale
	var fps := Engine.get_frames_per_second()
	if fps < 45.0:
		scale -= 0.05
	elif fps > 58.0:
		scale += 0.05
	viewport.scaling_3d_scale = clampf(
		scale, float(values["resolution_scale_min"]), float(values["resolution_scale_max"])
	)


func _capture_lighting_baseline() -> void:
	var key := _scene_root.get_node_or_null("KeyLight") as Light3D
	var fill := _scene_root.get_node_or_null("FillLight") as Light3D
	var world := _scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if key != null:
		_key_base_energy = key.light_energy
	if fill != null:
		_fill_base_energy = fill.light_energy
	if world != null and world.environment != null:
		_ambient_base_energy = world.environment.ambient_light_energy


func _apply_resolution() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if bool(values["dynamic_resolution"]):
		viewport.scaling_3d_scale = clampf(
			viewport.scaling_3d_scale,
			float(values["resolution_scale_min"]),
			float(values["resolution_scale_max"])
		)
	else:
		viewport.scaling_3d_scale = float(values["resolution_scale_max"])


func _apply_quality() -> void:
	var quality := int(values["quality_3d"])
	var viewport := get_viewport()
	viewport.msaa_3d = QUALITY_MSAA[quality]
	viewport.positional_shadow_atlas_size = QUALITY_SHADOW_ATLAS[quality]
	var key := _scene_root.get_node_or_null("KeyLight") as Light3D
	var fill := _scene_root.get_node_or_null("FillLight") as Light3D
	if key != null:
		key.shadow_enabled = quality > 0
	if fill != null:
		fill.shadow_enabled = quality >= 2


func _apply_lighting() -> void:
	var multiplier := float(values["lighting_intensity"])
	var key := _scene_root.get_node_or_null("KeyLight") as Light3D
	var fill := _scene_root.get_node_or_null("FillLight") as Light3D
	var world := _scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if key != null:
		key.light_energy = _key_base_energy * multiplier
	if fill != null:
		fill.light_energy = _fill_base_energy * multiplier
	if world != null and world.environment != null:
		world.environment.ambient_light_energy = _ambient_base_energy * multiplier


func _apply_visual_debug() -> void:
	if _scene_root == null:
		return
	var enabled := bool(values["visual_debug"])
	for node in _all_descendants(_scene_root):
		if is_instance_valid(node) and node is BgoTableGrid:
			var grid := node as BgoTableGrid
			grid.show_points = enabled
			grid.rebuild()
	if _visual_debug_layer == null:
		_visual_debug_layer = BgoVisualDebugLayer.new()
		_visual_debug_layer.name = "VisualDebugLayer"
		_scene_root.add_child(_visual_debug_layer)
		_visual_debug_layer.configure(_scene_root)
	_visual_debug_layer.set_debug_enabled(enabled)


func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _normalize() -> void:
	values["resolution_scale_min"] = clampf(float(values["resolution_scale_min"]), 0.5, 1.0)
	values["resolution_scale_max"] = clampf(float(values["resolution_scale_max"]), 0.5, 1.0)
	if float(values["resolution_scale_min"]) > float(values["resolution_scale_max"]):
		values["resolution_scale_min"] = values["resolution_scale_max"]
	values["quality_3d"] = clampi(int(values["quality_3d"]), 0, 2)
	values["lighting_intensity"] = clampf(float(values["lighting_intensity"]), 0.25, 1.5)
	values["ui_theme_profile"] = clampi(int(values["ui_theme_profile"]), 0, 1)
	values["ui_font_scale"] = clampf(float(values["ui_font_scale"]), 0.8, 1.4)
	values["hand_pickup_mode"] = clampi(int(values["hand_pickup_mode"]), 0, 1)
	if not values["ui_accent_color"] is Color:
		values["ui_accent_color"] = DEFAULTS["ui_accent_color"]


func _load() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in DEFAULTS:
		values[key] = config.get_value(SECTION, key, DEFAULTS[key])
	_normalize()


func _save() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	config.save(SETTINGS_PATH)
