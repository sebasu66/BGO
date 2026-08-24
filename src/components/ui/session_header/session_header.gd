class_name BgoSessionHeader
extends PanelContainer

signal profile_pressed
signal action_requested(action_id: String)

# Compact shared-game header styling.
const SURFACE_COLOR := Color(0.035, 0.042, 0.05, 0.92)
const TEXT_COLOR := Color(0.96, 0.95, 0.91, 1.0)
const MUTED_COLOR := Color(0.64, 0.67, 0.69, 1.0)
const SCENE_TEXT_COLOR := Color(0.09, 0.11, 0.13, 0.94)
const SCENE_MUTED_COLOR := Color(0.20, 0.24, 0.27, 0.76)
const CHIP_COLOR := Color(0.11, 0.125, 0.14, 0.98)
const HEADER_HEIGHT := 58.0

var _game_name: Label
var _game_context: Label
var _turn: Label
var _profile: Button
var _pending_state: Dictionary = {}
var _actions: Array[Dictionary] = []
var _actions_row: HBoxContainer


func _ready() -> void:
	custom_minimum_size.y = HEADER_HEIGHT
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_build()
	_apply_state(_pending_state)


## Updates visible session metadata without coupling the header to domain nodes.
func set_state(state: Dictionary) -> void:
	_pending_state = state.duplicate(true)
	if not is_node_ready():
		return
	_apply_state(_pending_state)


## Defines compact header actions without coupling the header to scene methods.
func configure_actions(actions: Array) -> void:
	_actions.clear()
	for value in actions:
		if value is Dictionary:
			_actions.append((value as Dictionary).duplicate(true))
	if is_node_ready():
		_rebuild_actions()


func _apply_state(state: Dictionary) -> void:
	_game_name.text = str(state.get("game_name", "BGO SESSION")).to_upper()
	var details: Array[String] = []
	var game_type := str(state.get("game_type", ""))
	var mode := str(state.get("mode", ""))
	if not game_type.is_empty():
		details.append(game_type.to_upper())
	if not mode.is_empty():
		details.append(mode.to_upper())
	_game_context.text = " · ".join(details)
	_game_context.visible = not details.is_empty()
	var turn_number := int(state.get("turn_number", 0))
	var active_label := str(state.get("active_player_label", ""))
	_turn.visible = turn_number > 0 or not active_label.is_empty()
	_turn.text = "TURN %d · %s" % [turn_number, active_label.to_upper()]
	var profile_label := str(state.get("profile_label", "SPECTATOR")).to_upper()
	var profile_color: Color = state.get("profile_color", MUTED_COLOR)
	_profile.text = "%s  ▾" % profile_label
	_profile.icon = LucideTexture.new(str(state.get("profile_icon", "eye")), 22.0, profile_color, 2.0)
	_profile.expand_icon = false
	_profile.add_theme_color_override("font_color", profile_color)
	_profile.add_theme_color_override("font_hover_color", profile_color.lightened(0.16))


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var identity := VBoxContainer.new()
	row.add_child(identity)
	_game_name = Label.new()
	_game_name.add_theme_font_size_override("font_size", 18)
	_game_name.add_theme_color_override("font_color", SCENE_TEXT_COLOR)
	identity.add_child(_game_name)
	_game_context = Label.new()
	_game_context.add_theme_font_size_override("font_size", 12)
	_game_context.add_theme_color_override("font_color", SCENE_MUTED_COLOR)
	identity.add_child(_game_context)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_turn = Label.new()
	_turn.add_theme_font_size_override("font_size", 14)
	_turn.add_theme_color_override("font_color", TEXT_COLOR)
	_turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_turn)
	_profile = Button.new()
	_profile.custom_minimum_size = Vector2(152, 44)
	_profile.tooltip_text = "Change local viewer profile or hot-seat"
	_profile.pressed.connect(func() -> void: profile_pressed.emit())
	_profile.theme_type_variation = "BgoEmphasisButton"
	row.add_child(_profile)
	_actions_row = HBoxContainer.new()
	_actions_row.add_theme_constant_override("separation", 6)
	row.add_child(_actions_row)
	_rebuild_actions()


func _rebuild_actions() -> void:
	if _actions_row == null:
		return
	for child in _actions_row.get_children():
		child.queue_free()
	for action in _actions:
		if not bool(action.get("visible", true)):
			continue
		var button := Button.new()
		var action_id := str(action.get("id", ""))
		button.icon = LucideTexture.new(str(action.get("icon", "info")), 22.0, TEXT_COLOR, 2.0)
		button.custom_minimum_size = Vector2(46, 44)
		button.tooltip_text = str(action.get("tooltip", action.get("label", action_id)))
		button.theme_type_variation = "BgoShellButton"
		button.pressed.connect(func() -> void: action_requested.emit(action_id))
		_actions_row.add_child(button)
