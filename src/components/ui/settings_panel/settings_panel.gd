class_name BgoSettingsPanel
extends Control

signal setting_changed(key: String, value: Variant)
signal close_requested
signal reset_requested

# Visual tuning values kept together for fast iteration.
const PANEL_COLOR := Color(0.055, 0.065, 0.075, 0.97)  # Main overlay surface.
const SECTION_COLOR := Color(0.09, 0.105, 0.12, 1.0)  # Tab content surface.
const ACCENT_COLOR := Color(0.88, 0.35, 0.22, 1.0)  # Active/focus accent.
const TEXT_COLOR := Color(0.96, 0.95, 0.91, 1.0)  # Primary readable text.
const MUTED_COLOR := Color(0.68, 0.7, 0.71, 1.0)  # Explanatory copy.
const MIN_PANEL_SIZE := Vector2(340, 310)  # Small landscape phone lower bound.
const MAX_PANEL_SIZE := Vector2(760, 560)  # Prevents over-expansion on desktop.
const OPEN_DURATION := 0.22  # Overlay entrance duration.

var _controls: Dictionary = {}
var _syncing := false
var _panel: PanelContainer
var _match_context: Dictionary = {}
var _bridge_status_label: Label
var _match_id_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_resize_panel()
	visible = false
	get_viewport().size_changed.connect(_resize_panel)


## Opens the settings overlay and synchronizes every control with current values.
func open(values: Dictionary) -> void:
	_sync_controls(values)
	_sync_match_context()
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, OPEN_DURATION)
	tween.tween_property(_panel, "scale", Vector2.ONE, OPEN_DURATION)


## Closes the overlay immediately after its short fade transition.
func close() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, OPEN_DURATION * 0.7)
	tween.tween_callback(func() -> void: visible = false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.add_theme_stylebox_override("panel", _style(PANEL_COLOR, 18))
	add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_panel.add_child(root)
	root.add_child(_build_header())
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 17)
	root.add_child(tabs)
	tabs.add_child(_build_video_section())
	tabs.add_child(_build_quality_section())
	tabs.add_child(_build_lighting_section())
	tabs.add_child(_build_appearance_section())
	tabs.add_child(_build_gameplay_section())
	root.add_child(_build_footer())


func _resize_panel() -> void:
	if _panel == null:
		return
	var available := get_viewport_rect().size * Vector2(0.92, 0.90)
	var target := Vector2(
		clampf(available.x, MIN_PANEL_SIZE.x, MAX_PANEL_SIZE.x),
		clampf(available.y, MIN_PANEL_SIZE.y, MAX_PANEL_SIZE.y)
	)
	_panel.offset_left = -target.x * 0.5
	_panel.offset_top = -target.y * 0.5
	_panel.offset_right = target.x * 0.5
	_panel.offset_bottom = target.y * 0.5


func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = "SETTINGS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 44)
	close_button.tooltip_text = "Close settings"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close_button)
	return row


func _build_video_section() -> Control:
	var section := _section("VIDEO")
	var content := section.get_node("Scroll/Content") as VBoxContainer
	var dynamic := CheckButton.new()
	dynamic.text = "DYNAMIC 3D RESOLUTION"
	dynamic.toggled.connect(func(value: bool) -> void: _emit_value("dynamic_resolution", value))
	_controls["dynamic_resolution"] = dynamic
	content.add_child(_row("Automatically adapt render scale to performance.", dynamic))
	_add_slider(content, "MINIMUM RENDER SCALE", "resolution_scale_min", 0.5, 1.0, 0.05)
	_add_slider(content, "MAXIMUM RENDER SCALE", "resolution_scale_max", 0.5, 1.0, 0.05)
	return section


func _build_quality_section() -> Control:
	var section := _section("3D QUALITY")
	var content := section.get_node("Scroll/Content") as VBoxContainer
	var quality := OptionButton.new()
	quality.add_item("LOW")
	quality.add_item("MEDIUM")
	quality.add_item("HIGH")
	quality.item_selected.connect(func(index: int) -> void: _emit_value("quality_3d", index))
	_controls["quality_3d"] = quality
	content.add_child(_row("Controls MSAA and real-time shadow quality.", quality))
	var visual_debug := CheckButton.new()
	visual_debug.text = "VISUAL DEBUG"
	visual_debug.toggled.connect(func(value: bool) -> void: _emit_value("visual_debug", value))
	_controls["visual_debug"] = visual_debug
	content.add_child(
		_row("Show runtime debug info, one-centimetre grid points and model pivots.", visual_debug)
	)
	return section


func _build_lighting_section() -> Control:
	var section := _section("LIGHTING")
	var content := section.get_node("Scroll/Content") as VBoxContainer
	_add_slider(content, "SCENE LIGHT INTENSITY", "lighting_intensity", 0.25, 1.5, 0.05)
	var note := Label.new()
	note.text = "Adjusts key, fill and ambient light together without changing game state."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(note)
	return section


