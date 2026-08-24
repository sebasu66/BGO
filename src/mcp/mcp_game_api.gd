class_name BgoMcpGameApi
extends RefCounted
# gdlint: disable=max-returns

## Transport-neutral logical API shared by future MCP and other adapters.
## It never reads render nodes and never writes Firebase directly.

var gameplay: GameplayState
var game_definition: Dictionary = {}

const ENTITY_GAME := "Game.definition"
const ENTITY_MATCH := "Match"
const ENTITY_TABLE := "Match.table"
const ENTITY_SYSTEM := "System.api"
const OBJECT_PREFIX := "Match.objects."

const OBJECT_PROPERTY_SCHEMA := {
	"componentId": {"type": "string", "writable": false},
	"configuration": {"type": "object", "writable": true, "authority": "owner"},
	"quantity": {"type": "integer", "minimum": 1, "writable": true, "authority": "host"},
	"availability": {"type": "string", "writable": false},
	"availableQuantity": {"type": "integer", "writable": false},
	"ownerId": {"type": "string", "writable": true, "authority": "host"},
	"holderId": {"type": "string", "writable": false},
	"visibility": {
		"type": "string",
		"enum": ["public", "owner_only"],
		"writable": true,
		"authority": "owner",
	},
	"location": {"type": "object", "writable": false},
}


static func create(p_gameplay: GameplayState, p_game_definition: Dictionary) -> RefCounted:
	var api = new()
	api.gameplay = p_gameplay
	api.game_definition = p_game_definition.duplicate(true)
	return api


func get_definition(_context: Dictionary) -> Dictionary:
	return {"ok": true, "definition": game_definition.duplicate(true)}


## Lists the logical entities visible to this caller and their declared commands.
func get_entities(context: Dictionary) -> Dictionary:
	if gameplay == null:
		return _rejected("gameplay_unavailable")
	var entities: Array[Dictionary] = [
		_entity_summary(ENTITY_GAME, "GameDefinition", [], false),
		_entity_summary(ENTITY_MATCH, "Match", ["createObjectAtPoint"], false),
		_entity_summary(ENTITY_TABLE, "Table", ["objectsAtPoint"], false),
		_entity_summary(ENTITY_SYSTEM, "SystemApi", [], false),
	]
	for object_id_variant in gameplay.objects:
		var object: LogicalObjectState = gameplay.objects[object_id_variant]
		if object == null or not _can_view_object(context, object):
			continue
		entities.append(
			_entity_summary(
				OBJECT_PREFIX + str(object_id_variant),
				"GameObject",
				_object_commands(context, object),
				_can_edit_object(context, object)
			)
		)
	entities.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("entity", "")) < str(right.get("entity", ""))
	)
	return {"ok": true, "entities": entities}


## Returns an authorized property snapshot plus its predictable writable schema.
func get_properties(context: Dictionary, entity: String) -> Dictionary:
	if entity == ENTITY_GAME:
		return {
			"ok": true,
			"entity": entity,
			"properties": game_definition.duplicate(true),
			"schema": {},
		}
	if entity == ENTITY_MATCH:
		var state_result := get_state(context)
		return {
			"ok": bool(state_result.get("ok", false)),
			"entity": entity,
			"properties": state_result.get("state", {}),
			"schema": {},
			"commands": ["createObjectAtPoint"] if _is_host(context) else [],
		}
	if entity == ENTITY_TABLE:
		var grid_result := get_grid_state(context)
		grid_result["entity"] = entity
		grid_result["properties"] = {
			"grid": grid_result.get("grid", {}), "objects": grid_result.get("objects", [])
		}
		grid_result["schema"] = {}
		grid_result.erase("grid")
		grid_result.erase("objects")
		return grid_result
	if entity == ENTITY_SYSTEM:
		return {
			"ok": true,
			"entity": entity,
			"properties": {
				"apiVersion": "0.2.0",
				"roots": ["Game", "Match", "System"],
				"tools": ["getEntities", "getProperties", "setProperties", "execute"],
			},
			"schema": {},
			"commands": [],
		}
	var object := _object_from_entity(context, entity)
	if object == null:
		return _rejected("unknown_or_hidden_entity")
	return {
		"ok": true,
		"entity": entity,
		"properties": _object_properties(object),
		"schema": _object_property_schema(context, object),
		"commands": _object_commands(context, object),
	}


