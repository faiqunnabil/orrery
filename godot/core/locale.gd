class_name Locale
extends RefCounted

const ENGLISH := "en"
const INDONESIAN := "id"
const LANGUAGES: Array[String] = [ENGLISH, INDONESIAN]
const LANGUAGE_NAMES: Array[String] = ["English", "Bahasa Indonesia"]
const VOICE_LANGUAGE := ENGLISH


static func t(message: String) -> String:
	return String(TranslationServer.translate(message))


static func system_language() -> String:
	return INDONESIAN if OS.get_locale_language() == INDONESIAN else ENGLISH


static func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


static func has_voice() -> bool:
	return current() == VOICE_LANGUAGE
