@tool
@icon("res://addons/lente/icons/lente.svg")
class_name LentePhotoMode
extends Node3D

## Drop-in, player-facing 3D photo mode for Godot 4.x.
##
## Call enter_photo_mode() with no arguments to inherit the current Camera3D.

signal entered(source_camera: Camera3D)
signal exit_started
signal exited
signal state_changed(state: Dictionary)
signal focus_changed(distance: float, world_position: Vector3)
signal capture_started
signal photo_captured(path: String, metadata: Dictionary)
signal capture_failed(reason: String)
signal message_requested(message: String)

const DefaultUI := preload("res://addons/lente/ui/lente_default_ui.tscn")
const PostShader := preload("res://addons/lente/ui/lente_post_process.gdshader")
const BoundVolume := preload("res://addons/lente/runtime/bounds/lente_bound_volume.gd")
const InputDefaults := preload("res://addons/lente/runtime/lente_input.gd")
const Localization := preload("res://addons/lente/runtime/lente_localization.gd")

const FILTER_NAMES := [
	"Neutral", "Cinema", "Noir", "Warm", "Cool", "Vintage", "Vivid",
	"Bleach Bypass", "Teal & Orange", "Faded Film", "Dream", "Night",
]
const FILTER_PRESETS := [
	{"filter_strength": 0.0, "vignette": 0.0, "saturation": 1.0, "contrast": 1.0, "temperature": 0.0},
	{"filter_strength": 0.85, "vignette": 0.24, "saturation": 0.92, "contrast": 1.08, "temperature": 0.06},
	{"filter_strength": 1.0, "vignette": 0.28, "saturation": 0.0, "contrast": 1.18, "temperature": 0.0},
	{"filter_strength": 0.8, "vignette": 0.08, "saturation": 1.05, "contrast": 1.03, "temperature": 0.22},
	{"filter_strength": 0.8, "vignette": 0.1, "saturation": 1.02, "contrast": 1.04, "temperature": -0.22},
	{"filter_strength": 0.88, "vignette": 0.32, "saturation": 0.78, "contrast": 0.94, "temperature": 0.16},
	{"filter_strength": 0.78, "vignette": 0.08, "saturation": 1.24, "contrast": 1.12, "temperature": 0.03},
	{"filter_strength": 0.82, "vignette": 0.18, "saturation": 0.68, "contrast": 1.18, "temperature": 0.02},
	{"filter_strength": 0.85, "vignette": 0.2, "saturation": 1.08, "contrast": 1.1, "temperature": 0.04},
	{"filter_strength": 0.9, "vignette": 0.3, "saturation": 0.76, "contrast": 0.88, "temperature": 0.1},
	{"filter_strength": 0.72, "vignette": 0.22, "saturation": 0.9, "contrast": 0.92, "temperature": -0.04},
	{"filter_strength": 0.9, "vignette": 0.36, "saturation": 0.72, "contrast": 1.12, "temperature": -0.28},
]

enum SessionState { INACTIVE, ACTIVE, EXITING }

static var _active_controller: WeakRef

@export_group("Activation")
@export var activation_action: StringName = &"lente_toggle"
@export var pause_world := true
@export var continue_processing_groups: PackedStringArray = PackedStringArray(["lente_unpaused"])
@export_range(0.0, 2.0, 0.01) var exit_flight_duration := 0.42

@export_group("Movement")
@export_range(0.1, 100.0, 0.1, "or_greater") var movement_speed := 7.0
@export_range(1.0, 10.0, 0.1) var boost_multiplier := 3.0
@export_range(0.05, 1.0, 0.01) var slow_multiplier := 0.25
@export_range(0.1, 100.0, 0.1) var acceleration := 20.0
@export_range(0.1, 100.0, 0.1) var deceleration := 14.0
@export_range(0.01, 1.0, 0.001) var mouse_sensitivity := 0.12
@export_range(10.0, 360.0, 1.0) var gamepad_look_speed := 115.0
@export_range(1.0, 40.0, 0.1) var rotation_smoothing := 18.0
@export_range(1.0, 180.0, 1.0) var roll_speed := 55.0

@export_group("World collision")
@export var collision_enabled := true
@export_flags_3d_physics var collision_mask := 1
@export_range(0.02, 2.0, 0.01) var collision_radius := 0.22
@export_range(0.001, 0.1, 0.001) var collision_safe_margin := 0.003
@export_range(1, 8, 1) var collision_max_slides := 4

@export_group("Movement boundary")
@export_range(0.5, 1000.0, 0.1, "or_greater") var fallback_radius := 12.0
@export_range(0.0, 20.0, 0.1) var soft_boundary_distance := 2.5

@export_group("Lens limits")
@export_range(1.0, 179.0, 1.0) var minimum_fov := 20.0
@export_range(1.0, 179.0, 1.0) var maximum_fov := 120.0
@export_range(0.1, 10000.0, 0.1) var maximum_focus_distance := 500.0
@export_flags_3d_physics var focus_collision_mask := 0xFFFFFFFF

@export_group("Capture")
@export_range(1.0, 4.0, 0.25) var capture_scale := 2.0
@export_range(1024, 16384, 1) var maximum_capture_dimension := 7680
@export_enum("Disabled:0", "2× MSAA:1", "4× MSAA:2", "8× MSAA:3") var capture_msaa: int = Viewport.MSAA_4X
## Optional override. Empty uses the OS Documents directory: <project>/screenshots.
@export_global_dir var gallery_directory := ""
@export var preset_file := "user://lente/presets.json"

@export_group("Game screen filters")
## ColorRects used by the game for full-screen shaders or color filters.
## Paths are resolved relative to this LentePhotoMode node.
@export var screen_filter_paths: Array[NodePath] = []
## Keeps assigned, originally visible filters in the photo-mode preview and PNG.
@export var include_screen_filters := true
## Exposes a "Keep game filter" switch in the default photo-mode interface.
## When disabled, include_screen_filters is fixed by the developer.
@export var allow_player_screen_filter_toggle := false

