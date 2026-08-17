class_name LenteDefaultUI
extends Control

## The shipped UI implements the same command/state contract available to custom UIs.

signal command_requested(command: StringName, payload: Variant)

const Localization := preload("res://addons/lente/runtime/lente_localization.gd")
const FILTER_TRANSLATION_KEYS := [
	&"LENTE_FILTER_NEUTRAL", &"LENTE_FILTER_CINEMA", &"LENTE_FILTER_NOIR",
	&"LENTE_FILTER_WARM", &"LENTE_FILTER_COOL", &"LENTE_FILTER_VINTAGE",
	&"LENTE_FILTER_VIVID", &"LENTE_FILTER_BLEACH_BYPASS",
	&"LENTE_FILTER_TEAL_ORANGE", &"LENTE_FILTER_FADED_FILM",
	&"LENTE_FILTER_DREAM", &"LENTE_FILTER_NIGHT",
]

var _controller: Node
var _built := false
var _syncing := false
var _controls: Dictionary = {}
var _value_labels: Dictionary = {}
var _settings_panel: PanelContainer
var _gallery_panel: PanelContainer
var _gallery_grid: GridContainer
var _preview_panel: PanelContainer
var _preview_texture: TextureRect
var _flash: ColorRect
var _toast: Label
var _status_label: Label
var _dof_toggle: CheckButton
var _screen_filter_toggle: CheckButton
var _filter_option: OptionButton
var _preset_option: OptionButton
var _preset_name: LineEdit
var _first_focus_control: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.ensure_registered()
	_build_interface()


func bind_lente(controller: Node) -> void:
	_controller = controller
	if not _built:
		_build_interface()
	if controller.has_signal("state_changed"):
		controller.state_changed.connect(_on_state_changed)
	if controller.has_signal("capture_started"):
		controller.capture_started.connect(_on_capture_started)
	if controller.has_signal("photo_captured"):
		controller.photo_captured.connect(_on_photo_captured)
	if controller.has_signal("focus_changed"):
		controller.focus_changed.connect(_on_focus_changed)
	if controller.has_signal("message_requested"):
		controller.message_requested.connect(show_toast)
	if controller.has_method("get_state"):
		_on_state_changed(controller.get_state())


func toggle_gallery() -> void:
	_gallery_panel.visible = not _gallery_panel.visible
	_settings_panel.visible = not _gallery_panel.visible
	_preview_panel.visible = false
	command_requested.emit(&"set_ui_interactive", _gallery_panel.visible)
	if _gallery_panel.visible:
		_refresh_gallery()


func show_toast(message: String) -> void:
	if not _toast:
		return
	_toast.text = message
	_toast.modulate.a = 0.0
	_toast.visible = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	tween.tween_interval(1.7)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.32)
	tween.tween_callback(_toast.hide)


func _build_interface() -> void:
	if _built:
		return
	_built = true
	theme = _make_theme()
	_build_viewfinder()
	_build_header()
	_build_settings_panel()
	_build_footer()
	_build_gallery()
	_build_feedback()


func _build_viewfinder() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var reticle := Label.new()
	reticle.text = "＋"
	reticle.add_theme_font_size_override("font_size", 29)
	reticle.modulate = Color(0.92, 1.0, 0.98, 0.8)
	center.add_child(reticle)
	for corner_data in [[0.035, 0.055, 1, 1], [0.965, 0.055, -1, 1], [0.035, 0.945, 1, -1], [0.965, 0.945, -1, -1]]:
		var corner := Control.new()
		corner.set_anchor(SIDE_LEFT, corner_data[0])
		corner.set_anchor(SIDE_TOP, corner_data[1])
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(corner)
		var horizontal := ColorRect.new()
		horizontal.color = Color(0.82, 1.0, 0.95, 0.72)
		horizontal.position = Vector2(0.0 if corner_data[2] > 0 else -34.0, 0.0)
		horizontal.size = Vector2(34.0, 2.0)
		corner.add_child(horizontal)
		var vertical := ColorRect.new()
		vertical.color = horizontal.color
		vertical.position = Vector2(0.0, 0.0 if corner_data[3] > 0 else -34.0)
		vertical.size = Vector2(2.0, 34.0)
		corner.add_child(vertical)


