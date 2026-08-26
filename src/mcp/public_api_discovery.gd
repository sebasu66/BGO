class_name BgoPublicApiDiscovery
extends RefCounted

const API_VERSION := "0.3.0"
const SCHEMA_VERSION := 1
const GAME_TABLE_INSTANCE_PREFIX := "Game.table.instances."
const OBJECT_PREFIX := "Match.objects."

var session_snapshot: Dictionary = {}
var game_definition: Dictionary = {}
var context: Dictionary = {}


static func create(
	p_session_snapshot: Dictionary, p_game_definition: Dictionary, p_context: Dictionary
) -> BgoPublicApiDiscovery:
	var discovery := BgoPublicApiDiscovery.new()
	discovery.session_snapshot = p_session_snapshot.duplicate(true)
	discovery.game_definition = p_game_definition.duplicate(true)
	discovery.context = p_context.duplicate(true)
	return discovery


## Executes one read-only public API discovery/query operation.
func query(operation: String, arguments: Dictionary = {}) -> Dictionary:
	match operation.strip_edges():
		"", "instructions", "System.instructions":
			return instructions()
		"getEntities", "System.api.getEntities":
			return get_entities(str(arguments.get("detail", "summary")))
		"getMethods", "System.api.getMethods":
			return get_methods(str(arguments.get("entity", "")))
		"describe", "System.api.describe":
			return describe(str(arguments.get("target", arguments.get("entity", ""))))
		"getProperties", "System.api.getProperties":
			return get_properties(str(arguments.get("entity", "")))
		"getView", "Match.getView":
			return get_view(str(arguments.get("detail", "compact")))
		_:
			return _rejected("unsupported_query_operation")


## Returns the minimal bootstrap instructions a new LLM needs to navigate BGO.
func instructions() -> Dictionary:
	return _envelope(
		{
			"kind": "instructions",
			"canonical": "System.instructions",
			"summary": "Discover and operate BGO through Game, Match, and System without engine-level knowledge.",
			"roots": [
				{
					"name": "Game",
					"responsibility": "Declarative game definition and component configuration/authoring.",
				},
				{
					"name": "Match",
					"responsibility": "Current session state, visible objects, turns, and gameplay actions.",
				},
				{
					"name": "System",
					"responsibility": "API discovery plus runtime/environment/system capabilities when exposed.",
				},
			],
			"recommended_flow": [
				"Call System.instructions once.",
				"Call System.api.getEntities to discover stable logical entities.",
				"Call System.api.getMethods for the entity you intend to use.",
				"Call System.api.describe before an unfamiliar mutation.",
				"Use Match.getView for a compact player-like view of the table.",
				"Mutate only through bgo_set_properties or bgo_execute using the documented examples.",
			],
			"query_transport": {
				"tool": "bgo_query",
				"arguments": {"operation": "describe", "target": "Game.table.instances.main_board"},
			},
			"examples": [
				{
					"goal": "Inspect the main board",
					"call": {
						"tool": "bgo_query",
						"arguments": {"operation": "getProperties", "entity": "Game.table.instances.main_board"},
					},
				},
				{
					"goal": "Change a 6-row board to 8 rows while preserving other configuration",
					"call": {
						"tool": "bgo_set_properties",
						"arguments": {
							"entity": "Game.table.instances.main_board",
							"changes": {"configuration": {"rows": 8}},
						},
					},
				},
				{
					"goal": "Move one visible piece",
					"call": {
						"tool": "bgo_execute",
						"arguments": {
							"entity": "Match.objects.player_1_piece",
							"command": "moveToPoint",
							"arguments": {"x": 3, "y": 1},
						},
					},
				},
			],
		}
	)


