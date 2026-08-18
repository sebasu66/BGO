class_name BgoCameraFilterController
extends Node

const FILTER_ALPHA := 0.10
const REFRESH_SECONDS := 0.35

var _root: Node
var _ui: CanvasLayer
var _button: Button
var _popup: PopupPanel
var _owner_box: VBoxContainer
var _type_box: VBoxContainer
var _owner_enabled: Dictionary = {}
var _type_enabled: Dictionary = {}
var _elapsed := 0.0


func _ready() -> void:
	_root = get_parent()
	_ui = _root.get_node_or_null("UI") as CanvasLayer
	if _ui == null:
		return
	_build_ui()
	call_deferred("_refresh_filters")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	_refresh_filters()


func _build_ui() -> void:
	_button = Button.new()
	_button.text = "FILTER"
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = -118.0
	_button.offset_top = 18.0
	_button.offset_right = -18.0
	_button.offset_bottom = 58.0
	_button.pressed.connect(_toggle_popup)
	_ui.add_child(_button)

	_popup = PopupPanel.new()
	_popup.size = Vector2i(330, 420)
	_ui.add_child(_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_popup.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "CAMERA FILTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root_box.add_child(title)

	var explanation := Label.new()
	explanation.text = "Unchecked layers stay visible at 10% opacity and cannot be selected."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(explanation)

	var owner_title := Label.new()
	owner_title.text = "BY OWNER"
	owner_title.add_theme_font_size_override("font_size", 15)
	root_box.add_child(owner_title)
	_owner_box = VBoxContainer.new()
	root_box.add_child(_owner_box)

	var separator := HSeparator.new()
	root_box.add_child(separator)

	var type_title := Label.new()
	type_title.text = "BY TYPE"
	type_title.add_theme_font_size_override("font_size", 15)
	root_box.add_child(type_title)
	_type_box = VBoxContainer.new()
	root_box.add_child(_type_box)

	var all_button := Button.new()
	all_button.text = "SHOW ALL"
	all_button.pressed.connect(_show_all)
	root_box.add_child(all_button)


func _toggle_popup() -> void:
	if _popup.visible:
		_popup.hide()
		return
	_refresh_filter_controls()
	var viewport_size := get_viewport().get_visible_rect().size
	var position := Vector2i(maxi(int(viewport_size.x) - 350, 10), 68)
	_popup.position = position
	_popup.popup()


func _refresh_filters() -> void:
	if _root == null:
		return
	var pieces_variant: Variant = _root.get("pieces")
	if not pieces_variant is Dictionary:
		return
	var pieces: Dictionary = pieces_variant
	var owners: Dictionary = {}
	var types: Dictionary = {}
	for value in pieces.values():
		var piece := value as Node3D
		if piece == null:
			continue
		var owner_id := str(piece.get_meta("owner_id", ""))
		var type_id := _piece_type(piece)
		owners[owner_id] = true
		types[type_id] = true
		if not _owner_enabled.has(owner_id):
			_owner_enabled[owner_id] = true
		if not _type_enabled.has(type_id):
			_type_enabled[type_id] = true
		var enabled := (
			bool(_owner_enabled.get(owner_id, true)) and bool(_type_enabled.get(type_id, true))
		)
		_apply_piece_filter(piece, enabled)
	if _popup != null and _popup.visible:
		_refresh_filter_controls()


func _piece_type(piece: Node3D) -> String:
	var component_id := str(piece.get_meta("component_id", ""))
	if component_id.is_empty():
		return "piece"
	var kind := BgoComponentRegistry.get_kind(component_id)
	return kind if not kind.is_empty() else component_id


func _apply_piece_filter(piece: Node3D, enabled: bool) -> void:
	piece.set_meta("bgo_filtered_out", not enabled)
	if piece is CollisionObject3D:
		var body := piece as CollisionObject3D
		if not body.has_meta("bgo_filter_original_collision_layer"):
			body.set_meta("bgo_filter_original_collision_layer", body.collision_layer)
		body.collision_layer = (
			int(body.get_meta("bgo_filter_original_collision_layer", 1)) if enabled else 0
		)
	_apply_visual_alpha(piece, 1.0 if enabled else FILTER_ALPHA)


func _apply_visual_alpha(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.has_meta("bgo_filter_original_material"):
			mesh_instance.set_meta("bgo_filter_original_material", mesh_instance.material_override)
		var original: Material = (
			mesh_instance.get_meta("bgo_filter_original_material", null) as Material
		)
		if alpha >= 0.999:
			mesh_instance.material_override = original
		elif original is StandardMaterial3D:
			var faded := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var color := faded.albedo_color
			color.a = alpha
			faded.albedo_color = color
			mesh_instance.material_override = faded
	if node is Label3D:
		var label := node as Label3D
		var modulation := label.modulate
		modulation.a = alpha
		label.modulate = modulation
	for child in node.get_children():
		_apply_visual_alpha(child, alpha)


func _refresh_filter_controls() -> void:
	if _owner_box == null or _type_box == null:
		return
	_rebuild_checkboxes(_owner_box, _owner_enabled, true)
	_rebuild_checkboxes(_type_box, _type_enabled, false)


func _rebuild_checkboxes(container: VBoxContainer, values: Dictionary, owner_group: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(str(key))
	keys.sort()
	for key in keys:
		var checkbox := CheckBox.new()
		checkbox.text = _owner_label(key) if owner_group else key.replace("_", " ").capitalize()
		checkbox.button_pressed = bool(values[key])
		checkbox.toggled.connect(_on_filter_toggled.bind(key, owner_group))
		container.add_child(checkbox)


func _owner_label(owner_id: String) -> String:
	if owner_id.is_empty():
		return "Neutral / no owner"
	return owner_id.replace("_", " ").capitalize()


func _on_filter_toggled(enabled: bool, key: String, owner_group: bool) -> void:
	if owner_group:
		_owner_enabled[key] = enabled
	else:
		_type_enabled[key] = enabled
	_refresh_filters()


func _show_all() -> void:
	for key in _owner_enabled.keys():
		_owner_enabled[key] = true
	for key in _type_enabled.keys():
		_type_enabled[key] = true
	_refresh_filters()
