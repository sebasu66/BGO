extends "res://src/runtime/client_runtime_camera.gd"


func _create_hud() -> void:
	super._create_hud()
	_setup_client_settings()
	_setup_modular_shell()
	_setup_context_menu()


func _setup_modular_shell() -> void:
	title_label.visible = false
	hint_label.visible = false
	if _status_label != null:
		_status_label.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	var filters := get_node_or_null("CameraFilters")
	if filters != null:
		var filter_button: Variant = filters.get("_button")
		if filter_button is Button:
			(filter_button as Button).visible = false

	var header_scene := BgoComponentRegistry.load_scene("bgo.ui.session_header")
	var strip_scene := BgoComponentRegistry.load_scene("bgo.ui.action_strip")
	if header_scene == null or strip_scene == null:
		logger.error("MODULAR_SHELL_COMPONENT_MISSING")
		return

	_session_header = header_scene.instantiate() as BgoSessionHeader
	_session_header.name = "SessionHeader"
	_session_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_session_header.offset_left = 92
	_session_header.offset_top = 12
	_session_header.offset_right = -12
	_session_header.offset_bottom = 70
	_session_header.profile_pressed.connect(_open_profile_selector)
	_session_header.action_requested.connect(_on_shell_action)
	(
		_session_header
		. configure_actions(
			[
				{"id": "settings", "icon": "settings", "tooltip": "Settings"},
				{"id": "lobby", "icon": "house", "tooltip": "Return to lobby"},
				{"id": "fullscreen", "icon": "maximize", "tooltip": "Full screen"},
			]
		)
	)
	$UI.add_child(_session_header)

	_game_strip = strip_scene.instantiate() as BgoActionStrip
	_game_strip.name = "GameActions"
	_game_strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_game_strip.offset_left = 12
	_game_strip.offset_top = 82
	_game_strip.offset_right = 76
	_game_strip.offset_bottom = 525
	(
		_game_strip
		. configure(
			"GAME",
			[
				{
					"id": "pickup",
					"label": "PICK UP",
					"icon": "hand",
					"toggle": true,
					"group": "hand_mode"
				},
				{
					"id": "place",
					"label": "PLACE",
					"icon": "map-pin",
					"toggle": true,
					"group": "hand_mode"
				},
				{"id": "asset_box", "label": "GAME BOX", "icon": "box"},
				{"id": "filters", "label": "FILTERS", "icon": "filter"},
				{"id": "camera", "label": "RESET CAMERA", "icon": "rotate-ccw"},
				{"id": "help", "label": "GAME MANUAL", "icon": "info"},
			],
			"left"
		)
	)
	_game_strip.action_requested.connect(_on_shell_action)
	$UI.add_child(_game_strip)

	_build_profile_selector()
	_apply_ui_theme_from_settings()
	_refresh_session_header()
	logger.info("MODULAR_UI_SHELL_READY", {"profile": _current_profile_key()})


func _refresh_session_header() -> void:
	if _session_header == null:
		return
	var game: Dictionary = game_definition.get("game", {})
	var profile_key := _current_profile_key()
	var profile_label := "SPECTATOR"
	var profile_icon := "eye"
	var profile_color := Color(0.72, 0.75, 0.78)
	if profile_key == "host":
		profile_label = "HOST"
		profile_icon = "crown"
		profile_color = Color(0.95, 0.78, 0.30)
	elif profile_key.begins_with("player_"):
		profile_color = _player_color(profile_key)
		profile_label = "YELLOW" if profile_key == "player_1" else "BLUE"
		profile_icon = "user"
	(
		_session_header
		. set_state(
			{
				"game_name": str(game.get("name", game_id)),
				"game_type": "BOARD GAME",
				"mode": "GAME",
				"profile_label": profile_label,
				"profile_icon": profile_icon,
				"profile_color": profile_color,
				"turn_number": 0,
			}
		)
	)


func _current_profile_key() -> String:
	if not _hotseat_profile.is_empty():
		return _hotseat_profile
	return player_id if client_role == ROLE_PLAYER else "spectator"


func _build_profile_selector() -> void:
	_profile_popup = PopupPanel.new()
	_profile_popup.name = "ProfileSelector"
	_profile_popup.size = Vector2i(320, 270)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_profile_popup.add_child(list)
	var title := Label.new()
	title.text = "VIEW AS"
	title.add_theme_font_size_override("font_size", 18)
	list.add_child(title)
	_add_profile_option(list, "spectator", "SPECTATOR", "eye", Color(0.72, 0.75, 0.78))
	_add_profile_option(list, "host", "HOST", "crown", Color(0.95, 0.78, 0.30))
	_add_profile_option(list, "player_1", "YELLOW PLAYER", "user", _player_color("player_1"))
	_add_profile_option(list, "player_2", "BLUE PLAYER", "user", _player_color("player_2"))
	$UI.add_child(_profile_popup)


