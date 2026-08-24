class_name BgoDefinitionBuilder
extends RefCounted
# gdlint: disable=function-name

var type_name: String
var values: Dictionary = {}
var children: Dictionary = {}
var warnings: Array[String] = []
var _registry: BgoBuilderRegistry


func _init(builder_type: String, registry: BgoBuilderRegistry) -> void:
	type_name = builder_type
	_registry = registry


func invoke(method_name: String, arguments: Array) -> Dictionary:
	return _registry.invoke(self, method_name, arguments)


func getType() -> String:
	return type_name


func getWarnings() -> Array[String]:
	return warnings.duplicate()


func getDefinition() -> Dictionary:
	return _registry.build(self)


func getJson() -> String:
	return JSON.stringify(getDefinition(), "  ")


func validate() -> Array[String]:
	return BgoGameDefinitionLoader.validate_game(getDefinition())


func isValid() -> bool:
	return validate().is_empty()


func build() -> Dictionary:
	var definition := getDefinition()
	var errors := BgoGameDefinitionLoader.validate_game(definition)
	return {"ok": errors.is_empty(), "data": definition, "errors": errors}


func saveAs(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").simplify_path()
	var games_root := ProjectSettings.globalize_path("res://games").simplify_path()
	var inside_user := absolute.begins_with(user_root + "/")
	var inside_project_games := OS.is_debug_build() and absolute.begins_with(games_root + "/")
	if not inside_user and not inside_project_games:
		return {
			"ok": false,
			"error": "saveAs only accepts user:// or res://games/ paths in DEV.",
		}
	var result := build()
	if not bool(result.get("ok", false)):
		return result
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "error": "Could not create output directory."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not open output file."}
	file.store_string(JSON.stringify(result["data"], "  "))
	return {"ok": true, "path": path, "data": result["data"]}


func migrateToCurrent() -> BgoDefinitionBuilder:
	if type_name == "Game":
		values["schema_version"] = 1
	return self
