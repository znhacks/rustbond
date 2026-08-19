extends Control

var orig_btn_colors = {}
var char_tween : Tween
var bg_start_pos : Vector2
var screen_size : Vector2

var tex_angry = preload("res://assets/Ashy/ashy_tittle2.png")

func _ready():
	TransitionManager.quit_attempted.connect(_scare_player)
	
	setup_bgm()
	
	# 1. Setup Vignette Effect (softer)
	setup_vignette()
	
	# Pastikan Container tidak nge-block klik mouse ke Character yang ada di belakangnya
	$HBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/LeftSpacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/RightMargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("ColorRect"):
		$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/RightMargin/VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. Wait one frame so UI layouts and sizes are calculated
	await get_tree().process_frame
	
	# 3. Setup Horror Buttons (Option B)
	var buttons = [
		$HBoxContainer/RightMargin/VBoxContainer/PlayButton,
		$HBoxContainer/RightMargin/VBoxContainer/OptionsButton,
		$HBoxContainer/RightMargin/VBoxContainer/LibraryButton,
		$HBoxContainer/RightMargin/VBoxContainer/ExitButton
	]
	
	for btn in buttons:
		btn.focus_mode = Control.FOCUS_NONE
		btn.pivot_offset = btn.size / 2.0
		
		apply_horror_button_style(btn)
		
		orig_btn_colors[btn] = Color(1, 1, 1, 1.0)
		btn.modulate = orig_btn_colors[btn]
		
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
	
	# 4. Setup Dynamic Background (Parallax)
	setup_background_parallax()
	
	# 5. Setup Character Animation and Glitch
	animate_character()
	setup_character_glitch()
	
	# 6. Setup Title Gradient and Glint
	setup_title_effects()
	
	_update_menu_labels()

func _update_menu_labels():
	var lang = SaveManager.get_language()
	var play_btn = $HBoxContainer/RightMargin/VBoxContainer/PlayButton
	var lang_btn = $HBoxContainer/RightMargin/VBoxContainer/OptionsButton
	var lib_btn = $HBoxContainer/RightMargin/VBoxContainer/LibraryButton
	var exit_btn = $HBoxContainer/RightMargin/VBoxContainer/ExitButton
	var subtitle = $HBoxContainer/RightMargin/VBoxContainer/Subtitle
	
	if lang == "id":
		play_btn.text = "MAIN"
		lang_btn.text = "BAHASA"
		lib_btn.text = "GALERI"
		exit_btn.text = "KELUAR"
		subtitle.text = "mengapa karat ini ingin bersatu denganmu?."
	else:
		play_btn.text = "PLAY"
		lang_btn.text = "LANGUAGE"
		lib_btn.text = "LIBRARY"
		exit_btn.text = "EXIT"
		subtitle.text = "why the rust wanted to bonds with you?."

func _on_play_button_pressed():
	TransitionManager.play_splash()
	TransitionManager.transition_to_scene("res://Beginning.tscn")

func _on_options_button_pressed():
	TransitionManager.play_splash()
	_show_language_ui()

func _on_library_button_pressed():
	TransitionManager.play_splash()
	_show_library_ui()

func _on_exit_button_pressed():
	TransitionManager.play_splash()
	TransitionManager._show_quit_warning(TransitionManager.msg_exit)

var lang_layer: CanvasLayer

