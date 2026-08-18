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

var tex_tv = preload("res://assets/UI/tv_polos.jpg")

var tex_ashy = preload("res://assets/Ashy/ashy.png")
var tex_ashy_talk = preload("res://assets/Ashy/ashy_talk.png")
var tex_ashy_happy = preload("res://assets/Ashy/ashy_happy.png")
var tex_ashy_angry = preload("res://assets/Ashy/ashy_angry.png")

var full_text = """Official Warning from the Local Government

N.O.S-VID (Necrotic Organ Starvation Virus Infectious Disease) has infected many people in the city of Malzero, and medical personnel have been overwhelmed due to the chaos caused by infected patients.

Residents are allowed to use any protective gear to avoid N.O.S-VID victims.

Be aware of your surroundings, stay safe, and pray. Hopefully, we all make it through."""

var dialogues = [
	"Phew... what a tiring day at work.",
	"Let's see what's on the news."
]

var current_dialogue_idx = 0
var is_typing_dialogue = false
var is_tv_mode = false
var dialogue_tween : Tween

var current_char = 0
var type_speed = 0.04
var type_timer : Timer
var blip_player : AudioStreamPlayer
var last_visible_characters = 0

var tv_done_waiting = false
var post_tv_phase = 0
var choice_container : Control

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready():
	if dialogue_label: dialogue_label.add_theme_font_override("normal_font", font_vt323)
	if broadcast_label: broadcast_label.add_theme_font_override("font", font_vt323)
	if name_tag: name_tag.add_theme_font_override("font", font_vt323)
	
	broadcast_label.text = ""
	dialogue_label.text = ""
	tv_bg.color.a = 0.0
	dialogue_box.hide()
	character_sprite.hide()
	
	# Bikin SkipIndicator kedap-kedip
	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(skip_indicator, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(skip_indicator, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# Setup suara blip 8-bit
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = -15.0
	add_child(blip_player)
	
	# Setup Meters
	love_container = VBoxContainer.new()
	love_container.name = "LoveContainer"
	love_container.position = Vector2(20, 20)
	
	var love_label = Label.new()
	love_label.text = "Love Meter"
	love_label.add_theme_font_override("font", font_vt323)
	love_label.add_theme_font_size_override("font_size", 22)
	love_container.add_child(love_label)
	
	love_bar = ProgressBar.new()
	love_bar.name = "LoveMeter"
	love_bar.custom_minimum_size = Vector2(250, 30)
	love_bar.max_value = 100
	love_bar.value = 0
	love_bar.modulate = Color(1, 0.4, 0.7) # Pink
	love_bar.add_theme_font_override("font", font_vt323)
	love_bar.add_theme_font_size_override("font_size", 20)
	love_container.add_child(love_bar)
	
	rage_container = VBoxContainer.new()
	rage_container.name = "RageContainer"
	rage_container.position = Vector2(20, 90)
	
	var rage_label = Label.new()
	rage_label.text = "Rage Meter"
	rage_label.add_theme_font_override("font", font_vt323)
	rage_label.add_theme_font_size_override("font_size", 22)
	rage_container.add_child(rage_label)
	
	rage_bar = ProgressBar.new()
	rage_bar.name = "RageMeter"
	rage_bar.custom_minimum_size = Vector2(250, 30)
	rage_bar.max_value = 100
	rage_bar.value = 0
	rage_bar.modulate = Color(1, 0, 0) # Merah
	rage_bar.add_theme_font_override("font", font_vt323)
	rage_bar.add_theme_font_size_override("font_size", 20)
	rage_container.add_child(rage_bar)
	
	# Skip Indicator font
	var skip_label = skip_indicator.get_node_or_null("HBoxContainer/SkipIndicator")
	if skip_label:
		skip_label.add_theme_font_override("font", font_vt323)
		skip_label.add_theme_font_size_override("font_size", 22)
	
	love_container.hide()
	rage_container.hide()
	
	$CanvasLayer.add_child(love_container)
	$CanvasLayer.add_child(rage_container)
	
	# BGM Ingame (dengan efek distorsi/redup lewat pitch & volume)
	var bgm_player = AudioStreamPlayer.new()
	var bgm_stream = preload("res://assets/Audio/FMB Ingamever.mp3")
	bgm_player.stream = bgm_stream
	bgm_player.pitch_scale = 0.85
	bgm_player.volume_db = -5.0
	bgm_player.finished.connect(func(): bgm_player.play())
	add_child(bgm_player)
	bgm_player.play()
	
	await get_tree().create_timer(1.0).timeout
	_start_dialogue()

func _process(delta):
	if is_typing_dialogue and dialogue_box.visible:
		var current_visible = dialogue_label.visible_characters
		if current_visible > last_visible_characters:
			if current_visible <= dialogue_label.text.length() and current_visible > 0:
				var char = dialogue_label.text[current_visible - 1]
				if char != " " and char != "\n":
					blip_player.play()
			last_visible_characters = current_visible

func _start_dialogue():
	dialogue_box.show()
	_show_next_dialogue()

func _show_next_dialogue():
	if current_dialogue_idx < dialogues.size():
		name_tag.text = "Me"
		blip_player.pitch_scale = 0.6
		dialogue_label.text = dialogues[current_dialogue_idx]
		dialogue_label.visible_characters = 0
		last_visible_characters = 0
		is_typing_dialogue = true
		
		if dialogue_tween and dialogue_tween.is_valid():
			dialogue_tween.kill()
			
		dialogue_tween = create_tween()
		dialogue_tween.tween_property(dialogue_label, "visible_characters", dialogue_label.text.length(), dialogue_label.text.length() * 0.05)
		dialogue_tween.finished.connect(func(): is_typing_dialogue = false)
		
		current_dialogue_idx += 1
	else:
		_transition_to_tv()

func _input(event):
	var is_advance_action = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_advance_action = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		is_advance_action = true
		
	if is_advance_action:
		# Hide skip indicator on first interaction to keep screen clean
		if skip_indicator.visible:
			var tw = create_tween()
			tw.tween_property(skip_indicator, "modulate:a", 0.0, 0.5)
			tw.finished.connect(func(): skip_indicator.hide())
			
		if post_tv_phase > 0:
			if is_typing_dialogue:
				is_typing_dialogue = false
				if dialogue_tween and dialogue_tween.is_valid():
					dialogue_tween.kill()
				dialogue_label.visible_characters = -1
			else:
				_advance_post_tv()
			return
			
		if is_tv_mode:
			if type_timer and not type_timer.is_stopped():
				# Skip TV broadcast typing
				type_timer.stop()
				current_char = full_text.length()
				broadcast_label.text = full_text
				tv_done_waiting = true
			elif tv_done_waiting:
				tv_done_waiting = false
				is_tv_mode = false
				_start_post_tv()
			return
		
		if dialogue_box.visible:
			if is_typing_dialogue:
				# Skip ngetik (langsung muncul semua)
				is_typing_dialogue = false
				if dialogue_tween and dialogue_tween.is_valid():
					dialogue_tween.kill()
				dialogue_label.visible_characters = -1
			else:
				# Pindah ke dialog selanjutnya
				_show_next_dialogue()

func _transition_to_tv():
	dialogue_box.hide()
	is_tv_mode = true
	
	var fade = create_tween()
	fade.tween_property(tv_bg, "color:a", 1.0, 0.5)
	await fade.finished
	
	background.texture = tex_tv
	
	# Start TV flicker
	var flicker = create_tween().set_loops()
	flicker.tween_property(tv_bg, "color:a", 0.6, 0.1)
	flicker.tween_property(tv_bg, "color:a", 0.55, 0.1)
	flicker.tween_property(tv_bg, "color:a", 0.65, 0.05)
	
	await get_tree().create_timer(1.0).timeout
	
	# Start Broadcast Typing
	type_timer = Timer.new()
	type_timer.wait_time = type_speed
	type_timer.autostart = true
	type_timer.timeout.connect(_type_next_char)
	add_child(type_timer)

func _type_next_char():
	if current_char < full_text.length():
		broadcast_label.text += full_text[current_char]
		current_char += 1
		
		var char = full_text[current_char - 1]
		
		# Putar suara jika bukan spasi atau baris baru
		if char != " " and char != "\n":
			blip_player.pitch_scale = 1.0
			blip_player.play()
			
		if char == '.' or char == ',' or char == '\n':
			type_timer.start(0.4)
		else:
			type_timer.start(type_speed)
	else:
		type_timer.stop()
		tv_done_waiting = true

func _start_post_tv():
	tv_bg.hide()
	broadcast_label.hide()
	dialogue_box.show()
	post_tv_phase = 1
	_play_dialogue_line("Me", "Ugh, I had a bad feeling about this.")

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

func _advance_post_tv():
	if choice_container and choice_container.is_inside_tree():
		return # Menunggu player milih
		
	if post_tv_phase == 1:
		_play_dialogue_line("Me", "It was just in the other city yesterday, how did it spread here so fast...")
		post_tv_phase = 2
	elif post_tv_phase == 2:
		background.texture = preload("res://assets/UI/front_door.jpg")
		_play_dialogue_line("???", "* KNOCK KNOCK *")
		post_tv_phase = 3
	elif post_tv_phase == 3:
		dialogue_box.hide()
		_show_choice(["Check the door", "Ignore"], _on_choice_1)
	elif post_tv_phase == 9:
		_play_dialogue_line("Me", "(Huh? How did she know I was here without me telling her...)")
		post_tv_phase = 10
	elif post_tv_phase == 10:
		_play_dialogue_line("???", "I can hear your thoughts.")
		post_tv_phase = 11
	elif post_tv_phase == 11:
		_play_dialogue_line("System", "Not long after, she entered my house. I didn't even know who she was, but she looked very strange.")
		post_tv_phase = 12
	elif post_tv_phase == 12:
		background.texture = preload("res://assets/UI/playerhome.jpg")
		character_sprite.show()
		love_container.show()
		rage_container.show()
		_change_character_sprite(tex_ashy_happy)
		_play_dialogue_line("???", "It's nice of you to let me in.")
		post_tv_phase = 13
	elif post_tv_phase == 13:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("System", "I remained silent, confused. Why did she look so strange?")
		post_tv_phase = 14
	elif post_tv_phase == 14:
		_play_dialogue_line("System", "I remembered that some of her features... she might be infected with the virus.")
		post_tv_phase = 15
	elif post_tv_phase == 15:
		_change_character_sprite(tex_ashy_talk)
		_play_dialogue_line("???", "Hey? Why are you ignoring me?")
		post_tv_phase = 16
	elif post_tv_phase == 16:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "It's nothing, I'm just confused. Who are you?")
		post_tv_phase = 17
	elif post_tv_phase == 17:
		_change_character_sprite(tex_ashy_talk)
		_play_dialogue_line("Ashy", "I'm Ashy.")
		post_tv_phase = 18
	elif post_tv_phase == 18:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "Cool... uh, why are you here?")
		post_tv_phase = 19
	elif post_tv_phase == 19:
		_change_character_sprite(tex_ashy_talk)
		_play_dialogue_line("Ashy", "I'm hungry.")
		post_tv_phase = 20
	elif post_tv_phase == 20:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "What's your purpose in coming here if you're hungry?")
		post_tv_phase = 21
	elif post_tv_phase == 21:
		_change_character_sprite(tex_ashy_angry)
		_play_dialogue_line("Ashy", "What do you think I'm doing here, idiot!")
		post_tv_phase = 40
	elif post_tv_phase == 40:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "How rude. Alright, sit down over there first.")
		post_tv_phase = 41
	elif post_tv_phase == 41:
		_change_character_sprite(tex_ashy_angry)
		_play_dialogue_line("Ashy", "Hmph. Humans are indeed insensitive.")
		post_tv_phase = 42
	elif post_tv_phase == 42:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "(Ugh... I don't even know how to talk to girls...)")
		post_tv_phase = 43
	elif post_tv_phase == 43:
		background.texture = preload("res://assets/UI/kitchen.jpg")
		character_sprite.hide()
		_play_dialogue_line("System", "I finally went to the kitchen, made some warm chocolate milk, and got some bread.")
		post_tv_phase = 44
	elif post_tv_phase == 44:
		dialogue_box.hide()
		post_tv_phase = 445 # Cegah klik spasi memunculkan minigame berkali-kali
		var minigame = preload("res://CookingMinigame.gd").new()
		add_child(minigame)
		minigame.minigame_finished.connect(_on_minigame_finished)
	elif post_tv_phase == 45:
		_play_dialogue_line("Me", "Wait a minute, did she just say humans are insensitive?")
		post_tv_phase = 46
	elif post_tv_phase == 46:
		_play_dialogue_line("Me", "Then...")
		post_tv_phase = 47
	elif post_tv_phase == 47:
		dialogue_box.hide()
		_show_choice(["(Ah, maybe it's just my imagination)", "(Is she a ghost? An alien? A monster? A robot?)"], _on_choice_3)
	elif post_tv_phase == 50:
		_play_dialogue_line("???", "Seems like no one is home...")
		post_tv_phase = 51
	elif post_tv_phase == 51:
		_play_dialogue_line("???", "Hello?")
		post_tv_phase = 52
	elif post_tv_phase == 52:
		dialogue_box.hide()
		_show_choice(["Check from the curtains", "Stay silent"], _on_choice_2)
	elif post_tv_phase == 53:
		_play_dialogue_line("System", "(The mysterious woman leaves. SAFE ENDING)")
		post_tv_phase = 1000 # Wait
	elif post_tv_phase == 99:
		_change_character_sprite(tex_ashy_happy)
		_play_dialogue_line("Ashy", "Would you like to play a Q&A game with me?")
		post_tv_phase = 100
	elif post_tv_phase == 100:
		_change_character_sprite(tex_ashy)
		_play_dialogue_line("Me", "Uh, okay?")
		post_tv_phase = 101
	elif post_tv_phase == 101:
		# Save love/rage meter values before transitioning? We can just pass them globally via an Autoload if needed, or instantiate the next scene. For simplicity, we can use an Autoload, but let's just let TheBond.gd reset or read them. Wait, user wants them to start from 0 for now. So we'll just switch scene.
		get_tree().change_scene_to_file("res://TheBond.tscn")

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
	add_child(choice_container)

