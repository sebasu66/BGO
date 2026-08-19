class_name DemoTokenView
extends BGOGameObject

@export var radius: float = 28.0
@export var token_color: Color = Color(0.95, 0.72, 0.22)

var selected := false


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var outline := Color.WHITE if selected else Color(0.1, 0.11, 0.14)
	draw_circle(Vector2.ZERO, radius + 4.0, outline)
	draw_circle(Vector2.ZERO, radius, token_color)
	if quantity > 1:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-8, 6),
			str(quantity),
			HORIZONTAL_ALIGNMENT_CENTER,
			16,
			18,
			Color.BLACK
		)


## Updates the token's selected visual state.
func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


## Returns whether the supplied global point intersects this token.
func contains_global_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius + 8.0
