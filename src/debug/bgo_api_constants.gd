class_name BgoApiConstants
extends RefCounted

const VALUES := {
	"G.AVAILABILITY_FINITE": "finite",
	"G.AVAILABILITY_INFINITE": "infinite",
	"G.AVAILABILITY_UNIQUE": "unique",
	"G.COLOR_SOURCE_FIXED": "fixed",
	"G.COLOR_SOURCE_PLAYER": "player",
	"G.COMPONENT_BASIC_CYLINDER": "bgo.piece.basic_cylinder",
	"G.COMPONENT_BASIC_MASK": "bgo.player_presence.basic_mask",
	"G.COMPONENT_CHECKERED_BOARD": "bgo.board.checkered",
	"G.COMPONENT_PLAYER_AREA": "bgo.player_area.basic",
	"G.COMPONENT_TYPES.BASIC_CYLINDER": "bgo.piece.basic_cylinder",
	"G.HAND_OWNER_FACE_OTHERS_HIDDEN": "owner_face_others_hidden",
	"G.LOCATION_TYPES.ASSET_BOX": "asset_box",
	"G.LOCATION_TYPES.GRID": "grid",
	"G.LOCATION_TYPES.HAND": "hand",
	"G.LOCATION_TYPES.PLAYER_AREA": "player_area",
	"G.LOCATION_TYPES.SLOT": "slot",
	"G.LOCATION_ASSET_BOX": "asset_box",
	"G.LOCATION_GRID": "grid",
	"G.LOCATION_HAND": "hand",
	"G.LOCATION_PLAYER_AREA": "player_area",
	"G.LOCATION_SLOT": "slot",
	"G.ROLE_HOST": "host",
	"G.ROLE_PLAYER": "player",
	"G.ROLE_SPECTATOR": "spectator",
	"G.ROLES.HOST": "host",
	"G.ROLES.PLAYER": "player",
	"G.ROLES.SPECTATOR": "spectator",
	"G.PLAYER_COLOR_BLUE": "#4DB7F2",
	"G.PLAYER_COLOR_RED": "#E34850",
	"G.VISIBILITY.PUBLIC": "public",
}


static func get_value(constant_name: String) -> Dictionary:
	if not VALUES.has(constant_name):
		return {"ok": false, "reason": "unknown_constant"}
	return {"ok": true, "value": VALUES[constant_name]}


static func names() -> PackedStringArray:
	var result := PackedStringArray(VALUES.keys())
	result.sort()
	return result


static func has_valid_public_names() -> bool:
	var segment_pattern := RegEx.new()
	segment_pattern.compile("^[A-Z][A-Z0-9_]*$")
	for constant_name in VALUES:
		var segments := str(constant_name).split(".")
		if segments.size() < 2 or segments[0] != "G":
			return false
		for index in range(1, segments.size()):
			if segment_pattern.search(segments[index]) == null:
				return false
	return true
