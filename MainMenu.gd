extends Control

var orig_btn_colors = {}
var char_tween : Tween
var bg_start_pos : Vector2
var screen_size : Vector2

func _ready():
	# 1. Setup Vignette Effect (softer)
	setup_vignette()
	
	# Pastikan Container tidak nge-block klik mouse ke Character yang ada di belakangnya
	$HBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/LeftSpacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/RightMargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBoxContainer/RightMargin/VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. Wait one frame so UI layouts and sizes are calculated
	await get_tree().process_frame
	
	# 3. Setup Elegant Buttons
	var buttons = [
		$HBoxContainer/RightMargin/VBoxContainer/PlayButton,
		$HBoxContainer/RightMargin/VBoxContainer/OptionsButton,
		$HBoxContainer/RightMargin/VBoxContainer/ExitButton
	]
	
	for btn in buttons:
		
		btn.pivot_offset = btn.size / 2.0
		
		btn.add_theme_color_override("font_shadow_color", Color(0,0,0, 0.8))
		btn.add_theme_constant_override("shadow_offset_x", 2)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		
		orig_btn_colors[btn] = Color(1, 1, 1, 0.7)
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

func _process(delta):
	# Parallax Background Logic
	if $Background:
		var mouse_pos = get_viewport().get_mouse_position()
		# Offset towards the mouse slightly (inverted for natural parallax)
		var offset = (mouse_pos - (screen_size / 2.0)) * 0.03
		# Smoothly lerp towards target position
		var target_pos = bg_start_pos - offset
		$Background.position = $Background.position.lerp(target_pos, delta * 4.0)

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

func _on_btn_hover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "modulate", Color(0.8, 0.1, 0.1, 1.0), 0.2)
	
func _on_btn_unhover(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "modulate", orig_btn_colors[btn], 0.3)

func _on_play_button_pressed():
	TransitionManager.transition_to_scene("res://MainMenu.tscn")

func _on_options_button_pressed():
	print("Options button pressed.")

func _on_exit_button_pressed():
	get_tree().quit()

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
		if (COLOR.r < 0.5) {
			// Pass outline atau shadow (gelap)
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
	
	# Material untuk Subtitle (putih/abu-abu gradasinya)
	var mat_sub = ShaderMaterial.new()
	mat_sub.shader = shader
	mat_sub.set_shader_parameter("color_top", Color(1.0, 1.0, 1.0, 1.0))
	mat_sub.set_shader_parameter("color_bottom", Color(0.6, 0.6, 0.6, 1.0))
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