## Applies only declared writable properties; movement and lifecycle remain commands.
func set_properties(context: Dictionary, entity: String, changes: Dictionary) -> Dictionary:
	var object := _object_from_entity(context, entity)
	if object == null:
		return _rejected("unknown_or_hidden_entity")
	if changes.is_empty():
		return _rejected("empty_changes")
	var allowed := _writable_property_names(context, object)
	for property_name_variant in changes:
		var property_name := str(property_name_variant)
		if not allowed.has(property_name):
			return _rejected("property_not_writable:%s" % property_name)
	var next_configuration := object.configuration.duplicate(true)
	if changes.has("configuration"):
		if not changes.configuration is Dictionary:
			return _rejected("configuration_must_be_object")
		next_configuration.merge(changes.configuration, true)
		var errors := BgoComponentRegistry.validate_config(object.component_id, next_configuration)
		if not errors.is_empty():
			return {"ok": false, "reason": "invalid_component_config", "errors": errors}
	if changes.has("quantity") and int(changes.quantity) < 1:
		return _rejected("quantity_must_be_positive")
	if changes.has("visibility") and str(changes.visibility) not in ["public", "owner_only"]:
		return _rejected("invalid_visibility")
	if changes.has("configuration"):
		object.configuration = next_configuration
	if changes.has("quantity"):
		object.quantity = int(changes.quantity)
		object.available_quantity = maxi(object.available_quantity, object.quantity)
	if changes.has("ownerId"):
		object.owner_id = str(changes.ownerId)
	if changes.has("visibility"):
		object.visibility = str(changes.visibility)
	return {
		"ok": true,
		"entity": entity,
		"properties": _object_properties(object),
		"event": {
			"type": "entity_properties_changed",
			"object_id": object.object_id,
			"participant_id": str(context.get("participant_id", "")),
			"properties": changes.keys(),
		},
	}


## Executes one command from the entity's declared allowlist.
func execute(context: Dictionary, entity: String, command: String, arguments: Dictionary) -> Dictionary:
	if entity == ENTITY_MATCH and command == "createObjectAtPoint":
		return create_object_at_point(
			context,
			str(arguments.get("catalogId", "")),
			str(arguments.get("objectId", "")),
			int(arguments.get("x", -1)),
			int(arguments.get("y", -1)),
			str(arguments.get("ownerId", "")),
			arguments.get("configuration", {}) as Dictionary,
			int(arguments.get("footprintX", 1)),
			int(arguments.get("footprintY", 1)),
			bool(arguments.get("allowOverlap", false))
		)
	if entity == ENTITY_TABLE and command == "objectsAtPoint":
		return objects_at_point(context, int(arguments.get("x", -1)), int(arguments.get("y", -1)))
	var object := _object_from_entity(context, entity)
	if object == null:
		return _rejected("unknown_or_hidden_entity")
	if not _object_commands(context, object).has(command):
		return _rejected("command_not_allowed")
	match command:
		"moveToPoint":
			return move_object_to_point(
				context,
				object.object_id,
				int(arguments.get("x", -1)),
				int(arguments.get("y", -1)),
				int(arguments.get("footprintX", maxi(object.grid_footprint.x, 1))),
				int(arguments.get("footprintY", maxi(object.grid_footprint.y, 1))),
				bool(arguments.get("allowOverlap", false))
			)
		"changeOwner":
			return set_properties(context, entity, {"ownerId": str(arguments.get("ownerId", ""))})
		_:
			return _rejected("unsupported_entity_command")


func get_state(context: Dictionary) -> Dictionary:
	if gameplay == null:
		return _rejected("gameplay_unavailable")
	return {"ok": true, "state": _filtered_state(context)}


func get_grid_state(context: Dictionary) -> Dictionary:
	if gameplay == null or gameplay.tabletop == null:
		return _rejected("tabletop_unavailable")
	var objects: Array[Dictionary] = []
	for object_id_variant in gameplay.objects:
		var object_id := str(object_id_variant)
		var object: LogicalObjectState = gameplay.objects[object_id_variant]
		if object == null or not _can_view_object(context, object):
			continue
		objects.append(_object_grid_summary(object))
	objects.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("object_id", "")) < str(right.get("object_id", ""))
	)
	return {
		"ok": true,
		"grid": gameplay.tabletop.grid.to_dictionary(),
		"objects": objects,
	}


