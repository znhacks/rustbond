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

var act_points: int = 0 # Default 0, Max 5
var comfort_uses_left: int = 2 # Default 2 uses
var rage_immunity_turns: int = 0 # Sisa turn kebal Rage
var cd_pat: int = 0 # Sisa turn cooldown Pat Pat (1 turn)
var cd_physical: int = 0 # Sisa turn cooldown Physical (2 turns)

var act_container: VBoxContainer
var act_label: Label
var act_button: Button
var act_layer: CanvasLayer

var questions = []
var current_question_idx = 0
var phase = 0

var consecutive_correct = 0

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _get_lang() -> String:
	if has_node("/root/SaveManager"):
		return get_node("/root/SaveManager").get_language()
	return "en"

func _t(en_text: String, id_text: String) -> String:
	return id_text if _get_lang() == "id" else en_text

func add_act_points(amount: int):
	act_points = min(5, act_points + amount)
	_update_act_ui()

func _process_turn_step():
	if rage_immunity_turns > 0:
		rage_immunity_turns -= 1
	if cd_pat > 0:
		cd_pat -= 1
	if cd_physical > 0:
		cd_physical -= 1
	_update_act_ui()

func _apply_rage_penalty(amount: int) -> bool:
	if rage_immunity_turns > 0:
		# Player is immune to Rage penalty!
		return false
	rage_bar.value += amount
	return true

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
	
	# Act System Container
	act_container = VBoxContainer.new()
	act_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_container.position = Vector2(20, 160)
	act_container.add_theme_constant_override("separation", 6)
	
	act_label = Label.new()
	act_label.add_theme_font_override("font", font_vt323)
	act_label.add_theme_font_size_override("font_size", 22)
	act_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	act_container.add_child(act_label)
	
	act_button = Button.new()
	act_button.custom_minimum_size = Vector2(250, 38)
	_apply_act_button_style(act_button)
	act_button.pressed.connect(_on_act_button_pressed)
	act_container.add_child(act_button)
	
	# Skip Indicator font
	var skip_label = skip_indicator.get_node_or_null("HBoxContainer/SkipIndicator")
	if skip_label:
		skip_label.add_theme_font_override("font", font_vt323)
		skip_label.add_theme_font_size_override("font_size", 22)
	
	$CanvasLayer.add_child(love_container)
	$CanvasLayer.add_child(rage_container)
	$CanvasLayer.add_child(act_container)
	_update_act_ui()

func _update_act_ui():
	var is_id = SaveManager.get_language() == "id"
	var txt = "Poin Tindakan: " + str(act_points) + "/5" if is_id else "Act Points: " + str(act_points) + "/5"
	if rage_immunity_turns > 0:
		txt += " [KEBAL: " + str(rage_immunity_turns) + "]" if is_id else " [IMMUNE: " + str(rage_immunity_turns) + "]"
	act_label.text = txt
	act_button.text = "ACT / TINDAKAN" if is_id else "ACT / ACTION"

func _apply_act_button_style(btn: Button):
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.3, 0.4, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.8, 1.0, 0.9)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb)

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