func _show_language_ui():
	if lang_layer and is_instance_valid(lang_layer):
		lang_layer.queue_free()
		
	lang_layer = CanvasLayer.new()
	lang_layer.layer = 95
	add_child(lang_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.02, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	lang_layer.add_child(dim)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lang_layer.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.04, 0.04, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.75, 0.15, 0.15, 0.9)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 25
	sb.content_margin_right = 25
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "SELECT LANGUAGE / PILIH BAHASA"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", font_helpme)
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	vbox.add_child(title_lbl)
	
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	var btn_en = Button.new()
	btn_en.text = "English (Default)  [ Active ]" if SaveManager.get_language() == "en" else "English (Default)"
	btn_en.custom_minimum_size = Vector2(360, 55)
	_apply_retro_button_style(btn_en, Color(0.8, 0.2, 0.2) if SaveManager.get_language() == "en" else Color(0.4, 0.4, 0.4))
	btn_en.pressed.connect(func():
		SaveManager.set_language("en")
		_update_menu_labels()
		lang_layer.queue_free()
	)
	vbox.add_child(btn_en)
	
	var btn_id = Button.new()
	btn_id.text = "Bahasa Indonesia  [ Aktif ]" if SaveManager.get_language() == "id" else "Bahasa Indonesia"
	btn_id.custom_minimum_size = Vector2(360, 55)
	_apply_retro_button_style(btn_id, Color(0.8, 0.2, 0.2) if SaveManager.get_language() == "id" else Color(0.4, 0.4, 0.4))
	btn_id.pressed.connect(func():
		SaveManager.set_language("id")
		_update_menu_labels()
		lang_layer.queue_free()
	)
	vbox.add_child(btn_id)
	
	var btn_back = Button.new()
	btn_back.text = "Back / Kembali"
	btn_back.custom_minimum_size = Vector2(360, 45)
	_apply_retro_button_style(btn_back, Color(0.5, 0.5, 0.5))
	btn_back.pressed.connect(func(): lang_layer.queue_free())
	vbox.add_child(btn_back)

var library_layer: CanvasLayer

func _show_library_ui():
	if library_layer and is_instance_valid(library_layer):
		library_layer.queue_free()
		
	library_layer = CanvasLayer.new()
	library_layer.layer = 90
	add_child(library_layer)
	
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.04, 0.02, 0.02, 0.94)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	library_layer.add_child(bg_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	library_layer.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1050, 560)
	
	var sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = Color(0.08, 0.04, 0.04, 0.92)
	sb_panel.border_width_left = 3
	sb_panel.border_width_top = 3
	sb_panel.border_width_right = 3
	sb_panel.border_width_bottom = 3
	sb_panel.border_color = Color(0.7, 0.15, 0.15, 0.9)
	sb_panel.corner_radius_top_left = 12
	sb_panel.corner_radius_top_right = 12
	sb_panel.corner_radius_bottom_right = 12
	sb_panel.corner_radius_bottom_left = 12
	sb_panel.content_margin_left = 25
	sb_panel.content_margin_right = 25
	sb_panel.content_margin_top = 20
	sb_panel.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb_panel)
	center.add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)
	
	var is_id = SaveManager.get_language() == "id"
	var title_lbl = Label.new()
	title_lbl.text = "GALERI ENDING" if is_id else "ENDING GALLERY & LIBRARY"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", font_helpme)
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	main_vbox.add_child(title_lbl)
	
	var hsep = HSeparator.new()
	main_vbox.add_child(hsep)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 370)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 25)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_hbox)
	
	_populate_library_cards(cards_hbox)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(bottom_hbox)
	
	var btn_clear = Button.new()
	btn_clear.text = "Hapus Galeri" if is_id else "Clear Library"
	btn_clear.custom_minimum_size = Vector2(220, 50)
	_apply_retro_button_style(btn_clear, Color(0.8, 0.2, 0.2))
	btn_clear.pressed.connect(func(): _confirm_clear_library(cards_hbox))
	bottom_hbox.add_child(btn_clear)
	
	var btn_back = Button.new()
	btn_back.text = "Kembali" if is_id else "Back"
	btn_back.custom_minimum_size = Vector2(220, 50)
	_apply_retro_button_style(btn_back, Color(0.5, 0.5, 0.5))
	btn_back.pressed.connect(func(): library_layer.queue_free())
	bottom_hbox.add_child(btn_back)

