class_name BgoClientRenderProfile
extends RefCounted

const WINDOWS_NATIVE := {
	"id": "windows_native",
	"quality": "desktop_high",
	"representation": "desktop_model_lod",
	"camera": "free_perspective",
	"fixed_pitch": false,
	"fixed_height": false,
}
const WEB := {
	"id": "web",
	"quality": "web_billboard",
	"representation": "billboard",
	"camera": "fixed_height_pitch_orbit",
	"fixed_pitch": true,
	"fixed_height": true,
}
const MOBILE := {
	"id": "mobile",
	"quality": "mobile_billboard",
	"representation": "billboard",
	"camera": "fixed_height_pitch_orbit",
	"fixed_pitch": true,
	"fixed_height": true,
}


## Resolves the local rendering profile without changing authoritative state.
static func current() -> Dictionary:
	if OS.has_feature("mobile"):
		return MOBILE.duplicate(true)
	if OS.has_feature("web"):
		return WEB.duplicate(true)
	return WINDOWS_NATIVE.duplicate(true)


## Returns a deterministic profile for tests and launch-option adapters.
static func by_id(profile_id: String) -> Dictionary:
	match profile_id:
		"web":
			return WEB.duplicate(true)
		"mobile":
			return MOBILE.duplicate(true)
		_:
			return WINDOWS_NATIVE.duplicate(true)


## Returns whether the tactical view was requested from launch arguments.
static func tactical_requested(arguments: PackedStringArray) -> bool:
	return "--view=tactical" in arguments


## Returns whether the current profile permits changing perspective pitch.
static func allows_pitch(profile: Dictionary) -> bool:
	return not bool(profile.get("fixed_pitch", false))


## Applies local tactical camera/representation state and returns pitch/distance.
static func apply_tactical_view(
	camera: Camera3D,
	enabled: bool,
	home_pitch: float,
	home_distance: float,
	adaptive_nodes: Array[Node],
) -> Vector2:
	camera.projection = (
		Camera3D.PROJECTION_ORTHOGONAL if enabled else Camera3D.PROJECTION_PERSPECTIVE
	)
	if enabled:
		camera.size = 16.0
	for node in adaptive_nodes:
		(node as BgoAdaptiveRepresentation).set_tactical_view(enabled)
	return Vector2(
		deg_to_rad(89.0) if enabled else home_pitch,
		maxf(home_distance, 12.0) if enabled else home_distance,
	)
