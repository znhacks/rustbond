extends Control

@onready var broadcast_label = $CanvasLayer/BroadcastText
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var dialogue_label = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var name_tag = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/NameTag
@onready var character_sprite = $CanvasLayer/CharacterSprite
@onready var skip_indicator = $CanvasLayer/SkipMargin
@onready var tv_bg = $CanvasLayer/ColorRect
@onready var background = $Background

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

var tv_done_waiting = false
var post_tv_phase = 0
var choice_container : VBoxContainer

func _ready():
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

func _start_dialogue():
	dialogue_box.show()
	_show_next_dialogue()

func _show_next_dialogue():
	if current_dialogue_idx < dialogues.size():
		dialogue_label.text = dialogues[current_dialogue_idx]
		dialogue_label.visible_characters = 0
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
				skip_indicator.show()
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
			blip_player.play()
			
		if char == '.' or char == ',' or char == '\n':
			type_timer.start(0.4)
		else:
			type_timer.start(type_speed)
	else:
		type_timer.stop()
		skip_indicator.show()
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
	is_typing_dialogue = true
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
		character_sprite.show()
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
		post_tv_phase = 99
	elif post_tv_phase == 30:
		_play_dialogue_line("???", "Seems like no one is home...")
		post_tv_phase = 21
	elif post_tv_phase == 21:
		_play_dialogue_line("???", "Hello?")
		post_tv_phase = 22
	elif post_tv_phase == 22:
		dialogue_box.hide()
		_show_choice(["Check from the curtains", "Stay silent"], _on_choice_2)
	elif post_tv_phase == 30:
		_play_dialogue_line("System", "(The mysterious woman leaves. SAFE ENDING)")
		post_tv_phase = 99

func _show_choice(choices: Array, callback: Callable):
	if choice_container:
		choice_container.queue_free()
	choice_container = VBoxContainer.new()
	choice_container.set_anchors_preset(Control.PRESET_CENTER)
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(300, 50)
		btn.pressed.connect(callback.bind(i))
		choice_container.add_child(btn)
		
	add_child(choice_container)

func _on_choice_1(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	if idx == 0:
		_play_dialogue_line("???", "Oh, so there is someone here.")
		post_tv_phase = 9  # Sisipkan fase untuk "Me"
	else:
		_play_dialogue_line("???", "...")
		post_tv_phase = 20

func _on_choice_2(idx: int):
	choice_container.queue_free()
	dialogue_box.show()
	if idx == 0:
		_play_dialogue_line("???", "Oh, so there is someone here.")
		post_tv_phase = 9
	else:
		_play_dialogue_line("???", "...")
		post_tv_phase = 30

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
