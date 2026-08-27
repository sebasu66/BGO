@tool
class_name BgoSlotLayout
extends BgoFeature

enum LayoutMode { ROW, COLUMN, GRID, STAGGERED_GRID }

@export var mode := LayoutMode.GRID
@export_range(1, 50, 1) var rows := 2
@export_range(1, 50, 1) var columns := 2
@export var slot_size := Vector2(1.0, 1.0)
@export var gap := Vector2(0.1, 0.1)
@export_range(-1.0, 1.0, 0.05) var stagger_fraction := 0.5
@export_range(1, 1000, 1) var slot_capacity := 1
@export var accepted_kinds: PackedStringArray = []


func _init() -> void:
	feature_id = &"slot_layout"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"layout_rows": {"type": "int", "min": 1, "default": rows},
		"layout_columns": {"type": "int", "min": 1, "default": columns},
		"layout_gap_x": {"type": "float", "min": 0.0, "default": gap.x},
		"layout_gap_z": {"type": "float", "min": 0.0, "default": gap.y},
		"layout_stagger": {"type": "float", "min": -1.0, "max": 1.0, "default": stagger_fraction},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("bgo_generated_slot"):
			child.free()
	var actual_rows := maxi(int(definition_value(&"layout_rows", rows)), 1)
	var actual_columns := maxi(int(definition_value(&"layout_columns", columns)), 1)
	if mode == LayoutMode.ROW:
		actual_rows = 1
	elif mode == LayoutMode.COLUMN:
		actual_columns = 1
	var actual_gap := Vector2(
		maxf(float(definition_value(&"layout_gap_x", gap.x)), 0.0),
		maxf(float(definition_value(&"layout_gap_z", gap.y)), 0.0)
	)
	var step := slot_size + actual_gap
	var total_width := float(actual_columns - 1) * step.x
	var total_depth := float(actual_rows - 1) * step.y
	var stagger := float(definition_value(&"layout_stagger", stagger_fraction))
	for row in actual_rows:
		for column in actual_columns:
			var slot := BgoSlot.new()
			slot.name = "Slot_%d_%d" % [column, row]
			slot.set_meta("bgo_generated_slot", true)
			slot.configure_generated(
				"layout:%d:%d" % [column, row], slot_size, slot_capacity, accepted_kinds
			)
			var offset_x := 0.0
			if mode == LayoutMode.STAGGERED_GRID and row % 2 == 1:
				offset_x = step.x * stagger
			slot.position = Vector3(
				float(column) * step.x - total_width * 0.5 + offset_x,
				0.03,
				float(row) * step.y - total_depth * 0.5
			)
			add_child(slot)


func generated_slots() -> Array[BgoSlot]:
	var result: Array[BgoSlot] = []
	for child in get_children():
		if child is BgoSlot and child.has_meta("bgo_generated_slot"):
			result.append(child as BgoSlot)
	return result