func _add_profile_option(
	container: VBoxContainer, profile_key: String, label: String, icon_name: String, color: Color
) -> void:
	var button := Button.new()
	button.text = label
	button.icon = LucideTexture.new(icon_name, 24.0, color, 2.0)
	button.custom_minimum_size = Vector2(286, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_switch_hotseat_profile.bind(profile_key))
	container.add_child(button)


func _open_profile_selector() -> void:
	if _profile_popup == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_profile_popup.position = Vector2i(int(viewport_size.x * 0.5 - 160), 78)
	_profile_popup.popup()


func _switch_hotseat_profile(profile_key: String) -> void:
	if profile_key == _current_profile_key():
		_profile_popup.hide()
		return
	_hotseat_profile = profile_key
	logger.info("LOCAL_VIEW_PROFILE_CHANGED", {"profile": profile_key})
	get_tree().reload_current_scene()


func _on_shell_action(action_id: String) -> void:
	match action_id:
		"pickup":
			_set_mode(MODE_PICK_UP if interaction_mode != MODE_PICK_UP else MODE_NONE)
		"place":
			_set_mode(MODE_PLACE if interaction_mode != MODE_PLACE else MODE_NONE)
		"asset_box":
			_set_status("Game Box drawer is available from the hand component")
		"settings":
			_open_settings()
		"filters":
			_open_camera_filters()
		"camera":
			reset_player_camera()
		"fullscreen":
			_enter_web_fullscreen()
		"help":
			_open_help_manual()
		"lobby":
			_return_to_lobby()


func _apply_landscape_player_layout() -> void:
	super._apply_landscape_player_layout()
	if client_role != ROLE_PLAYER:
		return
	_hide_button_by_text(_player_controls, "FULL SCREEN")
	# The modular shell owns utility actions; keep the legacy builder only for old scenes.


func _build_utility_strip() -> void:
	if _utility_panel != null:
		_utility_panel.queue_free()

	_utility_panel = PanelContainer.new()
	_utility_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_utility_panel.offset_left = 12.0
	_utility_panel.offset_right = 166.0
	_utility_panel.offset_top = 14.0
	_utility_panel.offset_bottom = -14.0
	$UI.add_child(_utility_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_utility_panel.add_child(root)

	var top_actions := HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 8)
	root.add_child(top_actions)

	_utility_collapse_button = Button.new()
	_utility_collapse_button.text = "â€¹"
	_utility_collapse_button.custom_minimum_size = Vector2(44, 42)
	_utility_collapse_button.tooltip_text = "Collapse utility controls"
	_utility_collapse_button.pressed.connect(_toggle_utility_strip)
	top_actions.add_child(_utility_collapse_button)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_actions.add_child(top_spacer)

	var help_button := Button.new()
	help_button.text = "?"
	help_button.custom_minimum_size = Vector2(44, 42)
	help_button.tooltip_text = "Open the BGO help manual in a new tab"
	help_button.pressed.connect(_open_help_manual)
	top_actions.add_child(help_button)

	_utility_content = VBoxContainer.new()
	_utility_content.add_theme_constant_override("separation", 8)
	root.add_child(_utility_content)

	_add_utility_button(
		"RESET CAM", reset_player_camera, "Return the camera to the player default view"
	)
	_add_utility_button(
		"FILTER", _open_camera_filters, "Choose which owners and component types are interactive"
	)
	_add_utility_button("SETTINGS", _open_settings, "Open client graphics and lighting settings")
	_add_utility_button("FULL SCREEN", _enter_web_fullscreen, "Enter fullscreen landscape mode")
	_add_utility_button("LOBBY", _return_to_lobby, "Return to the test lobby")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_utility_content.add_child(spacer)

	var camera_help := Label.new()
	camera_help.text = (
		"Mouse: L/M drag pan Â· R drag orbit Â· wheel zoom\n"
		+ "Keys: WASD/arrows pan Â· Q/E orbit Â· +/- zoom Â· R reset"
	)
	camera_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_help.add_theme_font_size_override("font_size", 12)
	_utility_content.add_child(camera_help)