func inspect_object(context: Dictionary, object_id: String) -> Dictionary:
	if gameplay == null or not gameplay.objects.has(object_id):
		return _rejected("unknown_object")
	var object: LogicalObjectState = gameplay.objects[object_id]
	if object == null or not _can_view_object(context, object):
		return _rejected("not_authorized")
	return {"ok": true, "object": object.to_dictionary()}


func objects_at_point(context: Dictionary, x: int, y: int) -> Dictionary:
	if gameplay == null or gameplay.tabletop == null:
		return _rejected("tabletop_unavailable")
	var point := Vector2i(x, y)
	if not gameplay.tabletop.grid.is_valid_point(point):
		return _rejected("invalid_grid_point")
	var visible_ids: Array[String] = []
	for object_id in gameplay.tabletop.objects_at_grid_point(point):
		var object: LogicalObjectState = gameplay.objects.get(object_id)
		if object != null and _can_view_object(context, object):
			visible_ids.append(object_id)
	return {"ok": true, "point": {"x": x, "y": y}, "object_ids": visible_ids}


func create_object_at_point(
	context: Dictionary,
	catalog_id: String,
	object_id: String,
	x: int,
	y: int,
	owner_id: String = "",
	configuration: Dictionary = {},
	footprint_x: int = 1,
	footprint_y: int = 1,
	allow_overlap: bool = false
) -> Dictionary:
	if not _is_host(context):
		return _rejected("host_required")
	if not _sandbox_enabled():
		return _rejected("sandbox_disabled")
	if gameplay == null or gameplay.tabletop == null:
		return _rejected("gameplay_unavailable")
	if object_id.is_empty() or gameplay.objects.has(object_id):
		return _rejected("invalid_or_duplicate_object_id")
	var catalog_entry := _catalog_entry(catalog_id)
	if catalog_entry.is_empty():
		return _rejected("unknown_catalog_component")
	var component_id := str(catalog_entry.get("component", ""))
	var merged_config: Dictionary = catalog_entry.get("default_config", {}).duplicate(true)
	merged_config.merge(configuration, true)
	var config_errors := BgoComponentRegistry.validate_config(component_id, merged_config)
	if not config_errors.is_empty():
		return {"ok": false, "reason": "invalid_component_config", "errors": config_errors}
	var object := LogicalObjectState.create(object_id, owner_id)
	object.component_id = component_id
	object.configuration = merged_config
	var footprint := Vector2i(footprint_x, footprint_y)
	if not gameplay.add_object_at_grid(object, Vector2i(x, y), footprint, allow_overlap):
		return _rejected("grid_placement_rejected")
	return {
		"ok": true,
		"object": object.to_dictionary(),
		"event":
		{
			"type": "sandbox_object_created",
			"object_id": object_id,
			"component_id": component_id,
			"participant_id": str(context.get("participant_id", "")),
			"origin": {"x": x, "y": y},
		},
	}


func move_object_to_point(
	context: Dictionary,
	object_id: String,
	x: int,
	y: int,
	footprint_x: int = 1,
	footprint_y: int = 1,
	allow_overlap: bool = false
) -> Dictionary:
	if gameplay == null or gameplay.session == null:
		return _rejected("gameplay_unavailable")
	var participant_id := str(context.get("participant_id", ""))
	if _is_host(context):
		if not _sandbox_enabled():
			return _rejected("sandbox_disabled")
		if not gameplay.objects.has(object_id):
			return _rejected("unknown_object")
		var object: LogicalObjectState = gameplay.objects[object_id]
		var origin := Vector2i(x, y)
		var footprint := Vector2i(footprint_x, footprint_y)
		if not gameplay.tabletop.move_object_at_grid(object_id, origin, footprint, allow_overlap):
			return _rejected("table_grid_move_rejected")
		if not object.set_grid_placement(origin, footprint):
			return _rejected("object_grid_placement_rejected")
		return {
			"ok": true,
			"event":
			{
				"type": "sandbox_object_grid_moved",
				"object_id": object_id,
				"participant_id": participant_id,
				"to_origin": {"x": x, "y": y},
				"to_footprint": {"x": footprint_x, "y": footprint_y},
			},
		}
	return gameplay.move_object_at_grid(
		participant_id,
		object_id,
		Vector2i(x, y),
		Vector2i(footprint_x, footprint_y),
		allow_overlap,
		false
	)