func _unhandled_input(event):
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
	_process_turn_step()
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
		if rage_immunity_turns > 0:
			var imm_msg = _t("Ashy glares in anger, but your Comfort aura keeps her calm! (Rage Immunity Active)", "Ashy menatap marah, tetapi aura Comfort menenangkannya! (Kekebalan Rage Aktif)")
			_play_dialogue_line("Ashy", imm_msg)
			phase = 200
		else:
			rage_bar.value = 100
			_check_rage_or_jumpscare()
			return
		
	elif ans["efek"] == "NORMAL_WRONG":
		consecutive_correct = 0
		var took_rage = _apply_rage_penalty(20)
		if love_bar.value > 0:
			love_bar.value = max(0, love_bar.value - 10)
		_change_character_sprite(tex_ashy_angry)
		
		if rage_bar.value >= 100:
			_check_rage_or_jumpscare()
			return
		else:
			if not took_rage:
				var imm_msg = _t("Ashy glares furiously, but your Comfort aura absorbs her rage! (Rage Immune)", "Ashy menatap marah, tetapi aura Comfort menyerap amarahnya! (Kebal Rage)")
				_play_dialogue_line("Ashy", imm_msg)
			else:
				var wrong_lines_id = [
					"Hmph! Kamu beneran gak peka banget sih!",
					"Ih, jawabanmu keterlaluan banget!",
					"Ugh! Bikin bete aja, tidak peka!"
				]
				var wrong_lines_en = [
					"Hmph! You're so insensitive!",
					"Ugh, that answer is awful!",
					"Hmph! You're making me so annoyed!"
				]
				var msg = wrong_lines_id.pick_random() if SaveManager.get_language() == "id" else wrong_lines_en.pick_random()
				_play_dialogue_line("Ashy", msg)
			phase = 200
			
	elif ans["efek"] == "NORMAL_HALF":
		consecutive_correct = 0
		var took_rage = _apply_rage_penalty(10)
		if love_bar.value > 0:
			love_bar.value = max(0, love_bar.value - 5)
		_change_character_sprite(tex_ashy_angry)
		
		if rage_bar.value >= 100:
			_check_rage_or_jumpscare()
			return
		else:
			if not took_rage:
				var imm_msg = _t("Ashy seems irritated, but your Comfort aura keeps her calm! (Rage Immune)", "Ashy terlihat bete, tetapi aura Comfort menenangkannya! (Kebal Rage)")
				_play_dialogue_line("Ashy", imm_msg)
			else:
				var half_lines_id = [
					"Ih, apasih... jawaban kamu kok gitu...",
					"Ugh, kurang peka banget deh kamu...",
					"Hmph... kok rasanya kurang sreg ya."
				]
				var half_lines_en = [
					"Ugh, really? What kind of answer is that...",
					"Hmph... you could be a lot more thoughtful.",
					"Uh, I don't feel like that's a good answer..."
				]
				var msg = half_lines_id.pick_random() if SaveManager.get_language() == "id" else half_lines_en.pick_random()
				_play_dialogue_line("Ashy", msg)
			phase = 200
			
	elif ans["efek"] == "NORMAL_CORRECT":
		consecutive_correct += 1
		add_act_points(1)
		_change_character_sprite(tex_ashy_happy)
		
		if consecutive_correct >= 3:
			consecutive_correct = 0
			love_bar.value += 20
			if love_bar.value >= 100:
				_good_ending()
				return
			else:
				var sweet_msg = _t("Wh-what a sweet answer... I can feel we are getting closer! (+1 Act Point)", "A-apa... manis sekali jawabanmu... aku merasa kita semakin dekat! (+1 Poin Tindakan)")
				_play_dialogue_line("Ashy", sweet_msg)
				phase = 200
		else:
			var good_msg = _t("Good answer. (+1 Act Point)", "Jawaban yang bagus. (+1 Poin Tindakan)")
			_play_dialogue_line("Ashy", good_msg)
			phase = 200

