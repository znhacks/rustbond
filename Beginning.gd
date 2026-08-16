extends Control

@onready var broadcast_label = $CanvasLayer/BroadcastText
@onready var dialogue_box = $CanvasLayer/DialogueBox
@onready var dialogue_label = $CanvasLayer/DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var skip_indicator = $CanvasLayer/SkipMargin
@onready var tv_bg = $CanvasLayer/ColorRect
@onready var background = $Background

var tex_tv = preload("res://assets/UI/tv_polos.jpg")

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

func _ready():
	broadcast_label.text = ""
	dialogue_label.text = ""
	tv_bg.color.a = 0.0
	dialogue_box.hide()
	
	# Bikin SkipIndicator kedap-kedip
	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(skip_indicator, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(skip_indicator, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	
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
		
	if is_advance_action:
		if is_tv_mode:
			if type_timer and not type_timer.is_stopped():
				# Skip TV broadcast typing
				type_timer.stop()
				current_char = full_text.length()
				broadcast_label.text = full_text
				skip_indicator.hide()
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
		if char == '.' or char == ',' or char == '\n':
			type_timer.start(0.4)
		else:
			type_timer.start(type_speed)
	else:
		type_timer.stop()
		skip_indicator.hide()
