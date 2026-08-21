extends Control

@onready var fade_rect = $FadeRect
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var name_tag = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/NameTag
@onready var dialogue_text = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var narration_label = $CanvasLayer/NarrationLabel
@onready var black_screen = $CanvasLayer/BlackScreen
@onready var background = $TextureRect2
@onready var character_photo = $TextureRect

var phase: int = -1
var current_line: int = 0
var dialogue_lines: Array = []

var blip_player: AudioStreamPlayer
var is_typing: bool = false
var is_typing_narration: bool = false
var dialogue_tween: Tween
var last_visible_characters: int = 0
var last_narration_characters: int = 0

var font_vt323: Font = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready() -> void:
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = -10.0
	add_child(blip_player)
	
	if dialogue_text: dialogue_text.add_theme_font_override("normal_font", font_vt323)
	if name_tag: name_tag.add_theme_font_override("font", font_vt323)
	if narration_label: narration_label.add_theme_font_override("font", font_vt323)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 2.0)
	await tween.finished
	
	character_photo.show()
	_start_ending_sequence()

func _process(_delta: float) -> void:
	if is_typing and dialogue_box.visible:
		var current_visible = dialogue_text.visible_characters
		if current_visible > last_visible_characters:
			if current_visible <= dialogue_text.text.length() and current_visible > 0:
				var char = dialogue_text.text[current_visible - 1]
				if char != " " and char != "\n":
					blip_player.pitch_scale = 0.65
					blip_player.play()
			last_visible_characters = current_visible
			
	if is_typing_narration and narration_label.visible:
		var current_visible = narration_label.visible_characters
		if current_visible > last_narration_characters:
			if current_visible <= narration_label.text.length() and current_visible > 0:
				var char = narration_label.text[current_visible - 1]
				if char != " " and char != "\n":
					blip_player.pitch_scale = 0.4
					blip_player.play()
			last_narration_characters = current_visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance_dialogue()

func _advance_dialogue() -> void:
	if phase != 0: return
	
	if is_typing:
		is_typing = false
		if dialogue_tween and dialogue_tween.is_valid():
			dialogue_tween.kill()
		dialogue_text.visible_characters = -1
		return
		
	current_line += 1
	if current_line < dialogue_lines.size():
		_show_next_line()
	else:
		_start_epilogue()

func _start_ending_sequence() -> void:
	SaveManager.unlock_ending("reality_ending")
	phase = 0
	current_line = 0
	
	if SaveManager.get_language() == "id":
		dialogue_lines = [
			{"name": "Ashy", "text": "Kamu..."},
			{"name": "Me", "text": "???"},
			{"name": "Ashy", "text": "Aku minta maaf ya."},
			{"name": "Ashy", "text": "Seharusnya aku berada dirumah"},
			{"name": "Ashy", "text": "Seharusnya aku mendengarkanmu"},
			{"name": "Me", "text": "?!"},
			{"name": "Ashy", "text": "Sepertinya kamu sudah tau"},
			{"name": "Ashy", "text": "Aku terbakar... Hangus... Dan menjadi abu"},
			{"name": "Me", "text": "Mi...."},
			{"name": "Ashy", "text": "Ya aku Mimi..."}
		]
	else:
		dialogue_lines = [
			{"name": "Ashy", "text": "You..."},
			{"name": "Me", "text": "???"},
			{"name": "Ashy", "text": "I'm sorry."},
			{"name": "Ashy", "text": "I should have stayed home."},
			{"name": "Ashy", "text": "I should have listened to you."},
			{"name": "Me", "text": "?!"},
			{"name": "Ashy", "text": "It seems you already know."},
			{"name": "Ashy", "text": "I burned... Charred... And turned to ash."},
			{"name": "Me", "text": "Mi...."},
			{"name": "Ashy", "text": "Yes, I am Mimi..."}
		]
		
	_show_dialogue_box()
	_show_next_line()

func _show_next_line() -> void:
	var line = dialogue_lines[current_line]
	name_tag.text = line["name"]
	dialogue_text.text = line["text"]
	dialogue_text.visible_characters = 0
	last_visible_characters = 0
	
	is_typing = true
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_text, "visible_characters", line["text"].length(), line["text"].length() * 0.05)
	dialogue_tween.finished.connect(func(): is_typing = false)

func _start_epilogue() -> void:
	phase = 1
	_hide_dialogue_box()
	
	black_screen.modulate.a = 0.0
	black_screen.show()
	
	var tween = create_tween()
	tween.tween_property(black_screen, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	narration_label.show()
	var is_id = SaveManager.get_language() == "id"
	
	if is_id:
		await _play_narration("Ashy adalah Mimi. Wanita yang tewas dikarenakan kehancuran lab")
		await _play_narration("Api, Keributan, Kebencian. dan Parasit yang menjangkit tubuhnya perlahan hilang begitu saja...")
	else:
		await _play_narration("Ashy is Mimi. The woman who died due to the laboratory's destruction.")
		await _play_narration("Fire, Chaos, Hatred. And the Parasite infecting her body slowly faded away...")
	
	background.texture = preload("res://assets/UI/mimi_angel.jpg")
	character_photo.hide()
	var reveal_tw = create_tween()
	reveal_tw.tween_property(black_screen, "modulate:a", 0.0, 2.0)
	await reveal_tw.finished
	
	await get_tree().create_timer(3.0).timeout
	
	TransitionManager.transition_to_scene("res://MainMenu.tscn")

func _play_narration(text: String) -> void:
	narration_label.text = text
	narration_label.modulate.a = 1.0
	narration_label.visible_characters = 0
	last_narration_characters = 0
	
	is_typing_narration = true
	var t = create_tween()
	t.tween_property(narration_label, "visible_characters", text.length(), text.length() * 0.05)
	t.finished.connect(func(): is_typing_narration = false)
	
	await t.finished
	await get_tree().create_timer(3.0).timeout
	var t2 = create_tween()
	t2.tween_property(narration_label, "modulate:a", 0.0, 1.5)
	await t2.finished

func _generate_8bit_blip() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	
	var tone_duration := 0.04
	var tone_frequency := 600.0
	var frame_count := int(wav.mix_rate * tone_duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	
	for i in range(frame_count):
		var time := float(i) / wav.mix_rate
		var wave := 1.0 if sin(time * tone_frequency * TAU) > 0.0 else -1.0
		var volume_fade := 1.0
		var fade_start := frame_count * 0.7
		if i > fade_start:
			volume_fade = 1.0 - float(i - fade_start) / (frame_count * 0.3)
		data[i] = int(wave * volume_fade * 40) + 128
		
	wav.data = data
	return wav

func _show_dialogue_box() -> void:
	if dialogue_box.visible and dialogue_box.modulate.a >= 1.0: return
	dialogue_box.show()
	var tw = create_tween()
	tw.tween_property(dialogue_box, "modulate:a", 1.0, 0.25)

func _hide_dialogue_box() -> void:
	if not dialogue_box.visible: return
	var tw = create_tween()
	tw.tween_property(dialogue_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(dialogue_box.hide)