## Lists logical entities using compact, deterministic descriptors.
func get_entities(detail: String = "summary") -> Dictionary:
	var entities: Array[Dictionary] = [
		_entity("Game.definition", "game_definition", "Declarative definition of the loaded game.", false),
		_entity("Match", "match", "Current session and gameplay command root.", false),
		_entity("Match.table", "table", "Logical tabletop/grid view.", false),
		_entity("System.api", "system_api", "Discovery and description surface for the public API.", false),
	]
	for instance_variant in _table_instances():
		if not instance_variant is Dictionary:
			continue
		var instance: Dictionary = instance_variant
		var instance_id := str(instance.get("id", ""))
		if instance_id.is_empty():
			continue
		var component_id := str(instance.get("component", ""))
		var contract := BgoComponentRegistry.get_contract(component_id)
		entities.append(
			_entity(
				GAME_TABLE_INSTANCE_PREFIX + instance_id,
				str(contract.get("kind", "table_component")),
				str(contract.get("description", "Declarative table component instance.")),
				_is_host()
			)
		)
	for object_id_variant in _visible_pieces():
		var object_id := str(object_id_variant)
		var piece: Dictionary = _visible_pieces()[object_id_variant]
		var component_id := str(piece.get("component_id", ""))
		var contract := BgoComponentRegistry.get_contract(component_id)
		entities.append(
			_entity(
				OBJECT_PREFIX + object_id,
				str(contract.get("kind", "game_object")),
				str(contract.get("description", "Visible logical game object.")),
				_can_edit_piece(piece)
			)
		)
	entities.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("entity", "")) < str(right.get("entity", ""))
	)
	if detail == "full":
		for index in entities.size():
			entities[index]["methods"] = (get_methods(str(entities[index]["entity"])).get("methods", []) as Array).duplicate(true)
	return _envelope({"kind": "entity_list", "entities": entities})


## Returns structured method descriptors and examples for one entity.
func get_methods(entity: String) -> Dictionary:
	if entity.is_empty():
		return _rejected("entity_required")
	var methods: Array[Dictionary] = []
	if entity == "System.api":
		methods = [
			_query_method("System.instructions", "Explain the BGO roots and recommended LLM workflow.", "instructions", {}),
			_query_method("System.api.getEntities", "List stable logical entities.", "getEntities", {}),
			_query_method("System.api.getMethods", "List methods available for one entity.", "getMethods", {"entity": "Game.table.instances.main_board"}),
			_query_method("System.api.describe", "Describe an entity, method, or configuration property.", "describe", {"target": "Game.table.instances.main_board.configuration.rows"}),
			_query_method("System.api.getProperties", "Read the current logical properties of one entity.", "getProperties", {"entity": "Game.table.instances.main_board"}),
		]
	elif entity == "Match":
		methods = [
			_query_method("Match.getView", "Return a compact player-like projection of the current match.", "getView", {"detail": "compact"}),
			_query_method("Match.getProperties", "Read compact match/session properties.", "getProperties", {"entity": "Match"}),
		]
		if _is_host():
			methods.append(_execute_method(entity, "createObjectAtPoint", "Create a validated sandbox object at a logical grid point.", {"catalogId": "basic-miniature", "objectId": "new-piece", "x": 2, "y": 2}))
	elif entity == "Match.table":
		methods = [
			_query_method("Match.table.getProperties", "Read table and board dimensions visible to the caller.", "getProperties", {"entity": entity}),
			_execute_method(entity, "objectsAtPoint", "Return visible object IDs covering one logical point.", {"x": 2, "y": 2}, true),
		]
	elif entity == "Game.definition":
		methods = [_query_method("Game.definition.getProperties", "Read the declarative game definition.", "getProperties", {"entity": entity})]
	elif entity.begins_with(GAME_TABLE_INSTANCE_PREFIX):
		methods = [_query_method(entity + ".getProperties", "Read component identity, configuration, placement, and schema.", "getProperties", {"entity": entity})]
		if _is_host():
			methods.append(_set_properties_method(entity, "Change only manifest-declared configuration properties."))
	elif entity.begins_with(OBJECT_PREFIX) and _visible_pieces().has(entity.trim_prefix(OBJECT_PREFIX)):
		methods = [_query_method(entity + ".getProperties", "Read the curated logical state of this visible object.", "getProperties", {"entity": entity})]
		var piece: Dictionary = _visible_pieces()[entity.trim_prefix(OBJECT_PREFIX)]
		if _can_edit_piece(piece):
			methods.append(_set_properties_method(entity, "Change validated configuration/visibility properties without moving the object."))
			methods.append(_execute_method(entity, "moveToPoint", "Move this object to a logical grid point.", {"x": 3, "y": 1}))
		if _is_host():
			methods.append(_execute_method(entity, "changeOwner", "Change this object's logical owner.", {"ownerId": "player_2"}))
	else:
		return _rejected("unknown_or_hidden_entity")
	return _envelope({"kind": "method_list", "entity": entity, "methods": methods})


