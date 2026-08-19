extends Control

@onready var broadcast_label = $CanvasLayer/BroadcastText
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var dialogue_label = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var name_tag = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/NameTag
@onready var character_sprite = $CanvasLayer/CharacterSprite
@onready var skip_indicator = $CanvasLayer/SkipMargin
@onready var tv_bg = $CanvasLayer/ColorRect
@onready var background = $Background

var love_bar: ProgressBar
var rage_bar: ProgressBar
var love_container: VBoxContainer
var rage_container: VBoxContainer

var tex_ashy = preload("res://assets/Ashy/ashy.png")
var tex_ashy_talk = preload("res://assets/Ashy/ashy_talk.png")
var tex_ashy_happy = preload("res://assets/Ashy/ashy_happy.png")
var tex_ashy_angry = preload("res://assets/Ashy/ashy_angry.png")

var blip_player : AudioStreamPlayer
var dialogue_tween : Tween
var is_typing_dialogue = false
var last_visible_characters = 0

var choice_container : Control

var questions = []
var current_question_idx = 0
var phase = 0

var consecutive_correct = 0

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready():
	if dialogue_label: dialogue_label.add_theme_font_override("normal_font", font_vt323)
	if broadcast_label: broadcast_label.add_theme_font_override("font", font_vt323)
	if name_tag: name_tag.add_theme_font_override("font", font_vt323)
	
	tv_bg.hide()
	broadcast_label.hide()
	dialogue_box.hide()
	
	# Local SkipIndicator hidden in favor of global SkipOverlay
	if skip_indicator:
		skip_indicator.hide()
	
	# Setup audio
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = -15.0
	add_child(blip_player)
	
	_setup_meters()
	_load_questions()
	
	background.texture = preload("res://assets/UI/abandoned_lab.jpg")
	character_sprite.show()
	character_sprite.modulate.a = 0.0
	_change_character_sprite(tex_ashy)
	
	var fade_in = create_tween()
	fade_in.tween_property(character_sprite, "modulate:a", 1.0, 1.5)
	
	# BGM Ingame dikelola secara otomatis oleh global BGMManager
	
	await get_tree().create_timer(1.0).timeout
	_start_intro()

func _setup_meters():
	love_container = VBoxContainer.new()
	love_container.position = Vector2(20, 20)
	var love_label = Label.new()
	love_label.text = "Love Meter"
	love_label.add_theme_font_override("font", font_vt323)
	love_label.add_theme_font_size_override("font_size", 22)
	love_container.add_child(love_label)
	
	love_bar = ProgressBar.new()
	love_bar.custom_minimum_size = Vector2(250, 30)
	love_bar.max_value = 100
	love_bar.value = 0
	love_bar.modulate = Color(1, 0.4, 0.7)
	love_bar.add_theme_font_override("font", font_vt323)
	love_bar.add_theme_font_size_override("font_size", 20)
	love_container.add_child(love_bar)
	
	rage_container = VBoxContainer.new()
	rage_container.position = Vector2(20, 90)
	var rage_label = Label.new()
	rage_label.text = "Rage Meter"
	rage_label.add_theme_font_override("font", font_vt323)
	rage_label.add_theme_font_size_override("font_size", 22)
	rage_container.add_child(rage_label)
	
	rage_bar = ProgressBar.new()
	rage_bar.custom_minimum_size = Vector2(250, 30)
	rage_bar.max_value = 100
	rage_bar.value = 0
	rage_bar.modulate = Color(1, 0, 0)
	rage_bar.add_theme_font_override("font", font_vt323)
	rage_bar.add_theme_font_size_override("font_size", 20)
	rage_container.add_child(rage_bar)
	
	# Skip Indicator font
	var skip_label = skip_indicator.get_node_or_null("HBoxContainer/SkipIndicator")
	if skip_label:
		skip_label.add_theme_font_override("font", font_vt323)
		skip_label.add_theme_font_size_override("font_size", 22)
	
	$CanvasLayer.add_child(love_container)
	$CanvasLayer.add_child(rage_container)

