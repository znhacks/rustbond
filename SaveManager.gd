extends Node

const SAVE_PATH = "user://save_data.json"

var current_language: String = "en" # Default: English ("en" or "id")

var unlocked_endings = {
	"true_love": false,
	"locked_up": false,
	"safe_ending": false,
	"reality_ending": false
}

signal language_changed(new_lang: String)

func _ready():
	load_data()

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				if json.data.has("endings") and json.data["endings"] is Dictionary:
					for k in json.data["endings"]:
						unlocked_endings[k] = bool(json.data["endings"][k])
				else:
					for k in json.data:
						if k in unlocked_endings:
							unlocked_endings[k] = bool(json.data[k])
							
				if json.data.has("language"):
					current_language = str(json.data["language"])

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"endings": unlocked_endings,
			"language": current_language
		}
		file.store_string(JSON.stringify(data))
		file.close()

func get_language() -> String:
	return current_language

func set_language(lang: String):
	current_language = lang
	save_data()
	language_changed.emit(current_language)

func toggle_language() -> String:
	if current_language == "en":
		set_language("id")
	else:
		set_language("en")
	return current_language

func unlock_ending(ending_id: String):
	unlocked_endings[ending_id] = true
	save_data()

func is_unlocked(ending_id: String) -> bool:
	return unlocked_endings.get(ending_id, false)

func clear_library():
	unlocked_endings["true_love"] = false
	unlocked_endings["locked_up"] = false
	unlocked_endings["safe_ending"] = false
	unlocked_endings["reality_ending"] = false
	save_data()