## Describes a root, entity, method, or manifest-declared configuration property.
func describe(target: String) -> Dictionary:
	if target.is_empty():
		return _rejected("target_required")
	if target in ["Game", "Match", "System"]:
		return _describe_root(target)
	if target == "System.instructions":
		return _envelope({"kind": "method", "descriptor": _query_method("System.instructions", "Explain the BGO roots and recommended LLM workflow.", "instructions", {})})
	var property_result := _describe_configuration_property(target)
	if bool(property_result.get("ok", false)):
		return property_result
	var entities: Array = get_entities().get("entities", [])
	for entity_variant in entities:
		var entity: Dictionary = entity_variant
		var entity_name := str(entity.get("entity", ""))
		if target == entity_name:
			var properties := get_properties(entity_name)
			var methods := get_methods(entity_name)
			return _envelope({
				"kind": "entity",
				"entity": entity,
				"properties": properties.get("properties", {}),
				"schema": properties.get("schema", {}),
				"methods": methods.get("methods", []),
			})
		var methods_result := get_methods(entity_name)
		for method_variant in methods_result.get("methods", []):
			var method: Dictionary = method_variant
			if str(method.get("canonical", "")) == target:
				return _envelope({"kind": "method", "descriptor": method})
	return _rejected("unknown_target")


## Reads current logical properties without exposing raw Godot scene state.
func get_properties(entity: String) -> Dictionary:
	if entity == "System.api":
		return _envelope({"kind": "properties", "entity": entity, "properties": {"apiVersion": API_VERSION, "roots": ["Game", "Match", "System"]}, "schema": {}})
	if entity == "Game.definition":
		return _envelope({"kind": "properties", "entity": entity, "properties": game_definition.duplicate(true), "schema": {}})
	if entity == "Match":
		return _envelope({"kind": "properties", "entity": entity, "properties": _match_summary(), "schema": {}})
	if entity == "Match.table":
		return _envelope({"kind": "properties", "entity": entity, "properties": _table_view(), "schema": {}})
	var instance := _table_instance(entity)
	if not instance.is_empty():
		var definition: Dictionary = instance.get("definition", {})
		var component_id := str(definition.get("component", ""))
		return _envelope({
			"kind": "properties",
			"entity": entity,
			"properties": {
				"componentId": component_id,
				"configuration": (definition.get("config", {}) as Dictionary).duplicate(true),
				"placement": (definition.get("placement", {}) as Dictionary).duplicate(true),
			},
			"schema": _instance_schema(component_id),
		})
	if entity.begins_with(OBJECT_PREFIX):
		var object_id := entity.trim_prefix(OBJECT_PREFIX)
		var pieces := _visible_pieces()
		if not pieces.has(object_id):
			return _rejected("unknown_or_hidden_entity")
		var piece: Dictionary = pieces[object_id]
		var component_id := str(piece.get("component_id", ""))
		return _envelope({
			"kind": "properties",
			"entity": entity,
			"properties": _piece_view(object_id, piece, true),
			"schema": {
				"configuration": {
					"type": "object",
					"writable": _can_edit_piece(piece),
					"properties": _config_schema(component_id),
				},
			},
		})
	return _rejected("unknown_or_hidden_entity")


## Returns a compact semantic view approximating what an authorized player sees.
func get_view(detail: String = "compact") -> Dictionary:
	var objects: Array[Dictionary] = []
	var pieces := _visible_pieces()
	var ids: Array[String] = []
	for object_id in pieces:
		ids.append(str(object_id))
	ids.sort()
	for object_id in ids:
		objects.append(_piece_view(object_id, pieces[object_id], detail == "full"))
	return _envelope({
		"kind": "match_view",
		"detail": detail,
		"match": _match_summary(),
		"table": _table_view(),
		"objects": objects,
	})


func _entity(entity: String, kind: String, description: String, writable: bool) -> Dictionary:
	return {"entity": entity, "kind": kind, "description": description, "writable": writable}


func _query_method(
	canonical: String, description: String, operation: String, arguments: Dictionary
) -> Dictionary:
	var query_arguments := arguments.duplicate(true)
	query_arguments["operation"] = operation
	return {
		"canonical": canonical,
		"description": description,
		"read_only": true,
		"authority": "visible_to_caller",
		"parameters": _query_parameter_schema(operation),
		"returns": "JSON-serializable logical projection",
		"example": {"tool": "bgo_query", "arguments": query_arguments},
	}


func _set_properties_method(entity: String, description: String) -> Dictionary:
	return {
		"canonical": entity + ".setProperties",
		"description": description,
		"read_only": false,
		"authority": "host" if entity.begins_with(GAME_TABLE_INSTANCE_PREFIX) else "owner_or_host",
		"parameters": {"changes": {"type": "object", "required": true, "description": "Only properties marked writable by getProperties."}},
		"returns": "Updated logical properties plus event/result metadata.",
		"example": {
			"tool": "bgo_set_properties",
			"arguments": {"entity": entity, "changes": {"configuration": {"rows": 8}}},
		},
	}


