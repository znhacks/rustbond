extends CanvasLayer

signal quit_attempted

@onready var bg = $ColorRect
@onready var tape1 = $Tape1
@onready var tape2 = $Tape2
@onready var tape3 = $Tape3
@onready var notif_panel = $AntiQuitNotification
@onready var notif_label = $AntiQuitNotification/Margin/Label

var is_transitioning = false
var alt_f4_flag = false
var notif_tween : Tween
var pause_layer: CanvasLayer

var splash_player : AudioStreamPlayer
var ting_player : AudioStreamPlayer
var blur_rect : ColorRect

var msg_exit = [
	"Do it again.",
	"Stop.",
	"Oh such a bad boy here.",
	"Why you keep trying?",
	"There is NO exit"
]

var msg_altf4 = [
	"You're smart, but not smarter than me",
	"Stooopid~",
	"Stop trying.",
	"Alt + F4 is useless"
]

var msg_window_close = [
	"X wont work",
	"X is weak",
	"You cant close it",
	"X is useless"
]

var shown_priorities = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Global Anti-Quit
	get_tree().set_auto_accept_quit(false)
	
	_setup_blur()
	
	bg.modulate.a = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notif_panel.modulate.a = 0.0
	
	# Sembunyikan tape di luar layar
	_reset_tapes()
	
	_generate_sounds()
	
	# Global click sound listener for ALL buttons across the entire game	
	# Skip the first node which is the script itself (root scene) if we're iterating tree
	var root = get_tree().root
	for node in root.get_children():
		_attach_button_sounds(node)

func _attach_button_sounds(node: Node):
	if node is Button:
		if not node.pressed.is_connected(_play_global_click_sound):
			node.pressed.connect(_play_global_click_sound)
		
	# Recursively search children
	for child in node.get_children():
		_attach_button_sounds(child)

func _play_global_click_sound():
	play_splash()

func _show_pause_menu():
	if pause_layer and is_instance_valid(pause_layer): return
	
	get_tree().paused = true
	
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 100
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	var is_id = false
	if ResourceLoader.exists("res://SaveManager.gd"):
		is_id = get_node("/root/SaveManager").get_language() == "id"
	
	var lbl = Label.new()
	lbl.text = "PAUSED" if not is_id else "JEDA"
	var font = preload("res://assets/Fonts/VT323-Regular.ttf")
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 54)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	
	var hsep = HSeparator.new()
	vbox.add_child(hsep)
	
	var btn_resume = Button.new()
	btn_resume.text = "Resume" if not is_id else "Lanjutkan"
	btn_resume.custom_minimum_size = Vector2(280, 55)
	_apply_pause_btn_style(btn_resume)
	btn_resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(btn_resume)
	
	var btn_quit = Button.new()
	btn_quit.text = "Main Menu" if not is_id else "Menu Utama"
	btn_quit.custom_minimum_size = Vector2(280, 55)
	_apply_pause_btn_style(btn_quit)
	btn_quit.pressed.connect(_on_quit_to_menu_pressed)
	vbox.add_child(btn_quit)
	
	# Initial fade in for smoothness
	pause_layer.get_child(0).modulate.a = 0.0
	pause_layer.get_child(1).modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(pause_layer.get_child(0), "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(pause_layer.get_child(1), "modulate:a", 1.0, 0.15)

func _apply_pause_btn_style(btn: Button):
	var font = preload("res://assets/Fonts/VT323-Regular.ttf")
	if font: btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.6, 0.6))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.4, 0.45)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb)
	
	var sb_hov = sb.duplicate()
	sb_hov.bg_color = Color(0.25, 0.25, 0.28, 1.0)
	sb_hov.border_color = Color(0.7, 0.7, 0.75)
	btn.add_theme_stylebox_override("hover", sb_hov)
	
	var sb_prs = sb.duplicate()
	sb_prs.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	sb_prs.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("pressed", sb_prs)

