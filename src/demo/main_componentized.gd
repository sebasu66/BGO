extends "res://src/demo/main_3d.gd"

const GAME_DEFINITION_PATH := "res://games/test001/game.jsonh"

var game_definition: Dictionary = {}
var definition_errors: Array[String] = []
var _private_hand_strip: HBoxContainer

func _ready() -> void:
	_request_landscape_orientation()
	_load_game_definition()
	var preview := get_node_or_null("EditorPreview")
	if preview != null:
		preview.queue_free()
	super._ready()
	if not game_definition.is_empty():
		var game: Dictionary = game_definition.get("game", {})
		title_label.text = "BGO · %s · %s" % [str(game.get("name", game_id)), client_role.to_upper()]
	if not definition_errors.is_empty():
		call_deferred("_show_definition_errors")

func _load_game_definition() -> void:
	var result := BgoGameDefinitionLoader.load_game(GAME_DEFINITION_PATH)
	if bool(result.get("ok", false)):
		game_definition = (result.get("data", {}) as Dictionary).duplicate(true)
		definition_errors.clear()
		return
	game_definition.clear()
	definition_errors.clear()
	var raw_errors: Variant = result.get("errors", [])
	if raw_errors is Array:
		for error_value in raw_errors:
			definition_errors.append(str(error_value))
	else:
		definition_errors.append(str(raw_errors))
	for message in definition_errors:
		push_warning("Game definition ignored: %s" % message)

func _show_definition_errors() -> void:
	if _status_label == null or definition_errors.is_empty():
		return
	_set_status("Definition ignored · %s" % definition_errors[0])
	if logger != null:
		logger.error("GAME_DEFINITION_REJECTED", {"path": GAME_DEFINITION_PATH, "errors": definition_errors})

func _create_board() -> void:
	var board := $Board as BgoCheckeredBoard
	if board == null:
		push_error("Main/Board must be a BgoCheckeredBoard component instance.")
		return

	var columns := GRID_COLUMNS
	var rows := GRID_ROWS
	var cell_size := CELL_SIZE
	if not game_definition.is_empty():
		var board_definition: Dictionary = game_definition.get("board", {})
		var component_id := str(board_definition.get("component", ""))
		if BgoComponentRegistry.get_kind(component_id) == "board":
			var config: Dictionary = board_definition.get("config", {})
			columns = int(config.get("columns", columns))
			rows = int(config.get("rows", rows))
			cell_size = float(config.get("cell_size", cell_size))
	board.configure(columns, rows, cell_size)

func _create_player_areas() -> void:
	var p1 := $Player1Area as BgoPlayerArea
	var p2 := $Player2Area as BgoPlayerArea
	if p1 != null:
		p1.configure("player_1", "PLAYER 1", Color("#8A6B16"))
	if p2 != null:
		p2.configure("player_2", "PLAYER 2", Color("#12456D"))

func _create_piece_from_state(piece_id: String, state: Dictionary) -> Node3D:
	var component_id := str(state.get("component_id", "bgo.piece.basic_cylinder"))
	if BgoComponentRegistry.get_kind(component_id) != "piece":
		push_warning("Unsupported piece component '%s' for %s; using basic cylinder." % [component_id, piece_id])
		component_id = "bgo.piece.basic_cylinder"
	var piece_scene := BgoComponentRegistry.load_scene(component_id)
	if piece_scene == null:
		push_error("Could not resolve component scene for '%s'." % component_id)
		return null
	var piece := piece_scene.instantiate() as Node3D
	if piece == null:
		return null
	piece.name = piece_id
	pieces_root.add_child(piece)
	piece.set_meta("piece_id", piece_id)
	piece.set_meta("component_id", component_id)
	piece.set_meta("owner_id", str(state.get("owner_id", "")))
	if piece.has_method("set_quantity"):
		piece.call("set_quantity", int(state.get("quantity", 1)))
	_apply_piece_config(piece, state.get("object_config", {}))
	return piece

func _apply_piece_config(piece: Node3D, config_value: Variant) -> void:
	if not config_value is Dictionary:
		return
	var config: Dictionary = config_value
	if piece.has_method("configure_from_dictionary"):
		piece.call("configure_from_dictionary", config)

func _hand_world_position(piece_index: int) -> Vector3:
	return _player_area_world_position(client_player_id, piece_index)

func _player_area_world_position(player_id: String, piece_index: int) -> Vector3:
	var area: BgoPlayerArea = $Player2Area if player_id == "player_2" else $Player1Area
	if area != null and area.has_method("slot_world_position"):
		return area.slot_world_position(piece_index)
	var side := 1.0 if player_id == "player_2" else -1.0
	return Vector3(side * 6.15, 0.35, -2.1 + float(piece_index) * 0.75)

func _cell_world(cell: Vector2i) -> Vector3:
	var board := $Board as BgoCheckeredBoard
	if board != null:
		return board.cell_world(cell)
	return super._cell_world(cell)

func _create_hud() -> void:
	super._create_hud()
	_apply_landscape_player_layout()

func _apply_landscape_player_layout() -> void:
	if client_role != "player" or ui_layer == null:
		return

	if mode_button != null:
		mode_button.offset_left = 1060.0
		mode_button.offset_top = 80.0
		mode_button.offset_right = 1248.0
		mode_button.offset_bottom = 144.0
	if fullscreen_button != null:
		fullscreen_button.offset_left = 1060.0
		fullscreen_button.offset_top = 154.0
		fullscreen_button.offset_right = 1248.0
		fullscreen_button.offset_bottom = 210.0
	if pickup_button != null:
		pickup_button.offset_left = 1060.0
		pickup_button.offset_top = 226.0
		pickup_button.offset_right = 1248.0
		pickup_button.offset_bottom = 300.0
	if place_button != null:
		place_button.offset_left = 1060.0
		place_button.offset_top = 310.0
		place_button.offset_right = 1248.0
		place_button.offset_bottom = 384.0

	var hand_label := Label.new()
	hand_label.name = "HandTitle"
	hand_label.text = "HAND"
	hand_label.offset_left = 28.0
	hand_label.offset_top = 610.0
	hand_label.offset_right = 160.0
	hand_label.offset_bottom = 640.0
	hand_label.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(hand_label)

	_private_hand_strip = HBoxContainer.new()
	_private_hand_strip.name = "PrivateHandStrip"
	_private_hand_strip.offset_left = 28.0
	_private_hand_strip.offset_top = 642.0
	_private_hand_strip.offset_right = 1010.0
	_private_hand_strip.offset_bottom = 706.0
	_private_hand_strip.add_theme_constant_override("separation", 8)
	ui_layer.add_child(_private_hand_strip)

func _request_landscape_orientation() -> void:
	if not OS.has_feature("web"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

func _enter_web_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(() => {
				const target = document.documentElement;
				if (!document.fullscreenElement && target.requestFullscreen) {
					target.requestFullscreen().catch(() => {});
				}
				if (screen.orientation && screen.orientation.lock) {
					screen.orientation.lock('landscape').catch(() => {});
				}
			})();
		""")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