func _execute_method(
	entity: String, command: String, description: String, arguments: Dictionary, read_only: bool = false
) -> Dictionary:
	return {
		"canonical": entity + "." + command,
		"description": description,
		"read_only": read_only,
		"authority": "visible_to_caller" if read_only else "host_or_authorized_controller",
		"parameters": _argument_schema(arguments),
		"returns": "Structured command result.",
		"example": {
			"tool": "bgo_execute",
			"arguments": {"entity": entity, "command": command, "arguments": arguments.duplicate(true)},
		},
	}


func _query_parameter_schema(operation: String) -> Dictionary:
	match operation:
		"getMethods":
			return {"entity": {"type": "string", "required": true}}
		"describe":
			return {"target": {"type": "string", "required": true}}
		"getProperties":
			return {"entity": {"type": "string", "required": true}}
		"getView":
			return {"detail": {"type": "enum", "values": ["compact", "full"], "default": "compact"}}
	return {}


func _argument_schema(example_arguments: Dictionary) -> Dictionary:
	var schema := {}
	for key in example_arguments:
		var value: Variant = example_arguments[key]
		schema[str(key)] = {"type": type_string(typeof(value)), "required": true, "example": value}
	return schema


func _describe_root(root: String) -> Dictionary:
	var descriptions := {
		"Game": "Declarative game definition, components, setup, and authoring.",
		"Match": "Live session state and gameplay actions.",
		"System": "Discovery plus runtime/environment/system capabilities.",
	}
	return _envelope({"kind": "root", "canonical": root, "description": descriptions[root]})


func _describe_configuration_property(target: String) -> Dictionary:
	var marker := ".configuration."
	var marker_index := target.find(marker)
	if marker_index < 0:
		return _rejected("not_configuration_property")
	var entity := target.substr(0, marker_index)
	var property_name := target.substr(marker_index + marker.length())
	var component_id := ""
	var current_config: Dictionary = {}
	var instance := _table_instance(entity)
	if not instance.is_empty():
		var definition: Dictionary = instance.get("definition", {})
		component_id = str(definition.get("component", ""))
		current_config = (definition.get("config", {}) as Dictionary).duplicate(true)
	elif entity.begins_with(OBJECT_PREFIX):
		var object_id := entity.trim_prefix(OBJECT_PREFIX)
		var pieces := _visible_pieces()
		if pieces.has(object_id):
			var piece: Dictionary = pieces[object_id]
			component_id = str(piece.get("component_id", ""))
			current_config = (piece.get("object_config", {}) as Dictionary).duplicate(true)
	if component_id.is_empty():
		return _rejected("unknown_or_hidden_entity")
	var descriptor: Dictionary = _config_schema(component_id).get(property_name, {})
	if descriptor.is_empty():
		return _rejected("unknown_configuration_property")
	return _envelope({
		"kind": "property",
		"canonical": target,
		"componentId": component_id,
		"description": str(descriptor.get("description", "Manifest-declared component configuration property.")),
		"schema": descriptor,
		"current_value": current_config.get(property_name, descriptor.get("default")),
		"example": {
			"tool": "bgo_set_properties",
			"arguments": {"entity": entity, "changes": {"configuration": {property_name: descriptor.get("example", descriptor.get("default"))}}},
		},
	})


func _instance_schema(component_id: String) -> Dictionary:
	return {
		"componentId": {"type": "string", "writable": false},
		"configuration": {
			"type": "object",
			"writable": _is_host(),
			"properties": _config_schema(component_id),
		},
		"placement": {"type": "object", "writable": false},
	}


func _config_schema(component_id: String) -> Dictionary:
	var contract := BgoComponentRegistry.get_contract(component_id)
	var raw: Dictionary = contract.get("config", {})
	var result := raw.duplicate(true)
	for key in result:
		var descriptor: Dictionary = result[key]
		descriptor["writable"] = _is_host()
		if not descriptor.has("description"):
			descriptor["description"] = "Configuration property '%s' for %s." % [str(key), component_id]
		if not descriptor.has("example") and descriptor.has("default"):
			descriptor["example"] = descriptor["default"]
		result[key] = descriptor
	return result


func _table_instances() -> Array:
	var table: Dictionary = game_definition.get("table", {})
	var instances: Variant = table.get("instances", [])
	return instances if instances is Array else []


