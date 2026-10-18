class_name TableSurfacePresets
extends RefCounted

## The surface looks a game can ask for by name. Each one is a PBR material
## downloaded from ambientCG (license CC0), stored under assets/ambientcg.

const MATERIAL_BY_PRESET := {
	"marble": "res://assets/ambientcg/Extracted/Marble006_2K-JPG.tres",
	"wood": "res://assets/ambientcg/Extracted/WoodFloor043_2K-JPG.tres",
	"felt": "res://assets/ambientcg/Extracted/Fabric030_1K-JPG.tres",
	"metal": "res://assets/ambientcg/Extracted/Metal032_1K-JPG.tres",
}


## The names a game can use, in a stable order.
static func known_presets() -> Array[String]:
	var names: Array[String] = []
	for preset_name in MATERIAL_BY_PRESET:
		names.append(str(preset_name))
	names.sort()
	return names


static func is_known(preset_name: String) -> bool:
	return MATERIAL_BY_PRESET.has(preset_name)


## A fresh material for the preset, tinted and scaled. Null when the name is
## empty or unknown, so the caller keeps a plain tinted surface.
static func material_for(preset_name: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	if not is_known(preset_name):
		return null
	var loaded := load(str(MATERIAL_BY_PRESET[preset_name])) as StandardMaterial3D
	if loaded == null:
		return null
	var material := loaded.duplicate() as StandardMaterial3D
	material.albedo_color = tint
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return material
