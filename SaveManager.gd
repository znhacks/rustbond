extends Node

const SAVE_PATH = "user://save_data.json"

var unlocked_endings = {
	"true_love": false,
	"locked_up": false
}

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
				for k in json.data:
					unlocked_endings[k] = bool(json.data[k])

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(unlocked_endings))
		file.close()

func unlock_ending(ending_id: String):
	unlocked_endings[ending_id] = true
	save_data()

func is_unlocked(ending_id: String) -> bool:
	return unlocked_endings.get(ending_id, false)

func clear_library():
	unlocked_endings["true_love"] = false
	unlocked_endings["locked_up"] = false
	save_data()
