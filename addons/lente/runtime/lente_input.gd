class_name LenteInput
extends RefCounted

## Installs non-conflicting defaults. Existing project actions are never overwritten.


static func ensure_defaults(persist_to_project := false) -> void:
	_ensure_action(&"lente_toggle", [_key(KEY_P), _joy_button(JOY_BUTTON_START)], persist_to_project)
	_ensure_action(&"lente_exit", [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_B)], persist_to_project)
	_ensure_action(&"lente_move_forward", [_key(KEY_W), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)], persist_to_project)
	_ensure_action(&"lente_move_back", [_key(KEY_S), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)], persist_to_project)
	_ensure_action(&"lente_move_left", [_key(KEY_A), _joy_axis(JOY_AXIS_LEFT_X, -1.0)], persist_to_project)
	_ensure_action(&"lente_move_right", [_key(KEY_D), _joy_axis(JOY_AXIS_LEFT_X, 1.0)], persist_to_project)
	_ensure_action(&"lente_move_up", [_key(KEY_E), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], persist_to_project)
	_ensure_action(&"lente_move_down", [_key(KEY_Q), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], persist_to_project)
	_ensure_action(&"lente_look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)], persist_to_project)
	_ensure_action(&"lente_look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)], persist_to_project)
	_ensure_action(&"lente_look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)], persist_to_project)
	_ensure_action(&"lente_look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)], persist_to_project)
	_ensure_action(&"lente_boost", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_SHOULDER)], persist_to_project)
	_ensure_action(&"lente_slow", [_key(KEY_CTRL), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)], persist_to_project)
	_ensure_action(&"lente_capture", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)], persist_to_project)
	_ensure_action(&"lente_focus", [_mouse_button(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_RIGHT_STICK)], persist_to_project)
	_ensure_action(&"lente_roll_left", [_key(KEY_Z), _joy_button(JOY_BUTTON_DPAD_LEFT)], persist_to_project)
	_ensure_action(&"lente_roll_right", [_key(KEY_X), _joy_button(JOY_BUTTON_DPAD_RIGHT)], persist_to_project)
	_ensure_action(&"lente_ui", [_key(KEY_TAB), _joy_button(JOY_BUTTON_Y)], persist_to_project)
	_ensure_action(&"lente_gallery", [_key(KEY_G), _joy_button(JOY_BUTTON_X)], persist_to_project)
	_ensure_action(&"lente_reset", [_key(KEY_R), _joy_button(JOY_BUTTON_DPAD_DOWN)], persist_to_project)
	_ensure_action(&"lente_zoom_in", [_mouse_button(MOUSE_BUTTON_WHEEL_UP), _joy_button(JOY_BUTTON_DPAD_UP)], persist_to_project)
	_ensure_action(&"lente_zoom_out", [_mouse_button(MOUSE_BUTTON_WHEEL_DOWN)], persist_to_project)
	if persist_to_project:
		ProjectSettings.save()


static func _ensure_action(action: StringName, events: Array, persist: bool) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
		for event in events:
			InputMap.action_add_event(action, event)
	if persist and not ProjectSettings.has_setting("input/" + String(action)):
		ProjectSettings.set_setting("input/" + String(action), {"deadzone": 0.18, "events": events})


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _mouse_button(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event


static func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