func _add_utility_button(label_text: String, callback: Callable, tooltip: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(130, 48)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	_utility_content.add_child(button)


func _toggle_utility_strip() -> void:
	_utility_collapsed = not _utility_collapsed
	if _utility_content != null:
		_utility_content.visible = not _utility_collapsed
	if _utility_panel != null:
		_utility_panel.offset_right = 116.0 if _utility_collapsed else 166.0
	if _utility_collapse_button != null:
		_utility_collapse_button.text = "â€º" if _utility_collapsed else "â€¹"


func _open_help_manual() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('/help/', '_blank', 'noopener,noreferrer');", true)
		logger.info("HELP_MANUAL_OPENED", {"target": "/help/"})
		return
	var manual_path := ProjectSettings.globalize_path("res://hosting/help/index.html")
	var open_error := OS.shell_open(manual_path)
	if open_error == OK:
		logger.info("HELP_MANUAL_OPENED", {"target": manual_path})
		return
	logger.error("HELP_MANUAL_OPEN_FAILED", {"target": manual_path, "error": open_error})
	_set_status("Could not open the help manual")


func _open_camera_filters() -> void:
	var filters := get_node_or_null("CameraFilters")
	if filters == null:
		return
	var standalone_button: Variant = filters.get("_button")
	if standalone_button is Button:
		(standalone_button as Button).visible = false
	filters.call("_toggle_popup")


func _setup_client_settings() -> void:
	_settings_controller = BgoClientSettingsController.new()
	_settings_controller.name = "ClientSettings"
	add_child(_settings_controller)
	_settings_controller.initialize(self)
	_apply_visual_debug_ui()

	var packed := BgoComponentRegistry.load_scene("bgo.ui.settings_panel")
	if packed == null:
		logger.error("SETTINGS_COMPONENT_MISSING", {"component_id": "bgo.ui.settings_panel"})
		return
	_settings_panel = packed.instantiate() as BgoSettingsPanel
	_settings_panel.name = "SettingsPanel"
	$UI.add_child(_settings_panel)
	_settings_panel.setting_changed.connect(_on_client_setting_changed)
	_settings_panel.close_requested.connect(_close_settings)
	_settings_panel.reset_requested.connect(_reset_settings)

	_settings_button = Button.new()
	_settings_button.text = "âš™"
	_settings_button.tooltip_text = "Settings"
	_settings_button.custom_minimum_size = Vector2(48, 44)
	_settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Keep clear of the existing FILTER control at the far-right edge.
	_settings_button.offset_left = -174
	_settings_button.offset_top = 12
	_settings_button.offset_right = -126
	_settings_button.offset_bottom = 56
	_settings_button.pressed.connect(_open_settings)
	$UI.add_child(_settings_button)
	$UI.move_child(_settings_panel, $UI.get_child_count() - 1)
	logger.info("CLIENT_SETTINGS_READY", _settings_controller.values)


func _open_settings() -> void:
	if _settings_panel == null or _settings_controller == null:
		return
	_settings_panel.open(_settings_controller.values)
	logger.info("SETTINGS_OPENED", {"role": client_role, "player_id": player_id})


func _close_settings() -> void:
	if _settings_panel != null:
		_settings_panel.close()


func _reset_settings() -> void:
	if _settings_controller == null:
		return
	_settings_controller.reset_defaults()
	_apply_visual_debug_ui()
	_settings_panel.open(_settings_controller.values)
	logger.info("SETTINGS_RESET", _settings_controller.values)


func _on_client_setting_changed(key: String, value: Variant) -> void:
	if _settings_controller == null or not _settings_controller.set_value(key, value):
		return
	if key.begins_with("ui_"):
		_apply_ui_theme_from_settings()
	if key == "visual_debug":
		_apply_visual_debug_ui()
	logger.info("CLIENT_SETTING_CHANGED", {"key": key, "value": value})


func _apply_visual_debug_ui() -> void:
	if _debug_label != null and _settings_controller != null:
		_debug_label.visible = bool(_settings_controller.values.get("visual_debug", false))


func _apply_ui_theme_from_settings() -> void:
	if _settings_controller == null:
		return
	var profile_id := (
		"high_contrast"
		if int(_settings_controller.values.get("ui_theme_profile", 0)) == 1
		else "boardroom"
	)
	(
		UI_THEME_PROFILES
		. apply_to(
			$UI,
			profile_id,
			{
				"font_scale": float(_settings_controller.values.get("ui_font_scale", 1.0)),
				"accent": _settings_controller.values.get("ui_accent_color", Color("#d7aa4c")),
			}
		)
	)


func _return_to_lobby() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href='/test-launcher/';", true)
		return
	_set_status("Lobby navigation is available in the Web client")


func _hide_button_by_text(node: Node, target_text: String) -> bool:
	if node == null:
		return false
	if node is Button and (node as Button).text == target_text:
		(node as Button).visible = false
		return true
	for child in node.get_children():
		if _hide_button_by_text(child, target_text):
			return true
	return false


func _on_piece_tapped(piece: Node3D) -> void:
	if bool(piece.get_meta("bgo_filtered_out", false)):
		if logger != null:
			logger.info("FILTERED_COMPONENT_IGNORED", {"piece_id": piece.name})
		return
	super._on_piece_tapped(piece)


func _projected_piece_at(screen_position: Vector2) -> Node3D:
	var closest: Node3D = null
	var closest_distance := INF
	var viewport_size := get_viewport().get_visible_rect().size
	var threshold := maxf(54.0, minf(viewport_size.x, viewport_size.y) * 0.055)
	for value in pieces.values():
		var piece := value as Node3D
		if piece == null or bool(piece.get_meta("bgo_filtered_out", false)):
			continue
		if camera.is_position_behind(piece.global_position):
			continue
		var projected := camera.unproject_position(piece.global_position)
		var distance := projected.distance_to(screen_position)
		if distance < threshold and distance < closest_distance:
			closest = piece
			closest_distance = distance
	return closest
