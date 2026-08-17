class_name LenteLocalization
extends RefCounted

## Small, add-on-local translation registry.
##
## Lente follows TranslationServer.get_locale(), supports English, Italian, and
## Spanish (including regional variants), and deliberately falls back to English
## without changing the host project's global fallback locale.

const DEFAULT_LOCALE := "en"
const TRANSLATIONS := {
	"en": preload("res://addons/lente/locales/lente.en.po"),
	"it": preload("res://addons/lente/locales/lente.it.po"),
	"es": preload("res://addons/lente/locales/lente.es.po"),
}

static var _translations: Dictionary = {}
static var _registered := false


static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	for locale in TRANSLATIONS:
		var translation := TRANSLATIONS[locale] as Translation
		if not translation:
			continue
		_translations[locale] = translation
		TranslationServer.add_translation(translation)


static func get_active_locale() -> String:
	var locale := TranslationServer.get_locale().to_lower().replace("-", "_")
	var language := locale.get_slice("_", 0)
	return language if TRANSLATIONS.has(language) else DEFAULT_LOCALE


static func text(message: StringName) -> String:
	ensure_registered()
	var translation: Translation = _translations.get(get_active_locale())
	var translated := _message_from(translation, message)
	if not translated.is_empty():
		return translated
	translated = _message_from(_translations.get(DEFAULT_LOCALE), message)
	return translated if not translated.is_empty() else String(message)


static func _message_from(translation: Translation, message: StringName) -> String:
	if not translation:
		return ""
	var translated := String(translation.get_message(message))
	return "" if translated == String(message) else translated
