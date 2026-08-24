class_name BgoActionStrip
extends PanelContainer

signal action_requested(action_id: String)

# Shared shell styling. Visual tokens stay here so game skins can replace them later.
const SURFACE_COLOR := Color(0.045, 0.052, 0.06, 0.94)
const BUTTON_COLOR := Color(0.09, 0.105, 0.12, 0.96)
const HOVER_COLOR := Color(0.16, 0.18, 0.20, 1.0)
const TEXT_COLOR := Color(0.96, 0.95, 0.91, 1.0)
const MUTED_COLOR := Color(0.67, 0.69, 0.70, 1.0)
const TOUCH_SIZE := Vector2(52, 48)
const TRANSITION_DURATION := 0.18

var _title := "MENU"
var _edge := "left"
var _expanded := false
var _actions: Array[Dictionary] = []
var _active_actions: Dictionary = {}
var _content: VBoxContainer
var _toggle: Button


func _ready() -> void:
	theme_type_variation = "BgoShellPanel"
	_rebuild()


## Configures one reusable vertical strip from declarative action dictionaries.
## Each action accepts id, label, icon, tooltip, visible and enabled fields.
func configure(title: String, actions: Array, edge := "left", expanded := false) -> void:
	_title = title
	_edge = edge
	_expanded = expanded
	_actions.clear()
	for value in actions:
		if value is Dictionary:
			_actions.append((value as Dictionary).duplicate(true))
	if is_node_ready():
		_rebuild()


## Expands or collapses labels while preserving icon access.
func set_expanded(value: bool, animate := true) -> void:
	if _expanded == value:
		return
	_expanded = value
	_rebuild()
	if animate:
		modulate.a = 0.55
		create_tween().tween_property(self, "modulate:a", 1.0, TRANSITION_DURATION)


## Updates toggle state. When exclusive is true, peers in the same group are cleared.
func set_action_active(action_id: String, active: bool, exclusive := true) -> void:
	var target_group := ""
	for action in _actions:
		if str(action.get("id", "")) == action_id:
			target_group = str(action.get("group", ""))
			break
	if active and exclusive and not target_group.is_empty():
		for action in _actions:
			if str(action.get("group", "")) == target_group:
				_active_actions.erase(str(action.get("id", "")))
	if active:
		_active_actions[action_id] = true
	else:
		_active_actions.erase(action_id)
	if is_node_ready():
		_rebuild()


func is_action_active(action_id: String) -> bool:
	return bool(_active_actions.get(action_id, false))


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 7)
	add_child(_content)
	_add_toggle()
	for action in _actions:
		if bool(action.get("visible", true)):
			_add_action(action)


func _add_toggle() -> void:
	_toggle = Button.new()
	_toggle.text = _title if _expanded else ""
	_toggle.icon = _icon("x" if _expanded else "menu", TEXT_COLOR)
	_toggle.expand_icon = false
	_toggle.tooltip_text = "Collapse %s" % _title if _expanded else "Open %s" % _title
	_toggle.custom_minimum_size = TOUCH_SIZE
	_toggle.pressed.connect(func() -> void: set_expanded(not _expanded))
	_toggle.theme_type_variation = "BgoEmphasisButton"
	_content.add_child(_toggle)


func _add_action(action: Dictionary) -> void:
	var button := Button.new()
	var label := str(action.get("label", action.get("id", "ACTION")))
	button.text = label if _expanded else ""
	button.icon = _icon(str(action.get("icon", "info")), TEXT_COLOR)
	button.expand_icon = false
	button.tooltip_text = str(action.get("tooltip", label))
	button.disabled = not bool(action.get("enabled", true))
	button.toggle_mode = bool(action.get("toggle", false))
	button.button_pressed = is_action_active(str(action.get("id", "")))
	button.custom_minimum_size = Vector2(148, 48) if _expanded else TOUCH_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if _expanded else HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(_on_action_pressed.bind(action))
	button.theme_type_variation = "BgoShellButton"
	_content.add_child(button)


func _icon(icon_name: String, color: Color) -> Texture2D:
	var icon_path := "res://addons/lucide/icons/%s.svg" % icon_name
	if not FileAccess.file_exists(icon_path):
		icon_path = "res://addons/lucide/icons/info.svg"
	var texture := LucideTexture.new(icon_path.get_file().get_basename(), 24.0, color, 2.0)
	return texture


func _emit_action(action_id: String) -> void:
	if not action_id.is_empty():
		action_requested.emit(action_id)


func _on_action_pressed(action: Dictionary) -> void:
	var action_id := str(action.get("id", ""))
	if bool(action.get("toggle", false)):
		set_action_active(action_id, not is_action_active(action_id))
	_emit_action(action_id)
