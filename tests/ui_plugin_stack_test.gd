extends RefCounted

const GENERATED_COMPONENT = preload(
	"res://examples/ui_plugin_stack/ui_plugin_smoke.gd"
)


static func run(check: Callable) -> void:
	var spark_value := S.int(2)
	spark_value.value = 7
	check.call(spark_value.peek() == 7, "Spark reactive state updates")

	var vnode: RUIVNode = GENERATED_COMPONENT.render(
		{"message": "Reactive UI Editor OK"},
		[],
	)
	check.call(vnode.type == "VBoxContainer", "Reactive UI generates a container vnode")
	check.call(vnode.children.size() == 2, "Reactive UI generates declared children")
	check.call(
		str(vnode.children[0].props.get("text", "")) == "Reactive UI Editor OK",
		"Reactive UI preserves declared props",
	)

	GDSS.set_global_var("bgo_smoke", "GDSS OK")
	check.call(
		GDSS.get_global_var("bgo_smoke", "") == "GDSS OK",
		"GDSS global variables round-trip",
	)
	GDSS.reset_global_var("bgo_smoke")

	check.call(
		ClassDB.class_exists(&"GdscriptAnalyzer"),
		"Reactive UI native analyzer is loaded",
	)
	var root := (Engine.get_main_loop() as SceneTree).root
	check.call(root.get_node_or_null("GodotxToast") != null, "GodotX Toast autoload is active")