func _populate_library_cards(container: HBoxContainer):
	for c in container.get_children():
		c.queue_free()
		
	var is_love_unlocked = SaveManager.is_unlocked("true_love")
	var is_locked_unlocked = SaveManager.is_unlocked("locked_up")
	var is_safe_unlocked = SaveManager.is_unlocked("safe_ending")
	var is_id = SaveManager.get_language() == "id"
	
	# --- PENGATURAN FOTO ENDING 1: TRUE LOVE ---
	var t1 = "1. Cinta Sejati" if is_id else "1. True Love"
	var d1 = "Kamu berhasil, dia menghentikan wabah dunia" if is_id else "You did it, she's stop the world plague"
	var card1 = _create_ending_card(
		t1,
		d1 if is_love_unlocked else "???",
		preload("res://assets/Ashy/ashy_under.png"),
		is_love_unlocked,
		Vector2(0, 0),
		Vector2(1.0, 1.0)
	)
	container.add_child(card1)
	
	# --- PENGATURAN FOTO ENDING 2: LOCKED UP ---
	var t2 = "2. Terkunci" if is_id else "2. Locked Up"
	var d2 = "Kamu berhasil? Mungkin..." if is_id else "You did it? Maybe..."
	var card2 = _create_ending_card(
		t2,
		d2 if is_locked_unlocked else "???",
		preload("res://assets/Ashy/ashy_closeup.png"),
		is_locked_unlocked,
		Vector2(0, 0),
		Vector2(1.0, 1.0)
	)
	container.add_child(card2)

	# --- PENGATURAN FOTO ENDING 3: SAFE ENDING ---
	var t3 = "3. Ending Aman" if is_id else "3. Safe Ending"
	var d3 = "Selamat, kamu berhasil menghindari mimpi buruk ini!" if is_id else "Congratulations, you avoided the nightmare!"
	var card3 = _create_ending_card(
		t3,
		d3 if is_safe_unlocked else "???",
		preload("res://assets/UI/front_door.jpg"),
		is_safe_unlocked,
		Vector2(0, 0),
		Vector2(1.0, 1.0)
	)
	container.add_child(card3)

func _create_ending_card(title: String, desc: String, texture: Texture2D, unlocked: bool, img_offset: Vector2 = Vector2.ZERO, img_scale: Vector2 = Vector2.ONE) -> Control:
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(360, 350)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.02, 0.88)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.5, 0.15, 0.15, 0.8) if unlocked else Color(0.25, 0.25, 0.25, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 15
	sb.content_margin_right = 15
	sb.content_margin_top = 15
	sb.content_margin_bottom = 15
	card_panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card_panel.add_child(vbox)
	
	# Bingkai tempat foto ditampilkan (Ukuran default: 370 x 200)
	var img_container = Control.new()
	img_container.custom_minimum_size = Vector2(370, 200)
	img_container.clip_contents = true
	vbox.add_child(img_container)
	
	var img_rect = TextureRect.new()
	img_rect.position = img_offset
	img_rect.size = Vector2(370, 200)
	img_rect.scale = img_scale
	img_rect.texture = texture
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	if not unlocked:
		img_rect.modulate = Color(0.05, 0.05, 0.05, 0.8)
	else:
		img_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
	img_container.add_child(img_rect)
	
	if not unlocked:
		var lock_lbl = Label.new()
		lock_lbl.text = "[ LOCKED ]"
		lock_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_override("font", font_vt323)
		lock_lbl.add_theme_font_size_override("font_size", 32)
		lock_lbl.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2, 0.9))
		img_container.add_child(lock_lbl)
		
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_override("font", font_vt323)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0) if unlocked else Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", font_vt323)
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0) if unlocked else Color(0.4, 0.4, 0.4, 1.0))
	vbox.add_child(desc_lbl)
	
	return card_panel

