class_name ConsoleCommandTestObject
extends BGOGameObject

var test_value := 0
var test_name := "Console fixture"
var test_desc := "Console API fixture"
var test_width := 10
var test_active := true


func set_test_value(value: int) -> void:
	test_value = value


func _api_get_name() -> String:
	return test_name


func _api_set_name(value: String) -> void:
	test_name = value


func _api_get_desc() -> String:
	return test_desc


func _api_set_desc(value: String) -> void:
	test_desc = value


func _api_get_width() -> int:
	return test_width


func _api_set_width(value: int) -> void:
	test_width = value


func _api_is_active() -> bool:
	return test_active


func console_api() -> Dictionary:
	return {
		"scope": "Match",
		"entity": entity_id,
		"class": "ConsoleCommandTestObject",
		"description": "Intentional flat API fixture.",
		"methods":
		{
			"getName":
			{
				"call": "_api_get_name",
				"returns": "String",
				"description": "Returns the entity name.",
			},
			"setName":
			{
				"call": "_api_set_name",
				"args": [{"name": "value", "type": TYPE_STRING}],
				"returns": "void",
				"description": "Sets the entity name.",
			},
			"getDesc":
			{
				"call": "_api_get_desc",
				"returns": "String",
				"description": "Returns the entity description.",
			},
			"setDesc":
			{
				"call": "_api_set_desc",
				"args": [{"name": "value", "type": TYPE_STRING}],
				"returns": "void",
				"description": "Sets the entity description.",
			},
			"getWidth":
			{
				"call": "_api_get_width",
				"returns": "int",
				"description": "Returns the entity width.",
			},
			"setWidth":
			{
				"call": "_api_set_width",
				"args": [{"name": "value", "type": TYPE_INT}],
				"returns": "void",
				"description": "Sets the entity width.",
			},
			"isActive":
			{
				"call": "_api_is_active",
				"returns": "bool",
				"description": "Returns whether the entity is active.",
			},
		},
	}


func console_help() -> Dictionary:
	return {
		"_summary": "Fixture used to verify dynamic console command discovery.",
		"set_test_value": "Sets an integer value through the developer console.",
	}