func _catalog_entry(catalog_id: String) -> Dictionary:
	var sandbox: Variant = game_definition.get("sandbox", {})
	if not sandbox is Dictionary:
		return {}
	var catalog: Variant = sandbox.get("component_catalog", [])
	if not catalog is Array:
		return {}
	for entry_variant in catalog:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) == catalog_id:
			return entry
	return {}


func _sandbox_enabled() -> bool:
	var sandbox: Variant = game_definition.get("sandbox", {})
	return sandbox is Dictionary and bool(sandbox.get("enabled", false))


func _filtered_state(context: Dictionary) -> Dictionary:
	var snapshot := gameplay.to_dictionary()
	if _is_host(context):
		return snapshot
	var participant_id := str(context.get("participant_id", ""))
	var hands: Dictionary = snapshot.get("hands", {})
	for hand_id in hands.keys():
		if str(hand_id) != participant_id:
			hands.erase(hand_id)
	var objects: Dictionary = snapshot.get("objects", {})
	for object_id in objects.keys():
		var object: LogicalObjectState = gameplay.objects.get(object_id)
		if object == null or not _can_view_object(context, object):
			objects.erase(object_id)
	return snapshot


func _can_view_object(context: Dictionary, object: LogicalObjectState) -> bool:
	if _is_host(context) or object.visibility == "public":
		return true
	var participant_id := str(context.get("participant_id", ""))
	return object.owner_id == participant_id or object.holder_id == participant_id


func _can_edit_object(context: Dictionary, object: LogicalObjectState) -> bool:
	if _is_host(context):
		return true
	var participant_id := str(context.get("participant_id", ""))
	return str(context.get("role", "")) == "player" and (
		object.owner_id == participant_id or object.holder_id == participant_id
	)


func _object_from_entity(context: Dictionary, entity: String) -> LogicalObjectState:
	if not entity.begins_with(OBJECT_PREFIX):
		return null
	var object_id := entity.trim_prefix(OBJECT_PREFIX)
	var object: LogicalObjectState = gameplay.objects.get(object_id) if gameplay != null else null
	return object if object != null and _can_view_object(context, object) else null


func _object_properties(object: LogicalObjectState) -> Dictionary:
	return {
		"componentId": object.component_id,
		"configuration": object.configuration.duplicate(true),
		"quantity": object.quantity,
		"availability": object.availability_mode,
		"availableQuantity": object.available_quantity,
		"ownerId": object.owner_id,
		"holderId": object.holder_id,
		"visibility": object.visibility,
		"location": {
			"type": object.location_type,
			"id": object.location_id,
			"origin": {"x": object.grid_origin.x, "y": object.grid_origin.y},
			"footprint": {"x": object.grid_footprint.x, "y": object.grid_footprint.y},
		},
	}


func _object_property_schema(context: Dictionary, object: LogicalObjectState) -> Dictionary:
	var schema := OBJECT_PROPERTY_SCHEMA.duplicate(true)
	var writable := _writable_property_names(context, object)
	for property_name in schema:
		schema[property_name]["writable"] = writable.has(str(property_name))
	return schema


func _writable_property_names(context: Dictionary, object: LogicalObjectState) -> Array[String]:
	if _is_host(context):
		return ["configuration", "quantity", "ownerId", "visibility"]
	if _can_edit_object(context, object):
		return ["configuration", "visibility"]
	return []


func _object_commands(context: Dictionary, object: LogicalObjectState) -> Array[String]:
	var result: Array[String] = []
	if _can_edit_object(context, object):
		result.append("moveToPoint")
	if _is_host(context):
		result.append("changeOwner")
	return result


func _entity_summary(
	entity: String, entity_class: String, commands: Array[String], writable: bool
) -> Dictionary:
	return {
		"entity": entity,
		"class": entity_class,
		"writable": writable,
		"commands": commands,
	}


func _is_host(context: Dictionary) -> bool:
	if gameplay == null or gameplay.session == null:
		return false
	var participant_id := str(context.get("participant_id", ""))
	return str(context.get("role", "")) == "host" and gameplay.session.is_host(participant_id)


func _object_grid_summary(object: LogicalObjectState) -> Dictionary:
	return {
		"object_id": object.object_id,
		"component_id": object.component_id,
		"owner_id": object.owner_id,
		"location_type": object.location_type,
		"origin": {"x": object.grid_origin.x, "y": object.grid_origin.y},
		"footprint": {"x": object.grid_footprint.x, "y": object.grid_footprint.y},
	}


func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