func _confirm_clear_library(cards_hbox: HBoxContainer):
	var confirm_layer = CanvasLayer.new()
	confirm_layer.layer = 100
	add_child(confirm_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(dim)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 240)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.02, 0.02, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.9, 0.2, 0.2, 0.9)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 25
	sb.content_margin_right = 25
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 25)
	panel.add_child(vbox)
	
	var msg_lbl = Label.new()
	msg_lbl.text = "Are you sure? This will delete your ending progress"
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_override("font", font_vt323)
	msg_lbl.add_theme_font_size_override("font_size", 28)
	msg_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	vbox.add_child(msg_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(btn_hbox)
	
	var btn_yes = Button.new()
	btn_yes.text = "YES"
	btn_yes.custom_minimum_size = Vector2(140, 45)
	_apply_retro_button_style(btn_yes, Color(0.85, 0.15, 0.15))
	btn_yes.pressed.connect(func():
		SaveManager.clear_library()
		_populate_library_cards(cards_hbox)
		confirm_layer.queue_free()
	)
	btn_hbox.add_child(btn_yes)
	
	var btn_no = Button.new()
	btn_no.text = "CANCEL"
	btn_no.custom_minimum_size = Vector2(140, 45)
	_apply_retro_button_style(btn_no, Color(0.4, 0.4, 0.4))
	btn_no.pressed.connect(func(): confirm_layer.queue_free())
	btn_hbox.add_child(btn_no)

func _apply_retro_button_style(btn: Button, border_col: Color):
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7, 1.0))
	
	var sb_norm = StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.12, 0.04, 0.04, 0.88)
	sb_norm.border_width_left = 2
	sb_norm.border_width_top = 2
	sb_norm.border_width_right = 2
	sb_norm.border_width_bottom = 2
	sb_norm.border_color = border_col
	sb_norm.corner_radius_top_left = 6
	sb_norm.corner_radius_top_right = 6
	sb_norm.corner_radius_bottom_right = 6
	sb_norm.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb_norm)
	
	var sb_hov = sb_norm.duplicate()
	sb_hov.bg_color = Color(0.22, 0.08, 0.08, 0.95)
	sb_hov.border_color = border_col.lightened(0.3)
	btn.add_theme_stylebox_override("hover", sb_hov)

func _process(delta):
	# Parallax Background Logic
	if $Background:
		var mouse_pos = get_viewport().get_mouse_position()
		# Offset towards the mouse slightly (inverted for natural parallax)
		var offset = (mouse_pos - (screen_size / 2.0)) * 0.03
		# Smoothly lerp towards target position
		var target_pos = bg_start_pos - offset
		$Background.position = $Background.position.lerp(target_pos, delta * 4.0)

func setup_bgm():
	var bgm_player = AudioStreamPlayer.new()
	var bgm_stream = preload("res://assets/Audio/Faded Music Box.mp3")
	bgm_player.stream = bgm_stream
	# Pastikan musik di-loop setelah selesai
	bgm_player.finished.connect(func(): bgm_player.play())
	add_child(bgm_player)
	bgm_player.play()

