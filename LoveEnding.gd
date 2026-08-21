extends Control

@export_group("Character Photo Settings")
@export var photo_offset: Vector2 = Vector2(0, 0) ## Geser posisi foto karakter (X, Y)
@export var photo_scale: Vector2 = Vector2(1.0, 1.0) ## Ubah skala / zoom foto karakter (X, Y)

@onready var character_photo = $TextureRect
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

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready():
	if character_photo:
		character_photo.position += photo_offset
		character_photo.scale = photo_scale
		
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = -10.0
	add_child(blip_player)
	
	# Apply VT323 to dialogue and narration
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
				var c = dialogue_text.text[current_visible - 1]
				if c != " " and c != "\n":
					blip_player.pitch_scale = 0.65 # Deeper "Mommy" voice pitch
					blip_player.play()
			last_visible_characters = current_visible
			
	if is_typing_narration and narration_label.visible:
		var current_visible = narration_label.visible_characters
		if current_visible > last_narration_characters:
			if current_visible <= narration_label.text.length() and current_visible > 0:
				var c = narration_label.text[current_visible - 1]
				if c != " " and c != "\n":
					blip_player.pitch_scale = 0.4 # Heavy TV beep pitch
					blip_player.play()
			last_narration_characters = current_visible

func _unhandled_input(event):
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
	SaveManager.unlock_ending("true_love")
	phase = 0
	current_line = 0
	
	if SaveManager.get_language() == "id":
		dialogue_lines = [
			{"name": "Ashy", "text": "Kamu mendapatkan kepercayaanku."},
			{"name": "Ashy", "text": "Apakah kamu ingin tetap menjadi manusia, atau menjadi bagian dariku?"},
			{"name": "Ashy", "text": "Tidak perlu berbohong, aku tidak akan menyakitimu."}
		]
	else:
		dialogue_lines = [
			{"name": "Ashy", "text": "You earned my trust."},
			{"name": "Ashy", "text": "Do you want to remain a human, or become a part of me?"},
			{"name": "Ashy", "text": "No need to lie, I won't hurt you."}
		]
		
	_show_dialogue_box()
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

func _show_choices():
	phase = 1
	_hide_dialogue_box()
	
	choice_container.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(choice_container, "modulate:a", 1.0, 0.3)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	choice_container.add_child(vbox)
	
	var is_id = SaveManager.get_language() == "id"
	var btn_human = Button.new()
	btn_human.text = "Manusia" if is_id else "Human"
	btn_human.custom_minimum_size = Vector2(250, 55)
	apply_gray_choice_button_style(btn_human)
	btn_human.pressed.connect(_on_human_chosen)
	vbox.add_child(btn_human)
	
	var btn_parasite = Button.new()
	btn_parasite.text = "Parasit" if is_id else "Parasite"
	btn_parasite.custom_minimum_size = Vector2(250, 55)
	apply_gray_choice_button_style(btn_parasite)
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
	var tw = create_tween()
	tw.tween_property(choice_container, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		for c in choice_container.get_children():
			c.queue_free()
	)
	
	_show_dialogue_box()
	phase = 2
	
	var resp = "Baiklah, jika itu keinginanmu." if SaveManager.get_language() == "id" else "Very well, if that is your wish."
	await _type_response("Ashy", resp)
	await get_tree().create_timer(2.0).timeout
	_start_epilogue("human")

func _on_parasite_chosen():
	var tw = create_tween()
	tw.tween_property(choice_container, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		for c in choice_container.get_children():
			c.queue_free()
	)
	
	_show_dialogue_box()
	phase = 2
	
	var resp = "Kamu sungguh setia, ya." if SaveManager.get_language() == "id" else "You truly are loyal, aren't you."
	await _type_response("Ashy", resp)
	await get_tree().create_timer(2.0).timeout
	_start_epilogue("parasite")

func _start_epilogue(type: String):
	_hide_dialogue_box()
	
	black_screen.modulate.a = 0.0
	black_screen.show()
	
	var tween = create_tween()
	tween.tween_property(black_screen, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	narration_label.show()
	var is_id = SaveManager.get_language() == "id"
	
	if type == "human":
		if is_id:
			await _play_narration("Namun, akhirnya aku menemukan diriku kembali di rumahku. Anehnya, semuanya tidak hancur. Orang-orang bahkan beraktivitas di luar.")
			await _play_narration("Jadi, apa yang sebenarnya terjadi? Ke mana wabah itu pergi?")
		else:
			await _play_narration("However, I eventually found myself back at my home. Strangely, everything was not in ruins. People were even going about their business outside.")
			await _play_narration("So, what exactly happened? Where did the plague go?")
	else:
		if is_id:
			await _play_narration("Dia kemudian menggigit leherku. Rasanya aneh... sebelum aku akhirnya lenyap dari bumi ini.")
			await _play_narration("Dan berakhir bersamanya di alam ketenangan.")
			await _play_narration("Jadi, siapa Ashy yang kutemui sebelumnya?")
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

func _show_dialogue_box():
	if dialogue_box.visible and dialogue_box.modulate.a >= 1.0: return
	dialogue_box.show()
	var tw = create_tween()
	tw.tween_property(dialogue_box, "modulate:a", 1.0, 0.25)

func _hide_dialogue_box():
	if not dialogue_box.visible: return
	var tw = create_tween()
	tw.tween_property(dialogue_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(dialogue_box.hide)
