extends Control

@export_group("Character Photo Settings")
@export var photo_offset: Vector2 = Vector2(0, 0) ## Geser posisi foto karakter (X, Y)
@export var photo_scale: Vector2 = Vector2(1.0, 1.0) ## Ubah skala / zoom foto karakter (X, Y)

@onready var character_photo = $TextureRect
@onready var fade_rect = $FadeRect
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var name_tag = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/NameTag
@onready var dialogue_text = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var narration_label = $CanvasLayer/NarrationLabel
@onready var black_screen = $CanvasLayer/BlackScreen

var phase = -1
var current_line = 0
var dialogue_lines = [
	{"name": "Ashy", "text": "I love you... but you are so stupid. I will lock you here forever."},
	{"name": "Ashy", "text": "No matter how much you try to answer, you will stay with me here in this darkness."}
]

var blip_player: AudioStreamPlayer
var is_typing = false
var is_typing_narration = false
var dialogue_tween: Tween
var last_visible_characters = 0
var last_narration_characters = 0

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready():
	if character_photo:
		character_photo.position += photo_offset
		character_photo.scale = photo_scale
		
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
	
	_start_ending_sequence()

func _process(_delta):
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

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance_dialogue()

func _advance_dialogue():
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

func _start_ending_sequence():
	SaveManager.unlock_ending("locked_up")
	phase = 0
	current_line = 0
	
	if SaveManager.get_language() == "id":
		dialogue_lines = [
			{"name": "Ashy", "text": "Aku mencintaimu... tapi kamu sangat bodoh. Aku akan menguncimu di sini selamanya."},
			{"name": "Ashy", "text": "Tidak peduli berapa kali kamu berusaha menjawab, kamu akan tetap bersamaku di sini dalam kegelapan."}
		]
	else:
		dialogue_lines = [
			{"name": "Ashy", "text": "I love you... but you are so stupid. I will lock you here forever."},
			{"name": "Ashy", "text": "No matter how much you try to answer, you will stay with me here in this darkness."}
		]
		
	dialogue_box.show()
	_show_next_line()

func _show_next_line():
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

func _start_epilogue():
	phase = 1
	dialogue_box.hide()
	
	black_screen.modulate.a = 0.0
	black_screen.show()
	
	var tween = create_tween()
	tween.tween_property(black_screen, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	narration_label.show()
	
	if SaveManager.get_language() == "id":
		await _play_narration("Aku terkunci di dalam ruangan, tidak pernah melihat cahaya siang lagi.")
		await _play_narration("Dia mencintaiku... tapi obsesinya menjadi sangkar abadiku.")
		await _play_narration("Namun sayangnya, aku mati karena kelaparan.")
	else:
		await _play_narration("I was locked inside the room, never to see the light of day again.")
		await _play_narration("She loved me... but her obsession became my eternal cage.")
		await _play_narration("But unfortunately, I died because of starvation.")
	
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _play_narration(text: String):
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
