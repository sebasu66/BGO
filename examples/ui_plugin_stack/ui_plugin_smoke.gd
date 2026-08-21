class_name BgoUiPluginSmoke
extends RefCounted
## AUTO-GENERATED from ui_plugin_smoke.guitkx -- do not edit.

const __RUI_DECLS := {
	"BgoUiPluginSmoke": { "kind": "component", "sig": "", "export": true },
}

const __RUI_KIND := "mixed"

const __RUI_HOOK_SIG := ""

# component BgoUiPluginSmoke
static func render(props: Dictionary, children: Array) -> RUIVNode:
	var message = props.get("message", "Reactive UI Editor OK")
	return V.VBoxContainer({ "style": {"separation": 6} }, [V.Label({ "text": message }), V.Button({ "text": "Smoke action", "disabled": true })])