func _on_act_button_pressed():
	if act_layer and is_instance_valid(act_layer):
		act_layer.queue_free()
		
	act_layer = CanvasLayer.new()
	act_layer.layer = 95
	add_child(act_layer)
	
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.85)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	act_layer.add_child(bg_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	act_layer.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 460)
	var sb_p = StyleBoxFlat.new()
	sb_p.bg_color = Color(0.06, 0.12, 0.16, 0.95)
	sb_p.border_width_left = 3
	sb_p.border_width_top = 3
	sb_p.border_width_right = 3
	sb_p.border_width_bottom = 3
	sb_p.border_color = Color(0.2, 0.7, 0.9, 0.9)
	sb_p.corner_radius_top_left = 12
	sb_p.corner_radius_top_right = 12
	sb_p.corner_radius_bottom_right = 12
	sb_p.corner_radius_bottom_left = 12
	sb_p.content_margin_left = 25
	sb_p.content_margin_right = 25
	sb_p.content_margin_top = 20
	sb_p.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb_p)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var is_id = SaveManager.get_language() == "id"
	
	var title = Label.new()
	title.text = "MENU TINDAKAN / ACT" if is_id else "ACTION MENU / ACT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_vt323)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	vbox.add_child(title)
	
	var pts_lbl = Label.new()
	var info_str = "Poin: " + str(act_points) + "/5 | Sisa Comfort: " + str(comfort_uses_left) if is_id else "Points: " + str(act_points) + "/5 | Comfort Uses: " + str(comfort_uses_left)
	if rage_immunity_turns > 0:
		info_str += " [KEBAL: " + str(rage_immunity_turns) + " Soal]" if is_id else " [IMMUNE: " + str(rage_immunity_turns) + " Turns]"
	pts_lbl.text = info_str
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_lbl.add_theme_font_override("font", font_vt323)
	pts_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(pts_lbl)
	
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	# Action 1: Pujian (1 AP, CD 0, Rage -5)
	var can1 = act_points >= 1
	var btn1 = Button.new()
	btn1.text = "1. Pujian / Praise (1 AP -> Rage -5)" if is_id else "1. Praise (1 AP -> Rage -5)"
	btn1.custom_minimum_size = Vector2(480, 44)
	_apply_act_option_style(btn1, can1)
	btn1.pressed.connect(func(): _execute_act_action(1))
	vbox.add_child(btn1)
	
	# Action 2: Pat Pat (2 AP, CD 1 turn, Rage -10)
	var can2 = act_points >= 2 and cd_pat == 0
	var btn2_txt = "2. Pat Pat / Head Pat (2 AP -> Rage -10)" if is_id else "2. Head Pat (2 AP -> Rage -10)"
	if cd_pat > 0:
		btn2_txt += " [CD: " + str(cd_pat) + " Soal]" if is_id else " [CD: " + str(cd_pat) + " Turn]"
	var btn2 = Button.new()
	btn2.text = btn2_txt
	btn2.custom_minimum_size = Vector2(480, 44)
	_apply_act_option_style(btn2, can2)
	btn2.pressed.connect(func(): _execute_act_action(2))
	vbox.add_child(btn2)
	
	# Action 3: Physical (3 AP, CD 2 turns, Rage -15)
	var can3 = act_points >= 3 and cd_physical == 0
	var btn3_txt = "3. Sentuhan Fisik / Physical (3 AP -> Rage -15)" if is_id else "3. Physical Affection (3 AP -> Rage -15)"
	if cd_physical > 0:
		btn3_txt += " [CD: " + str(cd_physical) + " Soal]" if is_id else " [CD: " + str(cd_physical) + " Turns]"
	var btn3 = Button.new()
	btn3.text = btn3_txt
	btn3.custom_minimum_size = Vector2(480, 44)
	_apply_act_option_style(btn3, can3)
	btn3.pressed.connect(func(): _execute_act_action(3))
	vbox.add_child(btn3)
	
	# Action 4: Ultimate COMFORT (5 AP, comfort_uses_left > 0, rage > 50, love >= 30) -> Kebal Rage 3 Soal
	var can_comfort = (comfort_uses_left > 0) and (act_points >= 5) and (rage_bar.value > 50) and (love_bar.value >= 30)
	var btn4_txt = "★ COMFORT Ultimate (5 AP -> Kebal Rage 3 Soal) [Sisa: " + str(comfort_uses_left) + "]" if is_id else "★ COMFORT Ultimate (5 AP -> Rage Immune 3 Turns) [Left: " + str(comfort_uses_left) + "]"
	var btn4 = Button.new()
	btn4.text = btn4_txt
	btn4.custom_minimum_size = Vector2(480, 46)
	_apply_comfort_option_style(btn4, can_comfort)
	btn4.pressed.connect(func(): _execute_act_action(4))
	vbox.add_child(btn4)
	
	var btn_back = Button.new()
	btn_back.text = "Kembali" if is_id else "Back"
	btn_back.custom_minimum_size = Vector2(480, 38)
	_apply_act_option_style(btn_back, true)
	btn_back.pressed.connect(func(): act_layer.queue_free())
	vbox.add_child(btn_back)

