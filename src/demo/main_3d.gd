extends Node3D

const GRID_COLUMNS := 8
const GRID_ROWS := 6
const CELL_SIZE := 1.2

@onready var camera: Camera3D = $Camera3D

var selected_piece: Node3D
var pieces: Array[Node3D] = []

func _ready() -> void:
	_create_board()
	_create_piece("player_1_piece", "player_1", 1, Vector2i(1, 2), Color(0.95, 0.72, 0.22))
	_create_piece("player_2_stack", "player_2", 3, Vector2i(6, 3), Color(0.30, 0.72, 0.95))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick_at(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_pick_at(event.position)

func _pick_at(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	if collider != null and collider.has_meta("bgo_piece"):
		_select_piece(collider)
		return

	if selected_piece != null and collider != null and collider.has_meta("board_cell"):
		var cell: Vector2i = collider.get_meta("board_cell")
		_move_selected_to(cell)

func _create_board() -> void:
	for y in GRID_ROWS:
		for x in GRID_COLUMNS:
			var cell := StaticBody3D.new()
			cell.set_meta("board_cell", Vector2i(x, y))
			cell.position = _cell_world(Vector2i(x, y))

			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(CELL_SIZE - 0.03, 0.08, CELL_SIZE - 0.03)
			mesh_instance.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.20, 0.22, 0.25) if (x + y) % 2 == 0 else Color(0.12, 0.14, 0.17)
			material.roughness = 0.78
			mesh_instance.material_override = material
			cell.add_child(mesh_instance)

			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(CELL_SIZE, 0.12, CELL_SIZE)
			shape.shape = box
			cell.add_child(shape)
			$Board.add_child(cell)

func _create_piece(id: String, owner: String, quantity: int, cell: Vector2i, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("bgo_piece", true)
	body.set_meta("entity_id", id)
	body.set_meta("owner_id", owner)
	body.set_meta("quantity", quantity)
	body.set_meta("cell", cell)
	body.position = _cell_world(cell) + Vector3(0, 0.35, 0)

	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.38
	cylinder.bottom_radius = 0.38
	cylinder.height = 0.32
	mesh_instance.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.38
	material.metallic = 0.08
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 0.42
	cylinder_shape.height = 0.38
	shape.shape = cylinder_shape
	body.add_child(shape)

	if quantity > 1:
		var label := Label3D.new()
		label.text = str(quantity)
		label.font_size = 72
		label.position = Vector3(0, 0.28, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)

	$Pieces.add_child(body)
	pieces.append(body)

func _select_piece(piece: Node3D) -> void:
	selected_piece = piece
	for candidate in pieces:
		candidate.scale = Vector3.ONE * (1.14 if candidate == selected_piece else 1.0)

func _move_selected_to(cell: Vector2i) -> void:
	selected_piece.set_meta("cell", cell)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(selected_piece, "position", _cell_world(cell) + Vector3(0, 0.35, 0), 0.22)

func _cell_world(cell: Vector2i) -> Vector3:
	var width := float(GRID_COLUMNS - 1) * CELL_SIZE
	var depth := float(GRID_ROWS - 1) * CELL_SIZE
	return Vector3(float(cell.x) * CELL_SIZE - width * 0.5, 0.0, float(cell.y) * CELL_SIZE - depth * 0.5)