@export_group("Interface")
@export var ui_scene: PackedScene

var _session_state := SessionState.INACTIVE
var _source_camera_ref: WeakRef
var _rig: CharacterBody3D
var _camera: Camera3D
var _post_layer: CanvasLayer
var _post_material: ShaderMaterial
var _ui_layer: CanvasLayer
var _ui_root: Node
var _audio_player: AudioStreamPlayer
var _collision_node: CollisionShape3D
var _collision_sphere: SphereShape3D
var _collision_armed := false
var _collision_started_overlapping := false
var _bounds: Array[Node] = []
var _use_fallback_boundary := true
var _fallback_center := Vector3.ZERO
var _boundary_description := "Entry bubble"

var _settings: Dictionary = {}
var _initial_settings: Dictionary = {}
var _presets: Dictionary = {}
var _original_attributes: CameraAttributes
var _base_exposure_multiplier := 1.0
var _home_transform := Transform3D.IDENTITY
var _home_fov := 75.0
var _target_yaw := 0.0
var _target_pitch := 0.0
var _target_roll := 0.0
var _ui_interactive := false

var _was_tree_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _previous_focus_ref: WeakRef
var _keep_alive_records: Array[Dictionary] = []
var _screen_filter_records: Array[Dictionary] = []
var _capture_in_progress := false
var _pending_exit := false
var _gallery_fallback_in_use := false

