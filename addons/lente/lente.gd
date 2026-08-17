@tool
extends EditorPlugin

const PhotoMode := preload("res://addons/lente/runtime/lente_photo_mode.gd")
const LenteInputDefaults := preload("res://addons/lente/runtime/lente_input.gd")
const BoundsGizmo := preload("res://addons/lente/editor/lente_bounds_gizmo.gd")
const LenteInspector := preload("res://addons/lente/editor/lente_inspector.gd")

var _gizmo_plugin: EditorNode3DGizmoPlugin
var _inspector_plugin: EditorInspectorPlugin
var _toolbar_button: Button


func _enter_tree() -> void:
	_gizmo_plugin = BoundsGizmo.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)
	_inspector_plugin = LenteInspector.new(self)
	add_inspector_plugin(_inspector_plugin)
	_toolbar_button = Button.new()
	_toolbar_button.flat = true
	_toolbar_button.text = "Lente"
	_toolbar_button.tooltip_text = "Add a ready-to-use Lente Photo Mode to the edited 3D scene"
	_toolbar_button.icon = get_editor_interface().get_editor_theme().get_icon("Camera3D", "EditorIcons")
	_toolbar_button.pressed.connect(_add_photo_mode)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar_button)
	_ensure_default_input_actions()


func _exit_tree() -> void:
	if _toolbar_button:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _gizmo_plugin:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)
		_gizmo_plugin = null


func _add_photo_mode() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if not scene_root:
		return
	var parent: Node = scene_root
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() == 1 and selection[0] is Node3D:
		parent = selection[0]
	var photo_mode: Node = PhotoMode.new()
	photo_mode.name = "LentePhotoMode"
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add Lente Photo Mode")
	undo_redo.add_do_method(parent, "add_child", photo_mode, true)
	undo_redo.add_do_method(photo_mode, "set_owner", scene_root)
	undo_redo.add_do_reference(photo_mode)
	undo_redo.add_undo_method(parent, "remove_child", photo_mode)
	undo_redo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(photo_mode)


func _ensure_default_input_actions() -> void:
	LenteInputDefaults.ensure_defaults(true)
