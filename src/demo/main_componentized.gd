extends "res://src/demo/main_3d.gd"

const BASIC_CYLINDER_SCENE := preload("res://src/components/pieces/basic_cylinder/basic_cylinder_piece.tscn")

func _ready() -> void:
	_request_landscape_orientation()
	super._ready()

func _create_board() -> void:
	var board := $Board as BgoCheckeredBoard
	if board == null:
		push_error("Main/Board must be a BgoCheckeredBoard component instance.")
		return
	board.configure(GRID_COLUMNS, GRID_ROWS, CELL_SIZE)

func _create_player_areas() -> void:
	# Player areas are permanent PackedScene instances in main.tscn.
	var p1 := $Player1Area as BgoPlayerArea
	var p2 := $Player2Area as BgoPlayerArea
	if p1 != null:
		p1.player_id = "player_1"
		p1.label_text = "PLAYER 1"
		p1.area_color = Color(0.45, 0.31, 0.06)
	if p2 != null:
		p2.player_id = "player_2"
		p2.label_text = "PLAYER 2"
		p2.area_color = Color(0.07, 0.27, 0.43)

func _create_piece_from_state(id: String, state: Dictionary, cell: Vector2i) -> void:
	var owner := str(state.get("owner_id", ""))
	var quantity := int(state.get("quantity", 1))
	var color := Color(0.95, 0.72, 0.22) if owner == "player_1" else Color(0.30, 0.72, 0.95)
	var location: Dictionary = state.get("location", {})
	var location_type := str(location.get("type", "board"))
	var holder := str(state.get("holder_id", location.get("player_id", "")))

	var body := BASIC_CYLINDER_SCENE.instantiate() as BgoBasicCylinderPiece
	body.configure(id, owner, holder, quantity, color)
	body.set_meta("cell", cell)
	body.set_meta("location_type", location_type)
	body.position = _target_world_position(id, state, cell)
	$Pieces.add_child(body)
	pieces[id] = body
	logger.info("PIECE_CREATED", {"piece_id": id, "component": "bgo.piece.basic_cylinder", "location_type": location_type, "position": _vec3_payload(body.position)})

func _hand_world_position(holder: String, piece_id: String) -> Vector3:
	var slot := _hand_slot_index(holder, piece_id)
	var area: BgoPlayerArea = $Player2Area if holder == "player_2" else $Player1Area
	if area != null:
		return area.hand_slot_world(slot)
	return super._hand_world_position(holder, piece_id)

func _cell_world(cell: Vector2i) -> Vector3:
	var board := $Board as BgoCheckeredBoard
	if board != null:
		return board.cell_world(cell)
	return super._cell_world(cell)

func _create_hud() -> void:
	super._create_hud()
	if client_role != ROLE_PLAYER or _player_controls == null:
		return
	call_deferred("_apply_landscape_player_layout")

func _apply_landscape_player_layout() -> void:
	if _player_controls == null:
		return

	# Narrow right-side command rail: it preserves horizontal table space on phones.
	_player_controls.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_player_controls.offset_left = -310.0
	_player_controls.offset_right = -12.0
	_player_controls.offset_top = 14.0
	_player_controls.offset_bottom = -14.0

	var old_column := _player_controls.get_child(0) as VBoxContainer
	if old_column == null:
		return

	# Rebuild the panel as two vertical columns: hand/object strip + action rail.
	var hand_title: Control = old_column.get_child(0) if old_column.get_child_count() > 0 else null
	var hand_scroll: Control = old_column.get_child(1) if old_column.get_child_count() > 1 else null
	var old_bar: Control = _pickup_button.get_parent() if _pickup_button != null else null

	if hand_title != null:
		old_column.remove_child(hand_title)
	if hand_scroll != null:
		old_column.remove_child(hand_scroll)
	if _pickup_button != null and old_bar != null:
		old_bar.remove_child(_pickup_button)
	if _place_button != null and old_bar != null:
		old_bar.remove_child(_place_button)
	old_column.queue_free()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	_player_controls.add_child(columns)

	var hand_column := VBoxContainer.new()
	hand_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_column.add_theme_constant_override("separation", 6)
	columns.add_child(hand_column)
	if hand_title != null:
		hand_title.custom_minimum_size = Vector2(170, 32)
		hand_column.add_child(hand_title)
	if hand_scroll != null:
		hand_scroll.custom_minimum_size = Vector2(170, 0)
		hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hand_column.add_child(hand_scroll)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(108, 0)
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.add_theme_constant_override("separation", 10)
	columns.add_child(action_column)
	if _pickup_button != null:
		_pickup_button.custom_minimum_size = Vector2(106, 64)
		action_column.add_child(_pickup_button)
	if _place_button != null:
		_place_button.custom_minimum_size = Vector2(106, 64)
		action_column.add_child(_place_button)

	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULL\nSCREEN"
	fullscreen_button.custom_minimum_size = Vector2(106, 58)
	fullscreen_button.pressed.connect(_enter_web_fullscreen)
	action_column.add_child(fullscreen_button)

	# The textual mode/debug lines are useful on desktop but expensive on a phone.
	if _mode_label != null:
		_mode_label.visible = false
	if _debug_label != null:
		_debug_label.visible = false

func _request_landscape_orientation() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.documentElement.style.background='#05070a'; document.body.style.margin='0'; document.body.style.overflow='hidden';", true)

func _enter_web_fullscreen() -> void:
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# Browsers require fullscreen/orientation lock to originate from a user gesture.
	JavaScriptBridge.eval("(async()=>{try{const e=document.documentElement;if(e.requestFullscreen)await e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)await screen.orientation.lock('landscape');}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();", true)