var _exit_elapsed := 0.0
var _exit_from := Transform3D.IDENTITY
var _exit_to := Transform3D.IDENTITY
var _exit_fov_from := 75.0
var _exit_fov_to := 75.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.ensure_registered()
	InputDefaults.ensure_defaults(false)
	set_process(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _session_state != SessionState.INACTIVE:
		_teardown_session(false)


func _process(delta: float) -> void:
	if _session_state != SessionState.EXITING or not _rig or not _camera:
		return
	_exit_elapsed += delta
	var duration := maxf(exit_flight_duration, 0.001)
	var amount := clampf(_exit_elapsed / duration, 0.0, 1.0)
	var eased := amount * amount * (3.0 - 2.0 * amount)
	_rig.global_transform = _exit_from.interpolate_with(_exit_to, eased)
	_camera.fov = lerpf(_exit_fov_from, _exit_fov_to, eased)
	if amount >= 1.0:
		_teardown_session(true)


func _physics_process(delta: float) -> void:
	if _session_state != SessionState.ACTIVE or not _rig or not _camera:
		return
	_update_rotation(delta)
	_update_movement(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _session_state != SessionState.INACTIVE:
		return
	if _event_action_pressed(event, activation_action):
		enter_photo_mode()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _session_state == SessionState.INACTIVE:
		return
	if _event_action_pressed(event, &"lente_exit") or _event_action_pressed(event, activation_action):
		exit_photo_mode()
		get_viewport().set_input_as_handled()
		return
	if _session_state != SessionState.ACTIVE:
		return
	if _event_action_pressed(event, &"lente_capture"):
		capture_photo()
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_ui"):
		set_ui_interactive(not _ui_interactive)
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_gallery"):
		if _ui_root and _ui_root.has_method("toggle_gallery"):
			_ui_root.call("toggle_gallery")
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_reset"):
		reset_parameters()
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_focus") and not _ui_interactive:
		focus_at_screen_position(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_zoom_in"):
		set_parameter(&"fov", float(_settings.fov) - 2.0)
		get_viewport().set_input_as_handled()
	elif _event_action_pressed(event, &"lente_zoom_out"):
		set_parameter(&"fov", float(_settings.fov) + 2.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_target_pitch -= deg_to_rad(event.relative.y * mouse_sensitivity)
		_target_pitch = clampf(_target_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		get_viewport().set_input_as_handled()


## Enters photo mode using source_camera, or the current viewport camera when omitted.
func enter_photo_mode(source_camera: Camera3D = null) -> bool:
	if Engine.is_editor_hint() or _session_state != SessionState.INACTIVE:
		return false
	var active := _active_controller.get_ref() if _active_controller else null
	if is_instance_valid(active) and active != self:
		_request_message(Localization.text(&"LENTE_ERROR_ALREADY_ACTIVE"))
		return false
	if not source_camera:
		source_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(source_camera) or not source_camera.is_inside_tree():
		_request_message(Localization.text(&"LENTE_ERROR_NO_CAMERA"))
		return false
	_active_controller = weakref(self)
	_source_camera_ref = weakref(source_camera)
	_home_transform = source_camera.global_transform
	_home_fov = source_camera.fov
	_fallback_center = _home_transform.origin
	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	var focus_owner := get_viewport().gui_get_focus_owner()
	_previous_focus_ref = weakref(focus_owner) if focus_owner else null
	_setup_settings(source_camera)
	_collect_screen_filters()
	_setup_rig(source_camera)
	_collect_bounds()
	_setup_post_process()
	_setup_interface()
	_setup_shutter_audio()
	_apply_keep_alive_groups()
	if pause_world:
		get_tree().paused = true
	_session_state = SessionState.ACTIVE
	set_ui_interactive(false)
	_camera.make_current()
	if not source_camera.tree_exiting.is_connected(_on_source_camera_exiting):
		source_camera.tree_exiting.connect(_on_source_camera_exiting, CONNECT_ONE_SHOT)
	_presets = _read_json_dictionary(preset_file)
	_emit_state()
	entered.emit(source_camera)
	return true


## Begins the return flight and restores the game state when it completes.
func exit_photo_mode(immediate := false) -> void:
	if _session_state == SessionState.INACTIVE:
		return
	if _capture_in_progress and not immediate:
		_pending_exit = true
		_request_message(Localization.text(&"LENTE_FINISHING_PHOTO"))
		return
	if immediate or exit_flight_duration <= 0.0 or not _rig or not _camera:
		_teardown_session(true)
		return
	_session_state = SessionState.EXITING
	_ui_interactive = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_exit_elapsed = 0.0
	_exit_from = _rig.global_transform
	_exit_to = _home_transform
	_exit_fov_from = _camera.fov
	_exit_fov_to = _home_fov
	var source := _get_source_camera()
	if source:
		_exit_to = source.global_transform
		_exit_fov_to = source.fov
	exit_started.emit()
	_emit_state()


func toggle_photo_mode() -> void:
	if is_active():
		exit_photo_mode()
	else:
		enter_photo_mode()


func is_active() -> bool:
	return _session_state != SessionState.INACTIVE


func set_ui_interactive(enabled: bool) -> void:
	if _session_state == SessionState.INACTIVE:
		return
	_ui_interactive = enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED
	_emit_state()


## Enables or disables solid-world collision immediately, including mid-session.
func set_world_collision_enabled(enabled: bool) -> void:
	collision_enabled = enabled
	if not _rig:
		return
	if _collision_node:
		_collision_node.disabled = not enabled
	if not enabled:
		_collision_armed = false
		_rig.collision_mask = 0
	else:
		_collision_armed = false
		_refresh_collision_arming()
	_emit_state()


## Includes or removes the assigned game screen filters for this session.
## This remains callable from custom UIs even when the default UI choice is hidden.
func set_screen_filters_enabled(enabled: bool) -> void:
	_settings.screen_filters_enabled = enabled
	_apply_screen_filter_visibility()
	_emit_state()


func set_parameter(parameter: StringName, value: Variant) -> bool:
	if not _settings.has(parameter):
		return false
	match parameter:
		&"fov":
			_settings[parameter] = clampf(float(value), minimum_fov, maximum_fov)
			_ensure_practical_attributes()
			if _camera:
				_camera.fov = float(_settings[parameter])
		&"focus_distance":
			_settings[parameter] = clampf(float(value), 0.05, maximum_focus_distance)
			_apply_depth_of_field()
		&"aperture":
			_settings[parameter] = clampf(float(value), 1.4, 16.0)
			_apply_depth_of_field()
		&"dof_enabled":
			_settings[parameter] = bool(value)
			_apply_depth_of_field()
		&"exposure":
			_settings[parameter] = clampf(float(value), -4.0, 4.0)
			_apply_exposure()
		&"roll":
			_settings[parameter] = clampf(float(value), -45.0, 45.0)
			_target_roll = deg_to_rad(float(_settings[parameter]))
		&"filter":
			return apply_filter_preset(int(value))
		&"filter_strength", &"vignette":
			_settings[parameter] = clampf(float(value), 0.0, 1.0)
			_apply_post_process()
		&"saturation":
			_settings[parameter] = clampf(float(value), 0.0, 2.0)
			_apply_post_process()
		&"contrast":
			_settings[parameter] = clampf(float(value), 0.5, 1.5)
			_apply_post_process()
		&"temperature":
			_settings[parameter] = clampf(float(value), -1.0, 1.0)
			_apply_post_process()
		&"screen_filters_enabled":
			_settings[parameter] = bool(value)
			_apply_screen_filter_visibility()
		_:
			return false
	_emit_state()
	return true


func reset_parameters() -> void:
	_settings = _initial_settings.duplicate(true)
	if _camera:
		_camera.attributes = _original_attributes.duplicate(true) if _original_attributes else null
		_camera.fov = float(_settings.fov)
	_target_roll = deg_to_rad(float(_settings.roll))
	_apply_post_process()
	_apply_screen_filter_visibility()
	_emit_state()


## Applies a complete predefined look and updates all related grade controls.
func apply_filter_preset(filter_index: int) -> bool:
	if filter_index < 0 or filter_index >= FILTER_PRESETS.size():
		return false
	_settings.filter = filter_index
	var preset: Dictionary = FILTER_PRESETS[filter_index]
	for key in preset:
		_settings[key] = preset[key]
	_normalize_settings()
	_apply_post_process()
	_emit_state()
	return true


func focus_at_screen_position(screen_position: Vector2) -> bool:
	if _session_state != SessionState.ACTIVE or not _camera or not _camera.is_inside_tree():
		return false
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + _camera.project_ray_normal(screen_position) * maximum_focus_distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, focus_collision_mask)
	if _rig:
		query.exclude = [_rig.get_rid()]
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_request_message(Localization.text(&"LENTE_NO_FOCUS_SUBJECT"))
		return false
	var distance := _camera.global_position.distance_to(hit.position)
	_settings.focus_distance = clampf(distance, 0.05, maximum_focus_distance)
	_settings.dof_enabled = true
	_apply_depth_of_field()
	_emit_state()
	focus_changed.emit(float(_settings.focus_distance), hit.position)
	return true


## Captures a supersampled PNG and JSON sidecar in gallery_directory.
func capture_photo() -> void:
	if _session_state != SessionState.ACTIVE or _capture_in_progress or not _camera:
		return
	_capture_in_progress = true
	capture_started.emit()
	_play_shutter_sound()
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var output_size := Vector2i(maxi(2, roundi(viewport_size.x * capture_scale)), maxi(2, roundi(viewport_size.y * capture_scale)))
	var largest := maxi(output_size.x, output_size.y)
	if largest > maximum_capture_dimension:
		var ratio := float(maximum_capture_dimension) / float(largest)
		output_size = Vector2i(maxi(2, roundi(output_size.x * ratio)), maxi(2, roundi(output_size.y * ratio)))
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "LenteCaptureViewport"
	capture_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	capture_viewport.size = output_size
	capture_viewport.world_3d = get_viewport().world_3d
	capture_viewport.msaa_3d = capture_msaa
	capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture_viewport)
	var capture_camera := Camera3D.new()
	_copy_camera_properties(_camera, capture_camera)
	capture_viewport.add_child(capture_camera)
	capture_camera.global_transform = _camera.global_transform
	capture_camera.make_current()
	_add_screen_filters_to_capture(capture_viewport)
	var capture_grade := ColorRect.new()
	capture_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capture_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture_grade.material = _make_post_material()
	capture_viewport.add_child(capture_grade)
	# Use a bounded signal wait: headless builds deliberately never draw frames.
	var draw_state := [false]
	var on_frame_drawn := func(): draw_state[0] = true
	RenderingServer.frame_post_draw.connect(on_frame_drawn, CONNECT_ONE_SHOT)
	for _wait_frame in 8:
		await get_tree().process_frame
		if draw_state[0]:
			break
	if RenderingServer.frame_post_draw.is_connected(on_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(on_frame_drawn)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var image := capture_viewport.get_texture().get_image()
	var error_message := ""
	var saved_path := ""
	var metadata: Dictionary = {}
	if not image or image.is_empty():
		error_message = Localization.text(&"LENTE_CAPTURE_EMPTY")
	else:
		var capture_directory := get_gallery_directory()
		var absolute_directory := ProjectSettings.globalize_path(capture_directory)
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error != OK and gallery_directory.strip_edges().is_empty() and not _gallery_fallback_in_use:
			_gallery_fallback_in_use = true
			capture_directory = get_gallery_directory()
			absolute_directory = ProjectSettings.globalize_path(capture_directory)
			directory_error = DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error != OK:
			error_message = Localization.text(&"LENTE_GALLERY_CREATE_FAILED") % directory_error
		else:
			var base_name := _make_capture_name()
			saved_path = capture_directory.path_join(base_name + ".png")
			var save_error := image.save_png(ProjectSettings.globalize_path(saved_path))
			if save_error != OK:
				error_message = Localization.text(&"LENTE_PHOTO_SAVE_FAILED") % save_error
				saved_path = ""
			else:
				metadata = _make_capture_metadata(saved_path, output_size)
				_write_json(capture_directory.path_join(base_name + ".json"), metadata)
	capture_viewport.queue_free()
	_capture_in_progress = false
	if error_message.is_empty():
		photo_captured.emit(saved_path, metadata)
	else:
		capture_failed.emit(error_message)
		_request_message(error_message)
	if _pending_exit:
		_pending_exit = false
		exit_photo_mode()


func save_preset(preset_name: String) -> bool:
	var clean_name := preset_name.strip_edges().left(64)
	if clean_name.is_empty():
		return false
	var snapshot := _settings_snapshot()
	if not allow_player_screen_filter_toggle:
		snapshot.erase("screen_filters_enabled")
	_presets[clean_name] = snapshot
	if not _write_json(preset_file, _presets):
		return false
	_emit_state()
	return true


func load_preset(preset_name: String) -> bool:
	if not _presets.has(preset_name) or not _presets[preset_name] is Dictionary:
		return false
	var preset: Dictionary = _presets[preset_name]
	for key in _settings.keys():
		if key == "screen_filters_enabled" and not allow_player_screen_filter_toggle:
			continue
		if preset.has(key):
			_settings[key] = preset[key]
	_normalize_settings()
	_apply_all_settings()
	_emit_state()
	return true


func delete_preset(preset_name: String) -> bool:
	if not _presets.erase(preset_name):
		return false
	_write_json(preset_file, _presets)
	_emit_state()
	return true


func list_presets() -> PackedStringArray:
	var names := PackedStringArray()
	for preset_name in _presets:
		names.append(str(preset_name))
	names.sort()
	return names


func get_filter_names() -> PackedStringArray:
	return PackedStringArray(FILTER_NAMES)


## Returns the effective gallery path. An empty override resolves through the OS.
func get_gallery_directory() -> String:
	var configured := gallery_directory.strip_edges()
	if not configured.is_empty():
		return configured.simplify_path()
	if _gallery_fallback_in_use:
		return "user://screenshots"
	var documents := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents.is_empty():
		return "user://screenshots"
	var project_name := str(ProjectSettings.get_setting("application/config/name", "Godot Game")).strip_edges().validate_filename()
	project_name = project_name.trim_suffix(".").strip_edges()
	if project_name.is_empty() or project_name == "." or project_name == "..":
		project_name = "Godot Game"
	return documents.path_join(project_name).path_join("screenshots").simplify_path()


func list_photos(limit := 0) -> Array[Dictionary]:
	var photos: Array[Dictionary] = []
	var effective_directory := get_gallery_directory()
	var directory := DirAccess.open(effective_directory)
	if not directory:
		return photos
	var files: Array = Array(directory.get_files())
	files.sort()
	files.reverse()
	for file_name in files:
		if not str(file_name).to_lower().ends_with(".png"):
			continue
		var path := effective_directory.path_join(str(file_name))
		var metadata_path := path.get_basename() + ".json"
		var metadata := _read_json_dictionary(metadata_path)
		photos.append({"path": path, "metadata": metadata})
		if limit > 0 and photos.size() >= limit:
			break
	return photos


func get_state() -> Dictionary:
	var state := _settings.duplicate(true)
	state["active"] = _session_state != SessionState.INACTIVE
	state["exiting"] = _session_state == SessionState.EXITING
	state["ui_interactive"] = _ui_interactive
	state["capture_in_progress"] = _capture_in_progress
	state["collision_enabled"] = collision_enabled
	state["collision_armed"] = _collision_armed
	state["collision_started_overlapping"] = _collision_started_overlapping
	state["boundary"] = _boundary_description
	state["screen_filter_choice_available"] = allow_player_screen_filter_toggle and not _screen_filter_records.is_empty()
	state["screen_filter_count"] = _screen_filter_records.size()
	state["presets"] = list_presets()
	return state


func _setup_settings(source_camera: Camera3D) -> void:
	var rotation := source_camera.global_basis.get_euler()
	_target_pitch = rotation.x
	_target_yaw = rotation.y
	_target_roll = rotation.z
	_settings = {
		"fov": clampf(source_camera.fov, minimum_fov, maximum_fov),
		"focus_distance": 10.0,
		"aperture": 16.0,
		"dof_enabled": false,
		"exposure": 0.0,
		"roll": rad_to_deg(rotation.z),
		"filter": 0,
		"filter_strength": 0.0,
		"vignette": 0.0,
		"saturation": 1.0,
		"contrast": 1.0,
		"temperature": 0.0,
		"screen_filters_enabled": include_screen_filters,
	}
	_initial_settings = _settings.duplicate(true)
	_original_attributes = source_camera.attributes.duplicate(true) if source_camera.attributes else null
	_base_exposure_multiplier = source_camera.attributes.exposure_multiplier if source_camera.attributes else 1.0


func _collect_screen_filters() -> void:
	_screen_filter_records.clear()
	for path in screen_filter_paths:
		var node := get_node_or_null(path)
		if not node:
			push_warning("Lente: screen filter path '%s' could not be resolved." % path)
			continue
		if not node is ColorRect:
			push_warning("Lente: screen filter path '%s' does not point to a ColorRect." % path)
			continue
		var rect := node as ColorRect
		_screen_filter_records.append({
			"node": weakref(rect),
			"visible": rect.visible,
			"visible_in_tree": rect.is_visible_in_tree(),
		})
	_apply_screen_filter_visibility()


func _apply_screen_filter_visibility() -> void:
	var enabled := bool(_settings.get("screen_filters_enabled", include_screen_filters))
	for record in _screen_filter_records:
		var reference: WeakRef = record.get("node")
		var rect := reference.get_ref() as ColorRect if reference else null
		if is_instance_valid(rect):
			rect.visible = bool(record.get("visible", false)) and enabled


func _restore_screen_filters() -> void:
	for record in _screen_filter_records:
		var reference: WeakRef = record.get("node")
		var rect := reference.get_ref() as ColorRect if reference else null
		if is_instance_valid(rect):
			rect.visible = bool(record.get("visible", false))
	_screen_filter_records.clear()


func _add_screen_filters_to_capture(viewport: SubViewport) -> void:
	if not bool(_settings.get("screen_filters_enabled", include_screen_filters)):
		return
	for record in _screen_filter_records:
		if not bool(record.get("visible_in_tree", false)):
			continue
		var reference: WeakRef = record.get("node")
		var source := reference.get_ref() as ColorRect if reference else null
		if not is_instance_valid(source):
			continue
		var filter_copy := ColorRect.new()
		filter_copy.name = "LenteGameScreenFilter"
		filter_copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		filter_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filter_copy.color = source.color
		filter_copy.modulate = source.modulate
		filter_copy.self_modulate = source.self_modulate
		filter_copy.material = source.material
		filter_copy.texture_filter = source.texture_filter
		filter_copy.texture_repeat = source.texture_repeat
		viewport.add_child(filter_copy)


func _setup_rig(source_camera: Camera3D) -> void:
	_rig = CharacterBody3D.new()
	_rig.name = "LenteRuntimeRig"
	_rig.top_level = true
	_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	_rig.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_rig.collision_layer = 0
	_rig.collision_mask = 0
	_rig.safe_margin = collision_safe_margin
	_rig.max_slides = collision_max_slides
	add_child(_rig)
	_rig.global_transform = source_camera.global_transform
	_collision_node = CollisionShape3D.new()
	_collision_node.name = "CameraCollision"
	_collision_sphere = SphereShape3D.new()
	_collision_sphere.radius = collision_radius
	_collision_node.shape = _collision_sphere
	_collision_node.disabled = not collision_enabled
	_rig.add_child(_collision_node)
	_camera = Camera3D.new()
	_camera.name = "LenteCamera"
	_copy_camera_properties(source_camera, _camera)
	_rig.add_child(_camera)
	_camera.transform = Transform3D.IDENTITY
	_collision_started_overlapping = collision_enabled and _collision_overlaps_world()
	_collision_armed = collision_enabled and not _collision_started_overlapping
	_rig.collision_mask = collision_mask if _collision_armed else 0


func _copy_camera_properties(source: Camera3D, target: Camera3D) -> void:
	target.projection = source.projection
	target.fov = source.fov
	target.size = source.size
	target.near = source.near
	target.far = source.far
	target.keep_aspect = source.keep_aspect
	target.cull_mask = source.cull_mask
	target.h_offset = source.h_offset
	target.v_offset = source.v_offset
	target.frustum_offset = source.frustum_offset
	target.environment = source.environment
	target.compositor = source.compositor
	target.attributes = source.attributes.duplicate(true) if source.attributes else null


func _collect_bounds() -> void:
	_bounds.clear()
	_collect_bounds_recursive(self)
	_use_fallback_boundary = _bounds.is_empty()
	_boundary_description = "Entry bubble"
	if not _use_fallback_boundary:
		var starts_inside := false
		for bound in _bounds:
			if bound.get_margin(_fallback_center) >= 0.0:
				starts_inside = true
				break
		if starts_inside:
			_boundary_description = "%d authored volume%s" % [_bounds.size(), "" if _bounds.size() == 1 else "s"]
		else:
			_use_fallback_boundary = true
			_boundary_description = "Entry bubble (authored bounds missed entry)"
			push_warning("Lente: the active camera was outside every authored bound. Using the fallback entry bubble for this session.")


func _collect_bounds_recursive(parent: Node) -> void:
	for child in parent.get_children():
		if child is BoundVolume:
			_bounds.append(child)
		_collect_bounds_recursive(child)


func _setup_post_process() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.name = "LentePostProcess"
	_post_layer.layer = 90
	_post_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_post_layer)
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_material = _make_post_material()
	grade.material = _post_material
	_post_layer.add_child(grade)


func _setup_interface() -> void:
	var scene := ui_scene if ui_scene else DefaultUI
	_ui_root = scene.instantiate()
	_ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	if _ui_root is CanvasLayer:
		add_child(_ui_root)
	else:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "LenteInterface"
		_ui_layer.layer = 100
		_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_ui_layer)
		_ui_layer.add_child(_ui_root)
	if _ui_root.has_signal("command_requested"):
		_ui_root.connect("command_requested", _on_ui_command)
	if _ui_root.has_method("bind_lente"):
		_ui_root.call("bind_lente", self)
	else:
		push_warning("Lente custom UI has no bind_lente(controller) method; state signals remain available.")


func _setup_shutter_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "LenteShutter"
	_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.12
	_audio_player.stream = generator
	add_child(_audio_player)


func _apply_keep_alive_groups() -> void:
	_keep_alive_records.clear()
	for group_name in continue_processing_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node == self or is_ancestor_of(node):
				continue
			_keep_alive_records.append({"node": weakref(node), "process_mode": node.process_mode})
			node.process_mode = Node.PROCESS_MODE_ALWAYS


func _restore_keep_alive_groups() -> void:
	for record in _keep_alive_records:
		var node: Node = record.node.get_ref()
		if is_instance_valid(node):
			node.process_mode = int(record.process_mode)
	_keep_alive_records.clear()


func _update_rotation(delta: float) -> void:
	if not _ui_interactive:
		var look := Input.get_vector(&"lente_look_left", &"lente_look_right", &"lente_look_up", &"lente_look_down") if _has_actions([&"lente_look_left", &"lente_look_right", &"lente_look_up", &"lente_look_down"]) else Vector2.ZERO
		_target_yaw -= deg_to_rad(look.x * gamepad_look_speed * delta)
		_target_pitch -= deg_to_rad(look.y * gamepad_look_speed * delta)
		_target_pitch = clampf(_target_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		var roll_input := _action_strength(&"lente_roll_right") - _action_strength(&"lente_roll_left")
		if not is_zero_approx(roll_input):
			_target_roll = clampf(_target_roll + deg_to_rad(roll_input * roll_speed * delta), deg_to_rad(-45.0), deg_to_rad(45.0))
			_settings.roll = rad_to_deg(_target_roll)
	var desired_basis := Basis.from_euler(Vector3(_target_pitch, _target_yaw, _target_roll))
	var current_rotation := _rig.global_basis.get_rotation_quaternion()
	var desired_rotation := desired_basis.get_rotation_quaternion()
	var weight := 1.0 - exp(-rotation_smoothing * delta)
	var transform := _rig.global_transform
	transform.basis = Basis(current_rotation.slerp(desired_rotation, weight))
	_rig.global_transform = transform


func _update_movement(delta: float) -> void:
	_refresh_collision_arming()
	var direction := Vector3.ZERO
	if not _ui_interactive and _has_actions([&"lente_move_left", &"lente_move_right", &"lente_move_forward", &"lente_move_back"]):
		var planar := Input.get_vector(&"lente_move_left", &"lente_move_right", &"lente_move_forward", &"lente_move_back")
		var basis := _camera.global_basis
		direction = basis.x * planar.x + (-basis.z) * -planar.y
		direction += Vector3.UP * (_action_strength(&"lente_move_up") - _action_strength(&"lente_move_down"))
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
	var speed := movement_speed
	if _action_strength(&"lente_boost") > 0.2:
		speed *= boost_multiplier
	if _action_strength(&"lente_slow") > 0.2:
		speed *= slow_multiplier
	var desired_velocity := direction * speed
	var rate := acceleration if not direction.is_zero_approx() else deceleration
	_rig.velocity = _rig.velocity.move_toward(desired_velocity, rate * delta)
	_soften_boundary_velocity()
	_rig.move_and_slide()
	_clamp_to_boundary()


func _refresh_collision_arming() -> void:
	if not _rig:
		return
	if not collision_enabled:
		_collision_armed = false
		_rig.collision_mask = 0
		return
	if _collision_armed:
		_rig.collision_mask = collision_mask
		return
	# Gameplay cameras commonly begin inside their player's capsule. Lente
	# leaves collision disarmed until the camera clears that initial overlap,
	# avoiding a depenetration shove on the first photo-mode frame.
	if not _collision_overlaps_world():
		_collision_armed = true
		_rig.collision_mask = collision_mask


func _collision_overlaps_world() -> bool:
	if not _rig or not _collision_sphere or collision_mask == 0:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_sphere
	query.transform = Transform3D(Basis.IDENTITY, _rig.global_position)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_rig.get_rid()]
	return not _rig.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _soften_boundary_velocity() -> void:
	if soft_boundary_distance <= 0.0 or _rig.velocity.is_zero_approx():
		return
	var position := _rig.global_position
	var margin := _boundary_margin(position)
	if margin >= soft_boundary_distance:
		return
	var epsilon := maxf(0.03, collision_radius * 0.35)
	var gradient := Vector3(
		_boundary_margin(position + Vector3.RIGHT * epsilon) - _boundary_margin(position - Vector3.RIGHT * epsilon),
		_boundary_margin(position + Vector3.UP * epsilon) - _boundary_margin(position - Vector3.UP * epsilon),
		_boundary_margin(position + Vector3.BACK * epsilon) - _boundary_margin(position - Vector3.BACK * epsilon)
	)
	if gradient.is_zero_approx():
		return
	gradient = gradient.normalized()
	var outward_speed := -_rig.velocity.dot(gradient)
	if outward_speed <= 0.0:
		return
	var soft_factor := smoothstep(0.0, soft_boundary_distance, maxf(margin, 0.0))
	_rig.velocity += gradient * outward_speed * (1.0 - soft_factor)


func _clamp_to_boundary() -> void:
	if _boundary_margin(_rig.global_position) >= 0.0:
		return
	var outside_position := _rig.global_position
	var closest := _closest_allowed_point(outside_position)
	var outward := outside_position - closest
	_rig.global_position = closest
	if not outward.is_zero_approx():
		outward = outward.normalized()
		var outward_speed := _rig.velocity.dot(outward)
		if outward_speed > 0.0:
			_rig.velocity -= outward * outward_speed


func _boundary_margin(world_position: Vector3) -> float:
	if _use_fallback_boundary:
		return fallback_radius - world_position.distance_to(_fallback_center)
	var best := -INF
	for bound in _bounds:
		if is_instance_valid(bound):
			best = maxf(best, bound.get_margin(world_position))
	return best


func _closest_allowed_point(world_position: Vector3) -> Vector3:
	if _use_fallback_boundary:
		var offset := world_position - _fallback_center
		if offset.length_squared() <= fallback_radius * fallback_radius:
			return world_position
		return _fallback_center + offset.normalized() * fallback_radius
	var closest := world_position
	var best_distance := INF
	for bound in _bounds:
		if not is_instance_valid(bound):
			continue
		if bound.get_margin(world_position) >= 0.0:
			return world_position
		var candidate: Vector3 = bound.get_closest_point(world_position)
		var distance := candidate.distance_squared_to(world_position)
		if distance < best_distance:
			best_distance = distance
			closest = candidate
	return closest


func _apply_all_settings() -> void:
	if _camera:
		_ensure_practical_attributes()
		_camera.fov = float(_settings.fov)
	_target_roll = deg_to_rad(float(_settings.roll))
	_apply_exposure()
	_apply_depth_of_field()
	_apply_post_process()
	_apply_screen_filter_visibility()


func _ensure_practical_attributes() -> CameraAttributesPractical:
	if not _camera:
		return null
	if _camera.attributes is CameraAttributesPractical:
		return _camera.attributes
	var attributes := CameraAttributesPractical.new()
	attributes.exposure_multiplier = _base_exposure_multiplier
	_camera.attributes = attributes
	return attributes


func _apply_exposure() -> void:
	var attributes := _ensure_practical_attributes()
	if attributes:
		attributes.exposure_multiplier = _base_exposure_multiplier * pow(2.0, float(_settings.exposure))


func _apply_depth_of_field() -> void:
	var attributes := _ensure_practical_attributes()
	if not attributes:
		return
	var enabled := bool(_settings.dof_enabled)
	attributes.dof_blur_far_enabled = enabled
	attributes.dof_blur_near_enabled = enabled
	if not enabled:
		return
	var aperture_t := inverse_lerp(1.4, 16.0, float(_settings.aperture))
	var distance := float(_settings.focus_distance)
	var half_depth := maxf(0.12, distance * lerpf(0.025, 0.32, aperture_t))
	attributes.dof_blur_near_distance = maxf(0.05, distance - half_depth)
	attributes.dof_blur_near_transition = maxf(0.08, half_depth)
	attributes.dof_blur_far_distance = distance + half_depth
	attributes.dof_blur_far_transition = maxf(0.16, half_depth * 1.8)
	attributes.dof_blur_amount = lerpf(0.36, 0.025, aperture_t)


func _make_post_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PostShader
	for parameter in [&"filter", &"filter_strength", &"vignette", &"saturation", &"contrast", &"temperature"]:
		var uniform_name: StringName = &"filter_mode" if parameter == &"filter" else parameter
		material.set_shader_parameter(uniform_name, _settings.get(parameter, 0.0))
	return material


func _apply_post_process() -> void:
	if not _post_material:
		return
	_post_material.set_shader_parameter(&"filter_mode", int(_settings.filter))
	_post_material.set_shader_parameter(&"filter_strength", float(_settings.filter_strength))
	_post_material.set_shader_parameter(&"vignette", float(_settings.vignette))
	_post_material.set_shader_parameter(&"saturation", float(_settings.saturation))
	_post_material.set_shader_parameter(&"contrast", float(_settings.contrast))
	_post_material.set_shader_parameter(&"temperature", float(_settings.temperature))


func _play_shutter_sound() -> void:
	if not _audio_player:
		return
	_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	var frames := playback.get_frames_available()
	for index in frames:
		var time := float(index) / 44100.0
		var click_envelope := exp(-time * 74.0)
		var body_envelope := exp(-time * 31.0)
		var noise := randf_range(-1.0, 1.0) * click_envelope
		var body := sin(TAU * (84.0 + time * 180.0) * time) * body_envelope
		var sample := clampf(noise * 0.38 + body * 0.18, -0.8, 0.8)
		playback.push_frame(Vector2(sample, sample))


func _make_capture_name() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "Lente_%04d%02d%02d_%02d%02d%02d_%03d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		Time.get_ticks_msec() % 1000,
	]


func _make_capture_metadata(path: String, output_size: Vector2i) -> Dictionary:
	var rotation := _camera.global_basis.get_euler()
	return {
		"format_version": 1,
		"plugin": "Lente 0.9999",
		"engine": Engine.get_version_info().get("string", "Godot 4.x"),
		"project": ProjectSettings.get_setting("application/config/name", "Untitled"),
		"captured_at": Time.get_datetime_string_from_system(true),
		"path": path,
		"resolution": [output_size.x, output_size.y],
		"camera": {
			"position": [_camera.global_position.x, _camera.global_position.y, _camera.global_position.z],
			"rotation_degrees": [rad_to_deg(rotation.x), rad_to_deg(rotation.y), rad_to_deg(rotation.z)],
			"near": _camera.near,
			"far": _camera.far,
			"cull_mask": _camera.cull_mask,
		},
		"settings": _settings_snapshot(),
		"boundary": _boundary_description,
	}


func _settings_snapshot() -> Dictionary:
	return _settings.duplicate(true)


func _normalize_settings() -> void:
	_settings.fov = clampf(float(_settings.fov), minimum_fov, maximum_fov)
	_settings.focus_distance = clampf(float(_settings.focus_distance), 0.05, maximum_focus_distance)
	_settings.aperture = clampf(float(_settings.aperture), 1.4, 16.0)
	_settings.dof_enabled = bool(_settings.dof_enabled)
	_settings.exposure = clampf(float(_settings.exposure), -4.0, 4.0)
	_settings.roll = clampf(float(_settings.roll), -45.0, 45.0)
	_settings.filter = clampi(int(_settings.filter), 0, FILTER_NAMES.size() - 1)
	_settings.filter_strength = clampf(float(_settings.filter_strength), 0.0, 1.0)
	_settings.vignette = clampf(float(_settings.vignette), 0.0, 1.0)
	_settings.saturation = clampf(float(_settings.saturation), 0.0, 2.0)
	_settings.contrast = clampf(float(_settings.contrast), 0.5, 1.5)
	_settings.temperature = clampf(float(_settings.temperature), -1.0, 1.0)
	_settings.screen_filters_enabled = bool(_settings.get("screen_filters_enabled", include_screen_filters))


func _on_ui_command(command: StringName, payload: Variant = null) -> void:
	match command:
		&"set_parameter":
			if payload is Dictionary and payload.has("name"):
				set_parameter(StringName(payload.name), payload.get("value"))
		&"capture":
			capture_photo()
		&"focus":
			focus_at_screen_position(payload if payload is Vector2 else get_viewport().get_mouse_position())
		&"exit":
			exit_photo_mode()
		&"reset":
			reset_parameters()
		&"apply_filter_preset":
			apply_filter_preset(int(payload))
		&"set_ui_interactive":
			set_ui_interactive(bool(payload))
		&"save_preset":
			save_preset(str(payload))
		&"load_preset":
			load_preset(str(payload))
		&"delete_preset":
			delete_preset(str(payload))


func _on_source_camera_exiting() -> void:
	_source_camera_ref = null
	if _session_state != SessionState.INACTIVE:
		push_warning("Lente: the gameplay camera left the tree during a session; restoring without a return camera.")
		exit_photo_mode(true)


func _teardown_session(emit_exit_signal: bool) -> void:
	if _session_state == SessionState.INACTIVE:
		return
	var source := _get_source_camera()
	if source and source.tree_exiting.is_connected(_on_source_camera_exiting):
		source.tree_exiting.disconnect(_on_source_camera_exiting)
	if source and source.is_inside_tree():
		source.make_current()
	elif _camera and _camera.is_inside_tree():
		_camera.clear_current(true)
	_restore_keep_alive_groups()
	_restore_screen_filters()
	if is_inside_tree():
		get_tree().paused = _was_tree_paused
	Input.mouse_mode = _previous_mouse_mode
	if _previous_focus_ref:
		var focus_owner: Control = _previous_focus_ref.get_ref()
		if is_instance_valid(focus_owner) and focus_owner.is_inside_tree():
			focus_owner.call_deferred("grab_focus")
	_previous_focus_ref = null
	if _ui_root and _ui_root.has_signal("command_requested") and _ui_root.is_connected("command_requested", _on_ui_command):
		_ui_root.disconnect("command_requested", _on_ui_command)
	if _ui_layer:
		_ui_layer.queue_free()
	elif _ui_root:
		_ui_root.queue_free()
	if _post_layer:
		_post_layer.queue_free()
	if _rig:
		_rig.queue_free()
	if _audio_player:
		_audio_player.stop()
		_audio_player.stream = null
		_audio_player.queue_free()
	_ui_layer = null
	_ui_root = null
	_post_layer = null
	_post_material = null
	_rig = null
	_camera = null
	_audio_player = null
	_collision_node = null
	_collision_sphere = null
	_collision_armed = false
	_collision_started_overlapping = false
	_source_camera_ref = null
	_bounds.clear()
	_capture_in_progress = false
	_pending_exit = false
	_session_state = SessionState.INACTIVE
	if _active_controller and _active_controller.get_ref() == self:
		_active_controller = null
	if emit_exit_signal:
		exited.emit()


func _get_source_camera() -> Camera3D:
	if not _source_camera_ref:
		return null
	var source := _source_camera_ref.get_ref()
	return source as Camera3D if is_instance_valid(source) else null


func _emit_state() -> void:
	state_changed.emit(get_state())


func _request_message(message: String) -> void:
	message_requested.emit(message)
	if not _ui_root:
		push_warning("Lente: " + message)


func _event_action_pressed(event: InputEvent, action: StringName) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and event.is_action_pressed(action)


func _action_strength(action: StringName) -> float:
	return Input.get_action_strength(action) if InputMap.has_action(action) else 0.0


func _has_actions(actions: Array[StringName]) -> bool:
	for action in actions:
		if not InputMap.has_action(action):
			return false
	return true


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed := JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t", false))
	return true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if minimum_fov >= maximum_fov:
		warnings.append("Minimum FOV must be lower than maximum FOV.")
	if collision_radius >= fallback_radius:
		warnings.append("Collision radius should be smaller than the fallback boundary radius.")
	if soft_boundary_distance > fallback_radius:
		warnings.append("Soft boundary distance is larger than the fallback radius; movement will feel unusually heavy.")
	if capture_scale * 1920.0 > maximum_capture_dimension:
		warnings.append("Maximum capture dimension may cap the requested capture scale on common displays.")
	if allow_player_screen_filter_toggle and screen_filter_paths.is_empty():
		warnings.append("Player screen-filter choice is enabled, but no ColorRect paths are assigned.")
	return warnings