func _on_choice_1(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	if idx == 0:
		_play_dialogue_line("???", "Oh, so there is someone here.")
		post_tv_phase = 9  # Sisipkan fase untuk "Me"
	else:
		_play_dialogue_line("???", "...")
		post_tv_phase = 50

func _on_choice_2(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	if idx == 0:
		_play_dialogue_line("???", "Oh, so there is someone here.")
		post_tv_phase = 9
	else:
		_play_dialogue_line("???", "...")
		post_tv_phase = 53

func _on_choice_3(idx: int):
	choice_container.queue_free()
	
	# Kembali ke ruang tamu
	background.texture = preload("res://assets/UI/playerhome.jpg")
	character_sprite.show()
	love_container.show()
	rage_container.show()
	_change_character_sprite(tex_ashy)
	
	dialogue_box.show()
	if idx == 0:
		_play_dialogue_line("Me", "(Whatever, the important thing is she eats first.)")
		post_tv_phase = 99
	else:
		_play_dialogue_line("Me", "(Or maybe she's something else...)")
		# Love -10
		love_bar.value -= 10
		post_tv_phase = 99

func _on_minigame_finished():
	love_container.show()
	rage_container.show()
	
	dialogue_box.show()
	_play_dialogue_line("Me", "...")
	post_tv_phase = 45

func _change_character_sprite(new_texture: Texture2D):
	if character_sprite.texture == new_texture:
		return
		
	character_sprite.texture = new_texture
	
	# Set pivot ke tengah-bawah supaya animasi lompatnya menapak (tidak melayang)
	character_sprite.pivot_offset = Vector2(character_sprite.size.x / 2.0, character_sprite.size.y)
	
	# Animasi nge-bounce/loncat dikit
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