func setup_vignette():
	var vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_code = """
	shader_type canvas_item;
	uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	uniform float multiplier = 0.3; // Dikurangi agar lebih soft
	uniform float softness = 1.0; // Diperhalus ujungnya
	uniform float opacity = 0.7; // Transparansi keseluruhan dikurangi
	
	void fragment() {
		float val = distance(vec2(0.5), UV);
		val = val * multiplier;
		float vig = smoothstep(0.5, 0.5 - softness, val);
		COLOR = vec4(color.rgb, (1.0 - vig) * opacity);
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", Color(0, 0, 0, 1))
	mat.set_shader_parameter("multiplier", 0.4)
	mat.set_shader_parameter("softness", 1.0)
	mat.set_shader_parameter("opacity", 0.6)
	
	vignette.material = mat
	vignette.z_index = 100
	add_child(vignette)

func setup_background_parallax():
	var bg = $Background
	screen_size = get_viewport_rect().size
	
	# Buat agar background sedikit lebih besar dari layar untuk ruang gerak parallax
	bg.scale = Vector2(1.08, 1.08)
	bg.pivot_offset = bg.size / 2.0
	
	# Simpan posisi awal agar kita bisa lerp dari titik ini
	bg_start_pos = bg.position

func animate_character():
	var char_node = $Character
	var base_scale = char_node.scale
	
	char_tween = create_tween().set_loops()
	char_tween.tween_property(char_node, "scale", base_scale * 1.02, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	char_tween.tween_property(char_node, "scale", base_scale * 0.98, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func setup_character_glitch():
	var char_node = $Character
	
	var glitch_shader = """
	shader_type canvas_item;
	
	uniform float glitch_intensity = 0.0;
	uniform vec4 color_red : source_color = vec4(0.8, 0.0, 0.0, 1.0);
	uniform vec4 color_black : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	float rand(vec2 co){
		return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
	}
	
	void fragment() {
		vec2 uv = UV;
		float time = TIME;
		
		// Efek aneh: Memotong gambar menjadi slice horizontal dan menggesernya secara ekstrim
		if (glitch_intensity > 0.0) {
			float slice_y = floor(uv.y * 30.0); // 30 potongan horizontal
			float r = rand(vec2(time * 5.0, slice_y));
			if (r > 0.4) {
				uv.x += (rand(vec2(time, slice_y)) - 0.5) * 0.6 * glitch_intensity;
			}
			// Kadang-kadang stretch secara vertikal juga
			if (rand(vec2(time * 2.0, uv.x)) > 0.8) {
				uv.y += (rand(vec2(time, uv.x)) - 0.5) * 0.2 * glitch_intensity;
			}
		}
		
		vec4 tex = texture(TEXTURE, uv);
		
		// Tambahkan noise warna merah dan hitam
		if (glitch_intensity > 0.0 && tex.a > 0.0) {
			float noise_red = rand(vec2(time * 3.0, uv.x));
			float noise_black = rand(vec2(time * 1.5, uv.y));
			
			if (noise_red > 0.6) {
				tex.rgb = mix(tex.rgb, color_red.rgb, 0.9 * glitch_intensity);
			} else if (noise_black > 0.5) {
				tex.rgb = mix(tex.rgb, color_black.rgb, 1.0 * glitch_intensity);
			}
		}
		
		COLOR = tex;
	}
	"""
	
	var shader = Shader.new()
	shader.code = glitch_shader
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("glitch_intensity", 0.0)
	char_node.material = mat
	
	var timer = Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(_on_glitch_timeout)
	add_child(timer)

func _on_glitch_timeout():
	var char_node = $Character
	if char_node.material == null: return
	
	var tween = create_tween()
	tween.tween_method(_set_glitch_intensity, 0.0, 1.0, 0.1).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_method(_set_glitch_intensity, 1.0, 0.2, 0.05)
	tween.tween_method(_set_glitch_intensity, 0.2, 0.9, 0.05)
	tween.tween_method(_set_glitch_intensity, 0.9, 0.0, 0.15)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var char_node = $Character
		var local_mouse_pos = char_node.get_local_mouse_position()
		var tex_size = char_node.texture.get_size()
		var rect = Rect2(-tex_size / 2.0, tex_size)
		if rect.has_point(local_mouse_pos):
			_on_glitch_timeout()

func _set_glitch_intensity(val: float):
	var char_node = $Character
	if char_node.material:
		char_node.material.set_shader_parameter("glitch_intensity", val)
		
	# Distorsi fisik aneh pada node itu sendiri
	if val > 0.0:
		char_node.rotation = randf_range(-0.2, 0.2) * val
		char_node.scale = char_node.scale * Vector2(1.0 + randf_range(-0.1, 0.1), 1.0 + randf_range(-0.1, 0.1))
	else:
		char_node.rotation = 0.0

var font_helpme = preload("res://assets/Fonts/HelpMe.ttf")
var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func apply_horror_button_style(btn: Button):
	btn.add_theme_font_override("font", font_helpme)
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.1, 0.1, 1.0))
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	btn.add_theme_constant_override("shadow_offset_x", 3)
	btn.add_theme_constant_override("shadow_offset_y", 3)
	
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.02, 0.02, 0.85)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(0.65, 0.12, 0.12, 0.85)
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_right = 8
	sb_normal.corner_radius_bottom_left = 8
	sb_normal.shadow_color = Color(0.5, 0.0, 0.0, 0.35)
	sb_normal.shadow_size = 6
	btn.add_theme_stylebox_override("normal", sb_normal)
	
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.25, 0.04, 0.04, 0.95)
	sb_hover.border_color = Color(0.95, 0.18, 0.18, 1.0)
	sb_hover.shadow_color = Color(0.9, 0.1, 0.1, 0.6)
	sb_hover.shadow_size = 12
	btn.add_theme_stylebox_override("hover", sb_hover)
	
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.35, 0.05, 0.05, 1.0)
	sb_pressed.border_color = Color(1.0, 0.2, 0.2, 1.0)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

func _on_btn_hover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "modulate", Color(1.3, 0.8, 0.8, 1.0), 0.2)
	
func _on_btn_unhover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "modulate", orig_btn_colors[btn], 0.25)

func _scare_player():
	
	var char_node = $Character
	char_node.texture = tex_angry
	
	# Memicu glitch ekstrim sesaat
	var tween = create_tween()
	tween.tween_method(_set_glitch_intensity, 0.8, 1.8, 0.1)
	tween.tween_method(_set_glitch_intensity, 1.8, 0.0, 0.4)

func setup_title_effects():
	var title = $HBoxContainer/RightMargin/VBoxContainer/Title
	var subtitle = $HBoxContainer/RightMargin/VBoxContainer/Subtitle
	
	var shader_code = """
	shader_type canvas_item;
	
	uniform vec4 color_top : source_color = vec4(1.0, 0.3, 0.3, 1.0);
	uniform vec4 color_bottom : source_color = vec4(0.3, 0.0, 0.0, 1.0);
	uniform vec2 node_size = vec2(500.0, 100.0);
	uniform float glint_progress = -0.5;
	
	varying vec2 local_pos;
	
	void vertex() {
		local_pos = VERTEX;
	}
	
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		if (tex.a < 0.01) {
			discard;
		}
		
		// Deteksi apakah ini pass teks, outline, atau shadow berdasarkan warna input (COLOR)
		if (COLOR.r < 0.6) {
			// Pass outline/shadow (gelap/hitam)
			COLOR = vec4(COLOR.rgb, tex.a * COLOR.a);
		} else {
			// Pass teks utama (terang)
			vec2 n_pos = local_pos / node_size;
			
			// Gradasi Vertikal dari atas ke bawah
			vec3 grad = mix(color_top.rgb, color_bottom.rgb, n_pos.y);
			
			// Efek Glint putih menyapu menyilang
			float diag = (n_pos.x + (1.0 - n_pos.y)) / 2.0;
			float dist = abs(diag - glint_progress);
			float glint = smoothstep(0.15, 0.0, dist);
			
			vec3 final_color = mix(grad, vec3(1.0), glint * 0.85);
			
			COLOR = vec4(final_color, tex.a * COLOR.a);
		}
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	# Material untuk Title
	var mat_title = ShaderMaterial.new()
	mat_title.shader = shader
	mat_title.set_shader_parameter("node_size", title.size)
	title.material = mat_title
	title.resized.connect(func(): mat_title.set_shader_parameter("node_size", title.size))
	
	# Material untuk Subtitle (merah bergradasi dengan pendaran merah)
	subtitle.add_theme_font_override("font", font_vt323)
	subtitle.add_theme_font_size_override("font_size", 28)
	
	var mat_sub = ShaderMaterial.new()
	mat_sub.shader = shader
	mat_sub.set_shader_parameter("color_top", Color(0.88, 0.3, 0.3, 1.0))
	mat_sub.set_shader_parameter("color_bottom", Color(0.48, 0.08, 0.08, 1.0))
	mat_sub.set_shader_parameter("node_size", subtitle.size)
	subtitle.material = mat_sub
	subtitle.resized.connect(func(): mat_sub.set_shader_parameter("node_size", subtitle.size))
	
	# Timer untuk glint setiap 5 detik
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(func():
		var tween = create_tween()
		tween.tween_method(_set_glint_progress, -0.3, 1.3, 1.2).set_trans(Tween.TRANS_SINE)
	)
	add_child(timer)

func _set_glint_progress(val: float):
	var title = $HBoxContainer/RightMargin/VBoxContainer/Title
	var subtitle = $HBoxContainer/RightMargin/VBoxContainer/Subtitle
	
	if title.material:
		title.material.set_shader_parameter("glint_progress", val)
	if subtitle.material:
		subtitle.material.set_shader_parameter("glint_progress", val)
