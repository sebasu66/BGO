@tool
extends EditorInspectorPlugin

const PhotoMode := preload("res://addons/lente/runtime/lente_photo_mode.gd")
const BoxBound := preload("res://addons/lente/runtime/bounds/lente_box_bound.gd")
const SphereBound := preload("res://addons/lente/runtime/bounds/lente_sphere_bound.gd")
const PathBound := preload("res://addons/lente/runtime/bounds/lente_path_bound.gd")

var _plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _can_handle(object: Object) -> bool:
	return object is PhotoMode


func _parse_begin(object: Object) -> void:
	var panel := PanelContainer.new()
	panel.name = "LenteQuickSetup"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Author a movement boundary"
	title.add_theme_font_size_override("font_size", 13)
	content.add_child(title)
	var help := Label.new()
	help.text = "Volumes combine as a union. With none, Lente uses its entry bubble."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(1.0, 1.0, 1.0, 0.65)
	content.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	_add_bound_button(row, "Box", "BoxShape3D", object, BoxBound, "LenteBoxBound")
	_add_bound_button(row, "Sphere", "SphereShape3D", object, SphereBound, "LenteSphereBound")
	_add_bound_button(row, "Path", "Path3D", object, PathBound, "LentePathBound")
	add_custom_control(panel)


func _add_bound_button(parent: Control, label: String, icon_name: String, target: Object, script: Script, node_name: String) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = _plugin.get_editor_interface().get_editor_theme().get_icon(icon_name, "EditorIcons")
	button.pressed.connect(_add_bound.bind(target, script, node_name))
	parent.add_child(button)


func _add_bound(target: Object, script: Script, node_name: String) -> void:
	if not is_instance_valid(target) or not target is Node:
		return
	var child: Node = script.new()
	child.name = node_name
	if child is PathBound:
		var path_curve := Curve3D.new()
		path_curve.add_point(Vector3(-4.0, 0.0, 0.0))
		path_curve.add_point(Vector3(4.0, 0.0, 0.0))
		child.curve = path_curve
	var scene_root := _plugin.get_editor_interface().get_edited_scene_root()
	var undo_redo := _plugin.get_undo_redo()
	undo_redo.create_action("Add %s" % node_name)
	undo_redo.add_do_method(target, "add_child", child, true)
	undo_redo.add_do_method(child, "set_owner", scene_root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(target, "remove_child", child)
	undo_redo.commit_action()
	_plugin.get_editor_interface().get_selection().clear()
	_plugin.get_editor_interface().get_selection().add_node(child)
