class_name TableTexts
extends RefCounted

## Every sentence the table component can show to a person, in each language.
## Code and logs use English snake_case reasons; people read these sentences.

const DEFAULT_LANGUAGE := "en"

const SENTENCES := {
	"host_only":
	{
		"en": "Only the host can change the table.",
		"es": "Solo el anfitrión puede cambiar la mesa.",
	},
	"session_not_active":
	{
		"en": "The match has not started.",
		"es": "La partida no está en marcha.",
	},
	"invalid_mode":
	{
		"en": "The table mode must be free or closed.",
		"es": "El modo de la mesa debe ser libre o cerrado.",
	},
	"nothing_to_change":
	{
		"en": "Tell me what to change on the surface.",
		"es": "Decime qué querés cambiar de la superficie.",
	},
	"invalid_surface":
	{
		"en": "The surface needs a readable color and a scale above zero.",
		"es": "La superficie necesita un color válido y una escala mayor a cero.",
	},
	"invalid_light":
	{
		"en": "The light needs a new id, a known type and an intensity above zero.",
		"es": "La luz necesita un id nuevo, un tipo conocido y una intensidad mayor a cero.",
	},
	"unknown_light":
	{
		"en": "There is no light with that id.",
		"es": "No existe una luz con ese id.",
	},
	"invalid_zone_visibility":
	{
		"en": "A zone is either public or private.",
		"es": "Una zona es pública o privada.",
	},
	"invalid_size":
	{
		"en": "Width and depth must be numbers above zero.",
		"es": "El ancho y el fondo deben ser números mayores a cero.",
	},
	"zone_resize_rejected":
	{
		"en": "The zone cannot shrink past the objects placed in it.",
		"es": "La zona no puede achicarse más allá de los objetos que tiene.",
	},
	"slot_rejected":
	{
		"en": "The slot needs a new id, an existing zone and a valid anchor.",
		"es": "El slot necesita un id nuevo, una zona existente y un ancla válida.",
	},
	"slot_remove_rejected":
	{
		"en": "Only an empty slot can be removed.",
		"es": "Solo se puede quitar un slot vacío.",
	},
}


## Returns the sentence for a refusal reason in the wanted language.
## Falls back to English, then to the reason itself, so a person never sees nothing.
static func sentence_for(reason: String, language: String = DEFAULT_LANGUAGE) -> String:
	var translations: Dictionary = SENTENCES.get(reason, {})
	if translations.has(language):
		return str(translations[language])
	return str(translations.get(DEFAULT_LANGUAGE, reason))


## Lists the languages every sentence is written in.
static func supported_languages() -> PackedStringArray:
	return PackedStringArray(["en", "es"])


## Lists the refusal reasons that have a sentence.
static func known_reasons() -> Array:
	return SENTENCES.keys()