func _table_instance(entity: String) -> Dictionary:
	if not entity.begins_with(GAME_TABLE_INSTANCE_PREFIX):
		return {}
	var requested_id := entity.trim_prefix(GAME_TABLE_INSTANCE_PREFIX)
	for index in _table_instances().size():
		var candidate: Variant = _table_instances()[index]
		if candidate is Dictionary and str(candidate.get("id", "")) == requested_id:
			return {"index": index, "definition": candidate}
	return {}


func _visible_pieces() -> Dictionary:
	var pieces: Dictionary = session_snapshot.get("pieces", {})
	var visible := {}
	for object_id in pieces:
		var value: Variant = pieces[object_id]
		if value is Dictionary and _can_view_piece(value):
			visible[object_id] = value
	return visible


func _can_view_piece(piece: Dictionary) -> bool:
	if _is_host() or str(piece.get("visibility", "public")) == "public":
		return true
	var participant_id := str(context.get("participant_id", ""))
	return str(piece.get("owner_id", "")) == participant_id or str(piece.get("holder_id", "")) == participant_id


func _can_edit_piece(piece: Dictionary) -> bool:
	if _is_host():
		return true
	var participant_id := str(context.get("participant_id", ""))
	return str(piece.get("owner_id", "")) == participant_id or str(piece.get("holder_id", "")) == participant_id


func _is_host() -> bool:
	return str(context.get("role", "")) == "host"


func _match_summary() -> Dictionary:
	var keys := ["session_id", "lifecycle", "active_participant_id", "turn_number", "phase", "result"]
	var result := {}
	for key in keys:
		if session_snapshot.has(key):
			result[key] = session_snapshot[key]
	if not result.has("session_id"):
		result["session_id"] = str(context.get("session_id", ""))
	return result


func _table_view() -> Dictionary:
	var table: Dictionary = game_definition.get("table", {})
	var result := {
		"width": table.get("width"),
		"depth": table.get("depth"),
		"environment": (table.get("environment", {}) as Dictionary).duplicate(true),
	}
	for instance_variant in _table_instances():
		if not instance_variant is Dictionary:
			continue
		var instance: Dictionary = instance_variant
		var component_id := str(instance.get("component", ""))
		if not component_id.begins_with("bgo.board."):
			continue
		var config: Dictionary = instance.get("config", {})
		result["board"] = {
			"id": str(instance.get("id", "")),
			"component": component_id,
			"columns": config.get("columns"),
			"rows": config.get("rows"),
			"cell_size": config.get("cell_size"),
			"grid_cell_size_cm": config.get("grid_cell_size_cm"),
		}
		break
	return result


func _piece_view(object_id: String, piece: Dictionary, full: bool) -> Dictionary:
	var location: Dictionary = piece.get("location", {})
	var cell: Dictionary = piece.get("cell", {})
	var result := {
		"id": object_id,
		"component": str(piece.get("component_id", "")),
		"kind": BgoComponentRegistry.get_kind(str(piece.get("component_id", ""))),
		"owner": str(piece.get("owner_id", "")),
		"holder": str(piece.get("holder_id", "")),
		"visibility": str(piece.get("visibility", "public")),
		"quantity": int(piece.get("quantity", 1)),
		"location": {
			"type": str(location.get("type", "slot")),
			"id": str(location.get("slot_id", location.get("player_id", location.get("box_id", "")))),
			"cell": {"x": int(cell.get("x", -1)), "y": int(cell.get("y", -1))},
		},
	}
	var config: Dictionary = piece.get("object_config", {})
	var visible_config := _agent_visible_config(str(piece.get("component_id", "")), config)
	if not visible_config.is_empty():
		result["appearance"] = visible_config
	if full:
		result["configuration"] = config.duplicate(true)
	return result


func _agent_visible_config(component_id: String, config: Dictionary) -> Dictionary:
	var schema := _config_schema(component_id)
	var result := {}
	for key in config:
		var descriptor: Dictionary = schema.get(key, {})
		if bool(descriptor.get("agent_visible", false)):
			result[key] = config[key]
	return result


func _envelope(payload: Dictionary) -> Dictionary:
	var result := {
		"ok": true,
		"schema_version": SCHEMA_VERSION,
		"api_version": API_VERSION,
	}
	result.merge(payload, true)
	return result


func _rejected(reason: String) -> Dictionary:
	return {
		"ok": false,
		"schema_version": SCHEMA_VERSION,
		"api_version": API_VERSION,
		"reason": reason,
	}
