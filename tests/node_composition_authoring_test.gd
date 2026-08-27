extends GutTest

const ROOT_SCRIPT := preload("res://src/authoring/nodes/bgo_game_object_3d.gd")
const PLANE_SCRIPT := preload("res://src/authoring/nodes/bgo_plane_representation.gd")
const LAYOUT_SCRIPT := preload("res://src/authoring/nodes/bgo_slot_layout.gd")
const BEHAVIOR_SCRIPT := preload("res://src/authoring/nodes/bgo_behavior.gd")
const DEMO_SCENE := preload("res://src/authoring/scenes/node_composition_demo.tscn")


func test_root_merges_child_property_schema() -> void:
	var root := ROOT_SCRIPT.new()
	var plane := PLANE_SCRIPT.new()
	root.add_child(plane)
	root.definition_properties = {"width": 2.0, "height": 3.0}
	var schema: Dictionary = root.get_definition_schema()
	assert_true(schema.has("width"))
	assert_true(schema.has("height"))
	assert_eq(root.get_definition_value(&"width", 0.0), 2.0)
	root.free()


func test_staggered_layout_generates_rectangular_slots() -> void:
	var root := ROOT_SCRIPT.new()
	add_child(root)
	var layout := LAYOUT_SCRIPT.new()
	root.add_child(layout)
	layout.mode = 3
	layout.rows = 2
	layout.columns = 3
	layout.slot_size = Vector2(2.0, 1.0)
	layout.rebuild()
	var slots: Array[Node] = layout.generated_slots()
	assert_eq(slots.size(), 6)
	assert_eq(slots[0].get("size"), Vector2(2.0, 1.0))
	assert_ne((slots[0] as Node3D).position.x, (slots[3] as Node3D).position.x)
	root.free()


func test_behavior_is_authoring_data_only_for_now() -> void:
	var behavior := BEHAVIOR_SCRIPT.new()
	behavior.rules = [
		{"event": "onTake", "actions": [{"target": "Match.variables.alert", "operation": "add", "value": 1}]},
		{"event": "onPlay", "actions": []},
	]
	assert_eq(behavior.matching_rules(&"onTake").size(), 1)
	assert_eq(behavior.matching_rules(&"onDiscard").size(), 0)
	behavior.free()


func test_demo_scene_instantiates() -> void:
	var demo := DEMO_SCENE.instantiate()
	assert_not_null(demo)
	assert_not_null(demo.get_node_or_null("Table/Surface/Slots"))
	assert_not_null(demo.get_node_or_null("Card/Stackable"))
	assert_not_null(demo.get_node_or_null("Raider/Behavior"))
	demo.free()
