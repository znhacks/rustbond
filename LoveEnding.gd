extends Control

@onready var fade_rect = $FadeRect
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var name_tag = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/NameTag
@onready var dialogue_text = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var choice_container = $CanvasLayer/ChoiceContainer
@onready var narration_label = $CanvasLayer/NarrationLabel
@onready var black_screen = $CanvasLayer/BlackScreen

var phase = -1
var current_line = 0
var dialogue_lines = [
	{"name": "Ashy", "text": "You earned my trust."},
	{"name": "Ashy", "text": "Do you want to remain a human, or become a part of me?"},
	{"name": "Ashy", "text": "No need to lie, I won't hurt you."}
]

var blip_player: AudioStreamPlayer
var is_typing = false
var is_typing_narration = false
var dialogue_tween: Tween
var last_visible_characters = 0
var last_narration_characters = 0

func _ready():
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = -10.0
	add_child(blip_player)
	
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
					blip_player.pitch_scale = 0.65 # Deeper "Mommy" voice pitch
					blip_player.play()
			last_visible_characters = current_visible
			
	if is_typing_narration and narration_label.visible:
		var current_visible = narration_label.visible_characters
		if current_visible > last_narration_characters:
			if current_visible <= narration_label.text.length() and current_visible > 0:
				var char = narration_label.text[current_visible - 1]
				if char != " " and char != "\n":
					blip_player.pitch_scale = 0.4 # Heavy TV beep pitch
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
		_show_choices()

func _start_ending_sequence():
	phase = 0
	current_line = 0
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

func _show_choices():
	phase = 1
	dialogue_box.hide()
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	choice_container.add_child(vbox)
	
	var btn_human = Button.new()
	btn_human.text = "Human"
	btn_human.add_theme_font_size_override("font_size", 24)
	btn_human.custom_minimum_size = Vector2(200, 50)
	btn_human.pressed.connect(_on_human_chosen)
	vbox.add_child(btn_human)
	
	var btn_parasite = Button.new()
	btn_parasite.text = "Parasite"
	btn_parasite.add_theme_font_size_override("font_size", 24)
	btn_parasite.custom_minimum_size = Vector2(200, 50)
	btn_parasite.pressed.connect(_on_parasite_chosen)
	vbox.add_child(btn_parasite)

func _type_response(speaker: String, text: String):
	name_tag.text = speaker
	dialogue_text.text = text
	dialogue_text.visible_characters = 0
	last_visible_characters = 0
	
	is_typing = true
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_text, "visible_characters", text.length(), text.length() * 0.05)
	dialogue_tween.finished.connect(func(): is_typing = false)
	
	await dialogue_tween.finished

func _on_human_chosen():
	for c in choice_container.get_children():
		c.queue_free()
	
	dialogue_box.show()
	phase = 2
	
	await _type_response("Ashy", "Very well, if that is your wish.")
	await get_tree().create_timer(2.0).timeout
	_start_epilogue("human")

func _on_parasite_chosen():
	for c in choice_container.get_children():
		c.queue_free()
	
	dialogue_box.show()
	phase = 2
	
	await _type_response("Ashy", "You truly are loyal, aren't you.")
	await get_tree().create_timer(2.0).timeout
	_start_epilogue("parasite")

func _start_epilogue(type: String):
	dialogue_box.hide()
	
	black_screen.modulate.a = 0.0
	black_screen.show()
	
	var tween = create_tween()
	tween.tween_property(black_screen, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	narration_label.show()
	
	if type == "human":
		await _play_narration("However, I eventually found myself back at my home. Strangely, everything was not in ruins. People were even going about their business outside.")
		await _play_narration("So, what exactly happened? Where did the plague go?")
	else:
		await _play_narration("She then bit my neck. It felt strange... before I finally perished from this earth.")
		await _play_narration("And ended up with her in the realm of tranquility.")
		await _play_narration("So, who was the Ashy I met earlier?")
	
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