func set_match_context(context: Dictionary) -> void:
	_match_context = context.duplicate(true)
	_sync_match_context()


func _sync_match_context() -> void:
	if _match_id_label != null:
		_match_id_label.text = str(_match_context.get("session_id", "Not connected"))
	if _bridge_status_label != null:
		_bridge_status_label.text = str(_match_context.get("github_bridge_status", "disabled")).to_upper()
	if _controls.has("github_jobs_enabled") and not _syncing:
		_syncing = true
		(_controls["github_jobs_enabled"] as CheckButton).button_pressed = bool(_match_context.get("github_jobs_enabled", false))
		_syncing = false


func _copy_match_id() -> void:
	var session_id := str(_match_context.get("session_id", ""))
	if not session_id.is_empty():
		DisplayServer.clipboard_set(session_id)


func _build_appearance_section() -> Control:
	var section := _section("APPEARANCE")
	var content := section.get_node("Scroll/Content") as VBoxContainer
	var profile := OptionButton.new()
	profile.add_item("BOARDROOM")
	profile.add_item("HIGH CONTRAST")
	profile.item_selected.connect(func(index: int) -> void: _emit_value("ui_theme_profile", index))
	_controls["ui_theme_profile"] = profile
	content.add_child(_row("GLOBAL UI STYLE PROFILE", profile))
	_add_slider(content, "FONT AND CONTROL SCALE", "ui_font_scale", 0.8, 1.4, 0.05)
	var accent := ColorPickerButton.new()
	accent.edit_alpha = false
	accent.color_changed.connect(func(value: Color) -> void: _emit_value("ui_accent_color", value))
	_controls["ui_accent_color"] = accent
	content.add_child(_row("GLOBAL ACCENT COLOR", accent))
	var note := Label.new()
	note.text = "The selected template applies to all modular UI components immediately."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(note)
	return section


func _build_gameplay_section() -> Control:
	var section := _section("GAMEPLAY")
	var content := section.get_node("Scroll/Content") as VBoxContainer
	var pickup_mode := OptionButton.new()
	pickup_mode.add_item("ONE AT A TIME")
	pickup_mode.add_item("WHOLE STACK")
	pickup_mode.item_selected.connect(
		func(index: int) -> void: _emit_value("hand_pickup_mode", index)
	)
	_controls["hand_pickup_mode"] = pickup_mode
	content.add_child(_row("HAND PICKUP FOR STACKABLE COMPONENTS", pickup_mode))
	var note := Label.new()
	note.text = (
		"One at a time separates a single unit. "
		+ "Whole stack moves the complete stack into your hand."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(note)
	_match_id_label = Label.new()
	_match_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_row("MATCH / SESSION ID", _match_id_label))
	var copy := Button.new()
	copy.text = "COPY MATCH ID"
	copy.pressed.connect(_copy_match_id)
	content.add_child(copy)
	var bridge := CheckButton.new()
	bridge.text = "ENABLE GITHUB JOBS BRIDGE"
	bridge.toggled.connect(func(value: bool) -> void: _emit_value("github_jobs_enabled", value))
	_controls["github_jobs_enabled"] = bridge
	content.add_child(_row("Allow this match to participate in the Phase 1 lease and polling bridge.", bridge))
	_bridge_status_label = Label.new()
	_bridge_status_label.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(_row("BRIDGE STATUS", _bridge_status_label))
	return section


func _section(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = title
	panel.add_theme_stylebox_override("panel", _style(SECTION_COLOR, 10))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	return panel


func _row(description: String, control: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.custom_minimum_size.y = 76
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = description
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(label)
	control.custom_minimum_size = Vector2(0, 44)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_slider(
	content: VBoxContainer,
	label_text: String,
	key: String,
	minimum: float,
	maximum: float,
	step: float
) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value_changed.connect(func(value: float) -> void: _emit_value(key, value))
	_controls[key] = slider
	content.add_child(_row(label_text, slider))


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	var reset := Button.new()
	reset.text = "RESET DEFAULTS"
	reset.pressed.connect(func() -> void: reset_requested.emit())
	row.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(130, 48)
	done.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(done)
	return row


func _sync_controls(values: Dictionary) -> void:
	_syncing = true
	for key in _controls:
		var control: Control = _controls[key]
		if control is CheckButton:
			(control as CheckButton).button_pressed = bool(values.get(key, false))
		elif control is OptionButton:
			(control as OptionButton).select(int(values.get(key, 0)))
		elif control is Range:
			(control as Range).value = float(values.get(key, 1.0))
		elif control is ColorPickerButton:
			(control as ColorPickerButton).color = values.get(key, Color.WHITE)
	_syncing = false


func _emit_value(key: String, value: Variant) -> void:
	if not _syncing:
		setting_changed.emit(key, value)


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style