func _on_resume_pressed():
	if pause_layer and is_instance_valid(pause_layer):
		var tw = create_tween()
		tw.tween_property(pause_layer.get_child(0), "modulate:a", 0.0, 0.15)
		tw.parallel().tween_property(pause_layer.get_child(1), "modulate:a", 0.0, 0.15)
		tw.tween_callback(func():
			pause_layer.queue_free()
			pause_layer = null
			get_tree().paused = false
		)
	else:
		get_tree().paused = false

func _on_quit_to_menu_pressed():
	get_tree().paused = false
	if pause_layer and is_instance_valid(pause_layer):
		pause_layer.queue_free()
		pause_layer = null
	play_splash()
	transition_to_scene("res://MainMenu.tscn")

func _setup_blur():
	blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
	uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
	void fragment() {
		COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blur_amount", 0.0)
	blur_rect.material = mat
	add_child(blur_rect)
	move_child(blur_rect, bg.get_index())

func _set_blur(val: float):
	if blur_rect and blur_rect.material:
		blur_rect.material.set_shader_parameter("blur_amount", val)

func _generate_sounds():
	splash_player = AudioStreamPlayer.new()
	splash_player.stream = preload("res://assets/Audio/click.mp3")
	splash_player.volume_db = 0.0
	add_child(splash_player)
	
	ting_player = AudioStreamPlayer.new()
	var ting_stream = AudioStreamWAV.new()
	ting_stream.format = AudioStreamWAV.FORMAT_8_BITS
	ting_stream.mix_rate = 22050
	var ting_data = PackedByteArray()
	for i in range(22050): # 1.0s
		var t = float(i) / 22050.0
		var env = exp(-t * 5.0)
		var val = sin(t * 2.0 * PI * 1500.0) * 127.0
		ting_data.append(int(128 + val * env * 0.7))
	ting_stream.data = ting_data
	ting_player.stream = ting_stream
	ting_player.volume_db = -15.0
	add_child(ting_player)

func play_splash():
	if splash_player: splash_player.play()

func play_ting():
	if ting_player: ting_player.play()

func _input(event):
	if event is InputEventKey and event.pressed:
		# --- SECRET DEV BACKDOOR ---
		if event.keycode == KEY_ESCAPE and event.shift_pressed:
			get_tree().quit()
		# ---------------------------
		
		# --- PAUSE / RETURN TO MENU ---
		if event.keycode == KEY_ESCAPE and not event.shift_pressed:
			if get_tree().current_scene and get_tree().current_scene.scene_file_path != "res://MainMenu.tscn":
				if pause_layer and is_instance_valid(pause_layer):
					_on_resume_pressed()
				else:
					_show_pause_menu()
				
		if event.keycode == KEY_F4 and event.alt_pressed:
			alt_f4_flag = true

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if alt_f4_flag:
			_show_quit_warning(msg_altf4)
			alt_f4_flag = false
		else:
			_show_quit_warning(msg_window_close)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# Reset the flag if the window loses focus (e.g. Alt+Tab)
		alt_f4_flag = false

func _show_quit_warning(msg_list: Array, priority_msg: String = ""):
	play_ting()
	emit_signal("quit_attempted")
	
	if priority_msg == "":
		if msg_list == msg_exit:
			priority_msg = "There is NO exit"
		elif msg_list == msg_altf4:
			priority_msg = "Alt + F4 is useless"
		elif msg_list == msg_window_close:
			priority_msg = "X wont work"
			
	var chosen_msg = ""
	if priority_msg != "" and not shown_priorities.has(priority_msg):
		shown_priorities[priority_msg] = true
		chosen_msg = priority_msg
	else:
		chosen_msg = msg_list[randi() % msg_list.size()]
		
	notif_label.text = chosen_msg
	
	if notif_tween:
		notif_tween.kill()
		
	notif_tween = create_tween()
	notif_tween.tween_property(notif_panel, "modulate:a", 1.0, 0.2)
	notif_tween.tween_interval(2.0)
	notif_tween.tween_property(notif_panel, "modulate:a", 0.0, 0.5)

func _reset_tapes():
	var screen_size = get_viewport().get_visible_rect().size
	
	tape1.modulate.a = 0.0
	tape2.modulate.a = 0.0
	tape3.modulate.a = 0.0
	
	# Tape 1 (Atas)
	tape1.rotation_degrees = 15.0
	tape1.position = Vector2((screen_size.x - tape1.size.x) / 2, screen_size.y * 0.25 - tape1.size.y / 2) - _get_slide_offset(tape1.rotation_degrees, 2500)
	
	# Tape 2 (Tengah menyilang)
	tape2.rotation_degrees = -10.0
	tape2.position = Vector2((screen_size.x - tape2.size.x) / 2, screen_size.y * 0.5 - tape2.size.y / 2) + _get_slide_offset(tape2.rotation_degrees, 2500)
	
	# Tape 3 (Bawah)
	tape3.rotation_degrees = 5.0
	tape3.position = Vector2((screen_size.x - tape3.size.x) / 2, screen_size.y * 0.75 - tape3.size.y / 2) - _get_slide_offset(tape3.rotation_degrees, 2500)

func _get_slide_offset(angle_deg: float, distance: float) -> Vector2:
	var angle_rad = deg_to_rad(angle_deg)
	return Vector2(cos(angle_rad), sin(angle_rad)) * distance

func transition_to_scene(target_scene: String):
	if is_transitioning:
		return
	is_transitioning = true
	
	var screen_size = get_viewport().get_visible_rect().size
	
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_tapes()
	
	tape1.modulate = Color(0.5, 0.5, 0.5, 1.0)
	tape2.modulate = Color(0.5, 0.5, 0.5, 1.0)
	tape3.modulate = Color(0.5, 0.5, 0.5, 1.0)
	
	var tween = create_tween().set_parallel(true)
	# Fade in hitam & blur
	tween.tween_property(bg, "modulate:a", 1.0, 0.4)
	tween.tween_method(_set_blur, 0.0, 3.0, 0.4)
	
	# Tapes masuk dengan cepat dan nge-bounce
	var t1_target = Vector2((screen_size.x - tape1.size.x) / 2, screen_size.y * 0.25 - tape1.size.y / 2)
	var t2_target = Vector2((screen_size.x - tape2.size.x) / 2, screen_size.y * 0.5 - tape2.size.y / 2)
	var t3_target = Vector2((screen_size.x - tape3.size.x) / 2, screen_size.y * 0.75 - tape3.size.y / 2)
	
	var flash_color = Color(1.5, 0.2, 0.2, 1.0)
	var dark_color = Color(0.5, 0.5, 0.5, 1.0)
	
	# Tape 1
	tween.tween_property(tape1, "position", t1_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tape1, "modulate", flash_color, 0.1)
	tween.parallel().tween_property(tape1, "modulate", dark_color, 0.4).set_delay(0.1)
	
	# Tape 2
	tween.parallel().tween_property(tape2, "position", t2_target, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	tween.parallel().tween_property(tape2, "modulate", flash_color, 0.1).set_delay(0.1)
	tween.parallel().tween_property(tape2, "modulate", dark_color, 0.5).set_delay(0.2)
	
	# Tape 3
	tween.parallel().tween_property(tape3, "position", t3_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tween.parallel().tween_property(tape3, "modulate", flash_color, 0.1).set_delay(0.2)
	tween.parallel().tween_property(tape3, "modulate", dark_color, 0.4).set_delay(0.3)
	
	await tween.finished
	
	# Jeda sejenak untuk ngasih feel horor/menegangkan
	await get_tree().create_timer(0.3).timeout
	
	# Pindah scene
	get_tree().change_scene_to_file(target_scene)
	
	# Tapes keluar dan fade out
	var out_tween = create_tween().set_parallel(true)
	
	# Tapes keluar menyusuri poros kemiringannya
	out_tween.tween_property(tape1, "position", tape1.position + _get_slide_offset(tape1.rotation_degrees, 2500), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	out_tween.tween_property(tape2, "position", tape2.position - _get_slide_offset(tape2.rotation_degrees, 2500), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.1)
	out_tween.tween_property(tape3, "position", tape3.position + _get_slide_offset(tape3.rotation_degrees, 2500), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.2)
	
	out_tween.tween_property(bg, "modulate:a", 0.0, 0.5).set_delay(0.4)
	out_tween.tween_method(_set_blur, 3.0, 0.0, 0.5).set_delay(0.4)
	
	await out_tween.finished
	
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_tapes()
	is_transitioning = false

func play_glitch_teleport_transition(target_scene: String):
	is_transitioning = true
	
	# Fullscreen Glitch Material Rect
	var glitch_overlay = ColorRect.new()
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
	uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
	uniform float blackout : hint_range(0.0, 1.0) = 0.0;
	
	float rand(vec2 co) {
		return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
	}
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		float time = TIME;
		
		if (glitch_intensity > 0.0) {
			// Slicing horizontal pixel & error offset
			float slice_y = floor(uv.y * (25.0 + glitch_intensity * 35.0));
			float r = rand(vec2(time * 8.0, slice_y));
			if (r > 0.35) {
				uv.x += (rand(vec2(time * 12.0, slice_y)) - 0.5) * 0.45 * glitch_intensity;
			}
			if (rand(vec2(time * 4.0, uv.x)) > 0.75) {
				uv.y += (rand(vec2(time * 6.0, uv.x)) - 0.5) * 0.25 * glitch_intensity;
			}
		}
		
		// RGB Split (Channel Offset Error)
		float shift = 0.03 * glitch_intensity;
		vec4 col_r = texture(screen_texture, vec2(uv.x + shift, uv.y));
		vec4 col_g = texture(screen_texture, uv);
		vec4 col_b = texture(screen_texture, vec2(uv.x - shift, uv.y));
		
		vec4 tex = vec4(col_r.r, col_g.g, col_b.b, 1.0);
		
		// Noise merah & garis piksel mati
		if (glitch_intensity > 0.0) {
			float noise_red = rand(vec2(time * 5.0, uv.x));
			float noise_black = rand(vec2(time * 3.0, uv.y));
			
			if (noise_red > 0.65) {
				tex.rgb = mix(tex.rgb, vec3(0.8, 0.0, 0.0), 0.95 * glitch_intensity);
			} else if (noise_black > 0.55) {
				tex.rgb = mix(tex.rgb, vec3(0.0, 0.0, 0.0), 1.0 * glitch_intensity);
			}
		}
		
		// Blackout transition fade
		tex.rgb = mix(tex.rgb, vec3(0.0, 0.0, 0.0), blackout);
		COLOR = tex;
	}
	"""
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("glitch_intensity", 0.0)
	mat.set_shader_parameter("blackout", 0.0)
	glitch_overlay.material = mat
	add_child(glitch_overlay)
	
	# Static SFX
	var glitch_sfx = AudioStreamPlayer.new()
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var data = PackedByteArray()
	data.resize(22050 * 2)
	for i in range(data.size()):
		var noise = (randi() % 256) - 128
		data[i] = int(128 + noise * 0.3)
	wav.data = data
	glitch_sfx.stream = wav
	glitch_sfx.volume_db = -18.0
	add_child(glitch_sfx)
	glitch_sfx.play()
	
	# Animasi Glitch Error Piksel bertahap & Blackout
	var tw = create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("glitch_intensity", v), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_method(func(v: float): mat.set_shader_parameter("blackout", v), 0.0, 1.0, 0.6)
	
	await tw.finished
	
	# Pindah scene saat screen terdistorsi & blackout total
	get_tree().change_scene_to_file(target_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Recover dari glitch di scene baru
	var tw_out = create_tween()
	tw_out.tween_method(func(v: float): mat.set_shader_parameter("blackout", v), 1.0, 0.0, 0.4)
	tw_out.parallel().tween_method(func(v: float): mat.set_shader_parameter("glitch_intensity", v), 1.0, 0.0, 0.4)
	
	await tw_out.finished
	
	glitch_sfx.queue_free()
	glitch_overlay.queue_free()
	is_transitioning = false