func _setup_dev_tools():
	var dev_container = HBoxContainer.new()
	dev_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dev_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_container.position = Vector2(0, 10)
	
	var btn_love = Button.new()
	btn_love.text = "DEV: +Love"
	btn_love.pressed.connect(func():
		love_bar.value += 20
		if love_bar.value >= 100:
			_good_ending()
	)
	dev_container.add_child(btn_love)
	
	var btn_rage = Button.new()
	btn_rage.text = "DEV: +Rage"
	btn_rage.pressed.connect(func():
		rage_bar.value += 20
		if rage_bar.value >= 100:
			_check_rage_or_jumpscare()
	)
	dev_container.add_child(btn_rage)
	
	$CanvasLayer.add_child(dev_container)

func _load_questions():
	var q_path = "res://data/questions_id.json" if SaveManager.get_language() == "id" else "res://data/questions.json"
	var file = FileAccess.open(q_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			questions = json.data
			questions.shuffle()
		else:
			print("JSON Parse Error: ", json.get_error_message())

func _process(delta):
	if is_typing_dialogue and dialogue_box.visible:
		var current_visible = dialogue_label.visible_characters
		if current_visible > last_visible_characters:
			if current_visible <= dialogue_label.text.length() and current_visible > 0:
				var char = dialogue_label.text[current_visible - 1]
				if char != " " and char != "\n":
					blip_player.play()
			last_visible_characters = current_visible

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_input_advance_override2()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_handle_input_advance_override2()

func _start_intro():
	dialogue_box.show()
	phase = 1
	_play_dialogue_line("Ashy", "This is my home. My final home.")

func _advance_phase():
	if phase == 1:
		_play_dialogue_line("Ashy", "The place where I was hated, enslaved, and died miserably.")
		phase = 2
	elif phase == 2:
		_play_dialogue_line("Me", "...!?")
		phase = 3
	elif phase == 3:
		dialogue_box.hide()
		_show_choice(["I'm sorry to hear that.", "The you right now is..."], _on_intro_choice)
	elif phase == 4:
		_change_character_sprite(tex_ashy_happy)
		_play_dialogue_line("Ashy", "You're kind. Good thing I didn't infect you from the start.")
		phase = 6
	elif phase == 5:
		_change_character_sprite(tex_ashy_angry)
		_play_dialogue_line("Ashy", "Yes, it's me. I AM THE ONE WHO SPREAD THIS VIRUS.")
		phase = 6
	elif phase == 6:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Ashy", "Never mind... let's continue with the Q&A.")
		phase = 7
	elif phase == 7:
		_ask_question()
	elif phase == 99:
		# End states
		pass

func _on_intro_choice(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	if idx == 0:
		phase = 4
		_advance_phase()
	else:
		phase = 5
		_advance_phase()

func _ask_question():
	if current_question_idx >= questions.size():
		# Acak ulang soal jika habis, sehingga looping tanpa akhir
		current_question_idx = 0
		questions.shuffle()
		
	var q = questions[current_question_idx]
	var text = q["pertanyaan"]
	if q["is_krusial"]:
		text = "[CRITICAL] " + q["peringatan_krusial"] + "\n\n" + text
		
	_play_dialogue_line("Ashy", text)
	phase = 100

func _advance_phase_from_question():
	if phase == 100:
		dialogue_box.hide()
		var q = questions[current_question_idx]
		var choices = []
		for c in q["pilihan"]:
			choices.append(c["teks"])
		_show_choice(choices, _on_question_answered)

func _on_question_answered(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	
	var q = questions[current_question_idx]
	var ans = q["pilihan"][idx]
	
	current_question_idx += 1
	
	if ans["efek"] == "INSTANT_RAGE":
		rage_bar.value = 100
		_check_rage_or_jumpscare()
		return
		
	elif ans["efek"] == "NORMAL_WRONG":
		consecutive_correct = 0
		rage_bar.value += 20
		_change_character_sprite(tex_ashy_angry)
		
		if rage_bar.value >= 100:
			_check_rage_or_jumpscare()
			return
		else:
			_play_dialogue_line("Ashy", "Hmph. Wrong.")
			phase = 200
			
	elif ans["efek"] == "NORMAL_HALF":
		consecutive_correct = 0
		rage_bar.value += 10
		_change_character_sprite(tex_ashy)
		
		if rage_bar.value >= 100:
			_check_rage_or_jumpscare()
			return
		else:
			_play_dialogue_line("Ashy", "I guess that's an okay answer.")
			phase = 200
			
	elif ans["efek"] == "NORMAL_CORRECT":
		consecutive_correct += 1
		_change_character_sprite(tex_ashy_happy)
		
		if consecutive_correct >= 3:
			consecutive_correct = 0
			love_bar.value += 20
			if love_bar.value >= 100:
				_good_ending()
				return
			else:
				_play_dialogue_line("Ashy", "Wh-what a sweet answer... I can feel we are getting closer!")
				phase = 200
		else:
			_play_dialogue_line("Ashy", "Good answer.")
			phase = 200

func _process_phase_250_input():
	if phase == 250:
		dialogue_box.hide()
		_show_choice(["Gently hold her hand.", "Do nothing."], _on_love_choice)
		
func _on_love_choice(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	
	if idx == 0:
		love_bar.value += 20
		if love_bar.value >= 100:
			_good_ending()
		else:
			_play_dialogue_line("Ashy", "*blushes* Wh-what are you doing... let's just continue.")
			phase = 300
	else:
		_play_dialogue_line("Ashy", "Let's continue the game.")
		phase = 300

func _handle_input_advance_override2():
	if choice_container and choice_container.is_inside_tree():
		return
		
	if is_typing_dialogue:
		is_typing_dialogue = false
		if dialogue_tween and dialogue_tween.is_valid():
			dialogue_tween.kill()
		dialogue_label.visible_characters = -1
		return
		
	if phase == 100:
		_advance_phase_from_question()
	elif phase == 200 or phase == 300:
		_ask_question()
	elif phase == 250:
		_process_phase_250_input()
	else:
		_advance_phase()

func _check_rage_or_jumpscare():
	if love_bar.value >= 80:
		_locked_up_ending()
	else:
		_trigger_jumpscare()

func _trigger_jumpscare():
	get_tree().change_scene_to_file("res://Jumpscare.tscn")

func _locked_up_ending():
	get_tree().change_scene_to_file("res://LockedUpEnding.tscn")

func _good_ending():
	get_tree().change_scene_to_file("res://LoveEnding.tscn")

func _reset_game():
	rage_bar.value = 0
	love_bar.value = 0
	consecutive_correct = 0
	current_question_idx = 0
	questions.shuffle()
	
	love_container.show()
	rage_container.show()
	character_sprite.show()
	
	background.texture = preload("res://assets/UI/abandoned_lab.jpg")
	_change_character_sprite(tex_ashy)
	
	dialogue_box.show()
	_play_dialogue_line("Ashy", "Let's try that again...")
	phase = 7

func apply_gray_choice_button_style(btn: Button):
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.75, 1.0))
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.15, 0.15, 0.17, 0.88)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(0.45, 0.45, 0.5, 0.85)
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_right = 8
	sb_normal.corner_radius_bottom_left = 8
	sb_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb_normal.shadow_size = 4
	btn.add_theme_stylebox_override("normal", sb_normal)
	
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.28, 0.28, 0.32, 0.95)
	sb_hover.border_color = Color(0.75, 0.75, 0.85, 1.0)
	sb_hover.shadow_color = Color(0.5, 0.5, 0.6, 0.45)
	sb_hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", sb_hover)
	
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.38, 0.38, 0.42, 1.0)
	sb_pressed.border_color = Color(0.9, 0.9, 0.95, 1.0)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