func _apply_act_option_style(btn: Button, available: bool):
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0) if available else Color(0.5, 0.5, 0.5, 0.8))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.25, 0.32, 0.9) if available else Color(0.15, 0.15, 0.18, 0.8)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.8, 1.0, 0.9) if available else Color(0.3, 0.3, 0.35, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", sb)

func _apply_comfort_option_style(btn: Button, available: bool):
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0) if available else Color(0.6, 0.55, 0.4, 0.7))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.3, 0.05, 0.95) if available else Color(0.18, 0.16, 0.12, 0.8)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.8, 0.2, 0.9) if available else Color(0.4, 0.35, 0.2, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", sb)

func _execute_act_action(action_id: int):
	var is_id = SaveManager.get_language() == "id"
	
	if action_id == 1: # Pujian / Praise (1 AP, CD 0, Rage -5)
		if act_points < 1:
			_play_dialogue_line("System", "Poin Tindakan tidak cukup! (Butuh 1 AP)" if is_id else "Not enough Act Points! (Needs 1 AP)")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		act_points -= 1
		rage_bar.value = max(0, rage_bar.value - 5)
		_update_act_ui()
		if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
		
		dialogue_box.show()
		_change_character_sprite(tex_ashy_talk)
		var msg1 = _t("Ashy blushes upon hearing your compliment... (Rage -5)", "Ashy tersipu malu mendengarkan pujianmu... (Rage -5)")
		_play_dialogue_line("System", msg1)
		
	elif action_id == 2: # Pat Pat (2 AP, CD 1 turn, Rage -10)
		if act_points < 2:
			_play_dialogue_line("System", "Poin Tindakan tidak cukup! (Butuh 2 AP)" if is_id else "Not enough Act Points! (Needs 2 AP)")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		if cd_pat > 0:
			_play_dialogue_line("System", "Pat Pat sedang Cooldown! (Sisa " + str(cd_pat) + " Soal)" if is_id else "Pat Pat is on Cooldown! (" + str(cd_pat) + " Turn left)")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		act_points -= 2
		cd_pat = 1 # Cooldown 1 turn
		rage_bar.value = max(0, rage_bar.value - 10)
		_update_act_ui()
		if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
		
		dialogue_box.show()
		_change_character_sprite(tex_ashy_happy)
		var msg2 = _t("Ashy closes her eyes, enjoying the head pats... (Rage -10)", "Ashy memejamkan mata menikmati usapan di kepalanya... (Rage -10)")
		_play_dialogue_line("System", msg2)
		
	elif action_id == 3: # Physical (3 AP, CD 2 turns, Rage -15)
		if act_points < 3:
			_play_dialogue_line("System", "Poin Tindakan tidak cukup! (Butuh 3 AP)" if is_id else "Not enough Act Points! (Needs 3 AP)")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		if cd_physical > 0:
			_play_dialogue_line("System", "Sentuhan Fisik sedang Cooldown! (Sisa " + str(cd_physical) + " Soal)" if is_id else "Physical is on Cooldown! (" + str(cd_physical) + " Turns left)")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		act_points -= 3
		cd_physical = 2 # Cooldown 2 turns
		rage_bar.value = max(0, rage_bar.value - 15)
		_update_act_ui()
		if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
		
		dialogue_box.show()
		_change_character_sprite(tex_ashy_happy)
		var msg3 = _t("Your warm physical touch gently calms Ashy's rage away... (Rage -15)", "Sentuhan hangatmu membuat kemarahan Ashy perlahan mereda... (Rage -15)")
		_play_dialogue_line("System", msg3)
		
	elif action_id == 4: # COMFORT Ultimate
		if comfort_uses_left <= 0:
			_play_dialogue_line("System", "Penggunaan COMFORT sudah habis!" if is_id else "COMFORT uses exhausted!")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		if act_points < 5:
			_play_dialogue_line("System", "Butuh 5 AP untuk menggunakan COMFORT!" if is_id else "Needs 5 AP to use COMFORT!")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		if rage_bar.value <= 50:
			_play_dialogue_line("System", "COMFORT hanya bisa aktif saat Rage > 50%!" if is_id else "COMFORT requires Rage > 50%!")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
		if love_bar.value < 30:
			_play_dialogue_line("System", "COMFORT hanya bisa aktif saat Love >= 30%!" if is_id else "COMFORT requires Love >= 30%!")
			if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
			return
			
		act_points -= 5
		comfort_uses_left -= 1
		rage_immunity_turns = 3 # Kebal penalti Rage selama 3 soal ke depan!
		_update_act_ui()
		if act_layer and is_instance_valid(act_layer): act_layer.queue_free()
		
		dialogue_box.show()
		_change_character_sprite(tex_ashy_happy)
		var msg4 = _t("You embrace Ashy with profound comfort... Ashy gains Rage Immunity for 3 questions! (Rage Immunity Active)", "Kamu memberikan kenyamanan mendalam kepada Ashy... Ashy menjadi kebal amarah selama 3 soal ke depan! (Kebal Rage Aktif)")
		_play_dialogue_line("System", msg4)

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
	if act_layer and is_instance_valid(act_layer) and act_layer.is_inside_tree():
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
	choice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if act_container and is_instance_valid(act_container):
		$CanvasLayer.move_child(act_container, -1)

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