func _build_header() -> void:
	var header := PanelContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24.0
	header.offset_top = 20.0
	header.offset_right = -24.0
	header.offset_bottom = 68.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.06, 0.78), 12))
	add_child(header)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	header.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	var brand := Label.new()
	brand.text = "LENTE  /  " + Localization.text(&"LENTE_PHOTO_MODE")
	brand.add_theme_font_size_override("font_size", 15)
	brand.add_theme_color_override("font_color", Color("d8fff7"))
	row.add_child(brand)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_status_label = Label.new()
	_status_label.text = "50 mm   •   f/16   •   ±0.0 EV"
	_status_label.modulate = Color(0.88, 0.94, 0.93, 0.74)
	row.add_child(_status_label)


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchor(SIDE_LEFT, 1.0)
	_settings_panel.set_anchor(SIDE_RIGHT, 1.0)
	_settings_panel.set_anchor(SIDE_BOTTOM, 1.0)
	_settings_panel.offset_left = -408.0
	_settings_panel.offset_top = 84.0
	_settings_panel.offset_right = -24.0
	_settings_panel.offset_bottom = -82.0
	_settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.038, 0.046, 0.92), 14))
	add_child(_settings_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var title := Label.new()
	title.text = Localization.text(&"LENTE_LENS_GRADE")
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("5dd9c1"))
	content.add_child(title)
	_add_slider(content, &"fov", Localization.text(&"LENTE_FOV"), 20.0, 120.0, 1.0)
	_add_slider(content, &"focus_distance", Localization.text(&"LENTE_FOCUS_DISTANCE"), 0.2, 200.0, 0.1)
	_add_slider(content, &"aperture", Localization.text(&"LENTE_APERTURE"), 1.4, 16.0, 0.1)
	_dof_toggle = CheckButton.new()
	_dof_toggle.text = Localization.text(&"LENTE_DOF")
	_dof_toggle.toggled.connect(_on_dof_toggled)
	content.add_child(_dof_toggle)
	_add_slider(content, &"exposure", Localization.text(&"LENTE_EXPOSURE"), -4.0, 4.0, 0.1)
	_add_slider(content, &"roll", Localization.text(&"LENTE_ROLL"), -45.0, 45.0, 1.0)
	_add_separator(content)
	_filter_option = OptionButton.new()
	for translation_key in FILTER_TRANSLATION_KEYS:
		_filter_option.add_item(Localization.text(translation_key))
	_filter_option.item_selected.connect(_on_filter_selected)
	_add_labeled_control(content, Localization.text(&"LENTE_FILTER"), _filter_option)
	_add_slider(content, &"filter_strength", Localization.text(&"LENTE_FILTER_STRENGTH"), 0.0, 1.0, 0.01)
	_add_slider(content, &"vignette", Localization.text(&"LENTE_VIGNETTE"), 0.0, 1.0, 0.01)
	_add_slider(content, &"saturation", Localization.text(&"LENTE_SATURATION"), 0.0, 2.0, 0.01)
	_add_slider(content, &"contrast", Localization.text(&"LENTE_CONTRAST"), 0.5, 1.5, 0.01)
	_add_slider(content, &"temperature", Localization.text(&"LENTE_TEMPERATURE"), -1.0, 1.0, 0.01)
	_screen_filter_toggle = CheckButton.new()
	_screen_filter_toggle.text = Localization.text(&"LENTE_KEEP_GAME_FILTER")
	_screen_filter_toggle.visible = false
	_screen_filter_toggle.toggled.connect(_on_screen_filter_toggled)
	content.add_child(_screen_filter_toggle)
	_add_separator(content)
	var reset := Button.new()
	reset.text = Localization.text(&"LENTE_RESET")
	reset.pressed.connect(func(): command_requested.emit(&"reset", null))
	content.add_child(reset)
	var preset_title := Label.new()
	preset_title.text = Localization.text(&"LENTE_PRESET")
	preset_title.modulate = Color(1.0, 1.0, 1.0, 0.7)
	content.add_child(preset_title)
	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_preset_option)
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 5)
	content.add_child(preset_row)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = Localization.text(&"LENTE_MY_LOOK")
	_preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(_preset_name)
	var save := Button.new()
	save.text = Localization.text(&"LENTE_SAVE")
	save.pressed.connect(_save_preset)
	preset_row.add_child(save)
	var load_button := Button.new()
	load_button.text = Localization.text(&"LENTE_LOAD")
	load_button.pressed.connect(_load_preset)
	content.add_child(load_button)


