extends RefCounted

const COMPONENT_REGISTRY = preload("res://src/core/component_registry.gd")


## Verifies every registered component's curated API and manifest configuration mapping.
static func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for component_id in COMPONENT_REGISTRY.component_ids():
		var contract := COMPONENT_REGISTRY.get_contract(component_id)
		var scene := load(str(contract.get("scene", ""))) as PackedScene
		check.call(scene != null, "%s public API scene loads" % component_id)
		if scene == null:
			continue
		var component := scene.instantiate()
		component.name = component_id.replace(".", "_")
		tree.root.add_child(component)
		await tree.process_frame
		check.call(component.has_method("console_api"), "%s exposes console_api" % component_id)
		if not component.has_method("console_api"):
			component.queue_free()
			continue
		var descriptor: Dictionary = component.call("console_api")
		(
			check
			. call(
				str(descriptor.get("component_id", "")) == component_id,
				"%s API preserves stable component id" % component_id,
			)
		)
		var methods: Dictionary = descriptor.get("methods", {})
		check.call(not methods.is_empty(), "%s API exposes curated methods" % component_id)
		_test_methods(check, component_id, component, methods)
		_test_config_setters(check, component_id, component, contract, methods)
		component.queue_free()
		await tree.process_frame


static func _test_methods(
	check: Callable, component_id: String, component: Node, methods: Dictionary
) -> void:
	for api_name in methods:
		var method: Dictionary = methods[api_name]
		var call_name := str(method.get("call", ""))
		check.call(
			(
				not str(api_name).begins_with("_")
				and "@" not in str(api_name)
				and str(api_name).is_valid_identifier()
			),
			"%s.%s uses a safe explicit API name" % [component_id, api_name]
		)
		(
			check
			. call(
				not call_name.is_empty() and component.has_method(call_name),
				"%s.%s resolves a component method" % [component_id, api_name],
			)
		)
		for argument in method.get("args", []):
			(
				check
				. call(
					argument is Dictionary and (argument as Dictionary).get("type") is int,
					"%s.%s exposes adapter-ready argument types" % [component_id, api_name],
				)
			)


static func _test_config_setters(
	check: Callable,
	component_id: String,
	component: Node,
	contract: Dictionary,
	methods: Dictionary,
) -> void:
	var setters: Dictionary = {}
	for method_value in methods.values():
		if method_value is Dictionary and not str(method_value.get("property", "")).is_empty():
			setters[str(method_value["property"])] = method_value
	var config: Dictionary = contract.get("config", {})
	for property_name in config:
		(
			check
			. call(
				setters.has(property_name),
				"%s maps config.%s to its API" % [component_id, property_name],
			)
		)
		if not setters.has(property_name):
			continue
		var property_contract: Dictionary = config[property_name]
		if str(property_contract.get("type", "")) == "asset":
			continue
		var value: Variant = _config_default(property_contract)
		var setter: Dictionary = setters[property_name]
		var arguments: Array = [value]
		arguments.append_array(setter.get("bound_args", []))
		var result: Variant = component.callv(StringName(setter["call"]), arguments)
		(
			check
			. call(
				result != false,
				"%s applies default config.%s through its API" % [component_id, property_name],
			)
		)


static func _config_default(property_contract: Dictionary) -> Variant:
	var value: Variant = property_contract.get("default")
	match str(property_contract.get("type", "")):
		"vector2":
			if value is Array and value.size() >= 2:
				return Vector2(float(value[0]), float(value[1]))
		"vector3":
			if value is Dictionary:
				return Vector3(
					float(value.get("x", 0.0)),
					float(value.get("y", 0.0)),
					float(value.get("z", 0.0)),
				)
	return value
