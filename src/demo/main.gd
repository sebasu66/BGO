extends Node2D

const GRID_ORIGIN := Vector2(320, 120)
const CELL_SIZE := Vector2(80, 80)
const GRID_COLUMNS := 8
const GRID_ROWS := 6

var selected_token: DemoTokenView
var tokens: Array[DemoTokenView] = []

func _ready() -> void:
	_create_demo_tokens()
	queue_redraw()

func _draw() -> void:
	for y in GRID_ROWS:
		for x in GRID_COLUMNS:
			var rect := Rect2(GRID_ORIGIN + Vector2(x, y) * CELL_SIZE, CELL_SIZE)
			var fill := Color(0.18, 0.2, 0.24) if (x + y) % 2 == 0 else Color(0.14, 0.16, 0.2)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.32, 0.35, 0.4), false, 1.0)

	draw_string(ThemeDB.fallback_font, Vector2(40, 55), "BGO — Core Prototype", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(40, 88), "Click a token, then click a board cell to move it.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.72, 0.76, 0.84))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_pointer(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_pointer(event.position)

func _handle_pointer(point: Vector2) -> void:
	for token in tokens:
		if token.contains_global_point(point):
			_select_token(token)
			return

	if selected_token != null and _is_inside_board(point):
		var movable := selected_token.get_component(&"movable") as MovableComponent
		if movable != null:
			movable.request_move(_cell_center_from_point(point))

func _select_token(token: DemoTokenView) -> void:
	if selected_token != null:
		selected_token.set_selected(false)
	selected_token = token
	selected_token.set_selected(true)

func _create_demo_tokens() -> void:
	_create_token("player_1_piece", "player_1", 1, Vector2i(1, 2), Color(0.95, 0.72, 0.22))
	_create_token("player_2_stack", "player_2", 3, Vector2i(6, 3), Color(0.3, 0.72, 0.95))

func _create_token(id: String, owner: String, count: int, cell: Vector2i, color: Color) -> void:
	var token := DemoTokenView.new()
	token.entity_id = id
	token.owner_id = owner
	token.quantity = count
	token.token_color = color
	token.position = _cell_center(cell)
	add_child(token)

	var movable := MovableComponent.new()
	movable.snap_size = CELL_SIZE
	token.add_component(&"movable", movable)
	movable.move_requested.connect(_on_move_requested.bind(movable))

	tokens.append(token)

func _on_move_requested(_entity: BGOGameObject, target_position: Vector2, movable: MovableComponent) -> void:
	# Prototype authority boundary. Networking/rules can intercept here later.
	movable.apply_move(target_position)

func _cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * CELL_SIZE + CELL_SIZE * 0.5

func _cell_center_from_point(point: Vector2) -> Vector2:
	var local := point - GRID_ORIGIN
	var cell := Vector2i(floor(local.x / CELL_SIZE.x), floor(local.y / CELL_SIZE.y))
	return _cell_center(cell)

func _is_inside_board(point: Vector2) -> bool:
	return Rect2(GRID_ORIGIN, Vector2(GRID_COLUMNS, GRID_ROWS) * CELL_SIZE).has_point(point)
