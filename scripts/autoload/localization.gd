extends Node
## Builds Translation resources from data/translations.json (no import step needed)
## and keeps the active locale in sync with Settings.language.

const SOURCE := "res://data/translations.json"
const SUPPORTED: Array[String] = ["en", "ar"]


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var translations := {}
	for locale in SUPPORTED:
		var t := Translation.new()
		t.locale = locale
		translations[locale] = t
		TranslationServer.add_translation(t)
	for key: String in data:
		var entry: Dictionary = data[key]
		for locale in SUPPORTED:
			var text: String = entry.get(locale, entry.get("en", key))
			(translations[locale] as Translation).add_message(key, text)
	Settings.changed.connect(_apply)
	_apply()


func current() -> String:
	if Settings.language in SUPPORTED:
		return Settings.language
	var os_lang := OS.get_locale_language()
	return os_lang if os_lang in SUPPORTED else "en"


func is_rtl() -> bool:
	return current() == "ar"


func _apply() -> void:
	if TranslationServer.get_locale() != current():
		TranslationServer.set_locale(current())