func _build_footer() -> void:
	var footer := PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24.0
	footer.offset_top = -66.0
	footer.offset_right = -24.0
	footer.offset_bottom = -20.0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.06, 0.82), 12))
	add_child(footer)
	var hints := Label.new()
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hints.text = "[WASD] %s    [%s / RS] %s    [LMB / R3] %s    [Space / A] %s    [Tab / Y] %s    [G / X] %s    [Esc / B] %s" % [Localization.text(&"LENTE_MOVE"), Localization.text(&"LENTE_MOUSE"), Localization.text(&"LENTE_LOOK"), Localization.text(&"LENTE_FOCUS"), Localization.text(&"LENTE_CAPTURE"), Localization.text(&"LENTE_CONTROLS"), Localization.text(&"LENTE_GALLERY"), Localization.text(&"LENTE_EXIT")]
	hints.add_theme_font_size_override("font_size", 12)
	hints.modulate = Color(0.9, 0.96, 0.94, 0.78)
	footer.add_child(hints)


func _build_gallery() -> void:
	_gallery_panel = PanelContainer.new()
	_gallery_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_panel.offset_left = 48.0
	_gallery_panel.offset_top = 84.0
	_gallery_panel.offset_right = -48.0
	_gallery_panel.offset_bottom = -82.0
	_gallery_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.028, 0.034, 0.98), 16))
	_gallery_panel.visible = false
	add_child(_gallery_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_gallery_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var title := Label.new()
	title.text = "LENTE  /  " + Localization.text(&"LENTE_GALLERY")
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("5dd9c1"))
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close := Button.new()
	close.text = Localization.text(&"LENTE_CLOSE")
	close.pressed.connect(toggle_gallery)
	row.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 4
	_gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_grid.add_theme_constant_override("h_separation", 12)
	_gallery_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_gallery_grid)
	_preview_panel = PanelContainer.new()
	_preview_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.015, 0.018, 0.98), 12))
	_preview_panel.visible = false
	_gallery_panel.add_child(_preview_panel)
	var preview_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		preview_margin.add_theme_constant_override("margin_" + side, 20)
	_preview_panel.add_child(preview_margin)
	var preview_column := VBoxContainer.new()
	preview_margin.add_child(preview_column)
	_preview_texture = TextureRect.new()
	_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(_preview_texture)
	var preview_close := Button.new()
	preview_close.text = Localization.text(&"LENTE_CLOSE")
	preview_close.pressed.connect(func(): _preview_panel.hide())
	preview_column.add_child(preview_close)


func _build_feedback() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-150.0, 92.0)
	_toast.size = Vector2(300.0, 42.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.045, 0.05, 0.94), 10))
	_toast.visible = false
	add_child(_toast)


func _add_slider(parent: VBoxContainer, key: StringName, label_text: String, minimum: float, maximum: float, step: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	var header := HBoxContainer.new()
	block.add_child(header)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(0.91, 0.96, 0.94, 0.82)
	header.add_child(label)
	var value_label := Label.new()
	value_label.text = "—"
	value_label.add_theme_color_override("font_color", Color("8ff7e3"))
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(key))
	block.add_child(slider)
	_controls[key] = slider
	_value_labels[key] = value_label
	if not _first_focus_control:
		_first_focus_control = slider


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size.x = 145.0
	row.add_child(control)