func _show_choice(choices: Array, callback: Callable):
	if choice_container:
		choice_container.queue_free()
	
	choice_container = CenterContainer.new()
	choice_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(320, 55)
		apply_gray_choice_button_style(btn)
		btn.pressed.connect(callback.bind(i))
		vbox.add_child(btn)
		
	choice_container.add_child(vbox)
	$CanvasLayer.add_child(choice_container)

func _play_dialogue_line(speaker: String, text: String):
	name_tag.text = speaker
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	last_visible_characters = 0
	is_typing_dialogue = true
	
	if speaker == "Me":
		blip_player.pitch_scale = 0.6
	elif speaker == "Ashy" or speaker == "???":
		blip_player.pitch_scale = 1.4
	else:
		blip_player.pitch_scale = 1.0
		
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_label, "visible_characters", text.length(), text.length() * 0.05)
	dialogue_tween.finished.connect(func(): is_typing_dialogue = false)

func _change_character_sprite(new_texture: Texture2D):
	if character_sprite.texture == new_texture:
		return
		
	character_sprite.texture = new_texture
	character_sprite.pivot_offset = Vector2(character_sprite.size.x / 2.0, character_sprite.size.y)
	var tween = create_tween()
	tween.tween_property(character_sprite, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(character_sprite, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

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