func _add_separator(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	separator.modulate.a = 0.28
	parent.add_child(separator)


func _on_slider_changed(value: float, key: StringName) -> void:
	if _syncing:
		return
	_update_value_label(key, value)
	command_requested.emit(&"set_parameter", {"name": key, "value": value})


func _on_dof_toggled(enabled: bool) -> void:
	if not _syncing:
		command_requested.emit(&"set_parameter", {"name": &"dof_enabled", "value": enabled})


func _on_screen_filter_toggled(enabled: bool) -> void:
	if not _syncing:
		command_requested.emit(&"set_parameter", {"name": &"screen_filters_enabled", "value": enabled})


func _on_filter_selected(index: int) -> void:
	if not _syncing:
		command_requested.emit(&"apply_filter_preset", index)


func _on_state_changed(state: Dictionary) -> void:
	_syncing = true
	for key in _controls:
		if state.has(key):
			_controls[key].value = float(state[key])
			_update_value_label(key, float(state[key]))
	if _dof_toggle:
		_dof_toggle.button_pressed = bool(state.get("dof_enabled", false))
	if _screen_filter_toggle:
		_screen_filter_toggle.visible = bool(state.get("screen_filter_choice_available", false))
		_screen_filter_toggle.button_pressed = bool(state.get("screen_filters_enabled", true))
	if _filter_option:
		_filter_option.select(clampi(int(state.get("filter", 0)), 0, FILTER_TRANSLATION_KEYS.size() - 1))
	var interactive := bool(state.get("ui_interactive", false))
	if _settings_panel:
		_settings_panel.modulate.a = 1.0 if interactive else 0.62
	if interactive and _first_focus_control and not _gallery_panel.visible:
		_first_focus_control.grab_focus()
	_update_presets(state.get("presets", PackedStringArray()))
	_status_label.text = "%d°   •   f/%.1f   •   %+.1f EV" % [roundi(float(state.get("fov", 75.0))), float(state.get("aperture", 16.0)), float(state.get("exposure", 0.0))]
	_syncing = false


func _update_value_label(key: StringName, value: float) -> void:
	if not _value_labels.has(key):
		return
	var text := "%.2f" % value
	match key:
		&"fov", &"roll":
			text = "%d°" % roundi(value)
		&"focus_distance":
			text = "%.1f m" % value
		&"aperture":
			text = "f/%.1f" % value
		&"exposure":
			text = "%+.1f EV" % value
		&"filter_strength", &"vignette":
			text = "%d%%" % roundi(value * 100.0)
		&"saturation", &"contrast":
			text = "%.2f×" % value
		&"temperature":
			text = "%+.2f" % value
	_value_labels[key].text = text


func _update_presets(presets: Variant) -> void:
	if not _preset_option:
		return
	var selected := _preset_option.get_item_text(_preset_option.selected) if _preset_option.item_count > 0 else ""
	_preset_option.clear()
	for preset in presets:
		_preset_option.add_item(str(preset))
	for index in _preset_option.item_count:
		if _preset_option.get_item_text(index) == selected:
			_preset_option.select(index)
			break


func _save_preset() -> void:
	var preset_name := _preset_name.text.strip_edges()
	if preset_name.is_empty():
		preset_name = Localization.text(&"LENTE_MY_LOOK")
	command_requested.emit(&"save_preset", preset_name)
	show_toast(Localization.text(&"LENTE_PRESET_SAVED") % preset_name)


func _load_preset() -> void:
	if _preset_option.item_count == 0:
		return
	command_requested.emit(&"load_preset", _preset_option.get_item_text(_preset_option.selected))


func _on_capture_started() -> void:
	_flash.modulate.a = 0.72
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_photo_captured(path: String, _metadata: Dictionary) -> void:
	show_toast("%s  •  %s" % [Localization.text(&"LENTE_PHOTO_SAVED"), path.get_file()])
	if _gallery_panel.visible:
		_refresh_gallery()


func _on_focus_changed(distance: float, _world_position: Vector3) -> void:
	show_toast("%s  •  %.1f m" % [Localization.text(&"LENTE_FOCUS_LOCKED"), distance])


func _refresh_gallery() -> void:
	for child in _gallery_grid.get_children():
		_gallery_grid.remove_child(child)
		child.queue_free()
	if not _controller or not _controller.has_method("list_photos"):
		return
	var photos: Array = _controller.list_photos(24)
	if photos.is_empty():
		var empty := Label.new()
		empty.text = Localization.text(&"LENTE_EMPTY_GALLERY")
		empty.custom_minimum_size = Vector2(320.0, 100.0)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gallery_grid.add_child(empty)
		return
	for photo in photos:
		_add_photo_card(photo)


func _add_photo_card(photo: Dictionary) -> void:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220.0, 155.0)
	card.text = photo.get("path", "").get_file().get_basename()
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var image := Image.new()
	var absolute_path := ProjectSettings.globalize_path(str(photo.get("path", "")))
	if image.load(absolute_path) == OK:
		var target_width := 320
		var target_height := maxi(2, roundi(float(image.get_height()) * float(target_width) / float(maxi(1, image.get_width()))))
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
		card.icon = ImageTexture.create_from_image(image)
		card.expand_icon = true
	card.pressed.connect(_show_photo.bind(str(photo.get("path", ""))))
	_gallery_grid.add_child(card)


func _show_photo(path: String) -> void:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return
	_preview_texture.texture = ImageTexture.create_from_image(image)
	_preview_panel.show()


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", Color("edf8f5"))
	result.set_color("font_color", "Button", Color("edf8f5"))
	result.set_color("font_hover_color", "Button", Color("ffffff"))
	result.set_color("font_pressed_color", "Button", Color("bfffee"))
	result.set_stylebox("normal", "Button", _panel_style(Color(0.10, 0.15, 0.17, 0.96), 7))
	result.set_stylebox("hover", "Button", _panel_style(Color(0.12, 0.24, 0.23, 0.98), 7, Color("5dd9c1")))
	result.set_stylebox("pressed", "Button", _panel_style(Color(0.08, 0.30, 0.27, 1.0), 7, Color("8ff7e3")))
	result.set_stylebox("focus", "Button", _panel_style(Color(0.0, 0.0, 0.0, 0.0), 7, Color("8ff7e3"), 2))
	return result


func _panel_style(color: Color, radius: int, border_color := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style
