extends Control

# --- PENGATURAN ANIMASI JUMPSCARE (Bisa Diatur via Inspector Godot) ---
@export_group("Jumpscare Animation Settings")
@export var initial_scale: Vector2 = Vector2(0.05, 0.05) ## Skala awal Ashy saat muncul (kecil)
@export var target_scale: Vector2 = Vector2(1.5, 1.5)   ## Skala akhir Ashy saat loncat ke layar (besar)
@export var target_y_offset: float = 150.0              ## Pergeseran vertikal ke atas (nilai negatif = semakin ke atas)
@export var jump_duration: float = 0.35                  ## Durasi loncatan (0.35s pas agar terlihat jelas menabrak layar)
@export var shake_amount: float = 120.0                  ## Kekuatan guncangan layar (screen shake)
@export var scene_duration: float = 1.8                  ## Berapa detik scene jumpscare tampil sebelum ganti scene

@export_group("Easing Type")
## TRANS_BACK = Efek loncat/overshoot, TRANS_EXPO = Sangat cepat/tajam, TRANS_BOUNCE = Membal
@export_enum("TRANS_BACK", "TRANS_EXPO", "TRANS_BOUNCE", "TRANS_QUAD", "TRANS_LINEAR") var transition_type: String = "TRANS_BACK"

@onready var ashy_sprite = $AshySprite
var blip_player: AudioStreamPlayer
var speech_blip_player: AudioStreamPlayer
var shake_intensity = 0.0
var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")
var restart_stream = preload("res://assets/Audio/restart.mp3")

func _ready():
	# Sembunyikan sprite Ashy terlebih dahulu
	ashy_sprite.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Inisialisasi audio beep suara dialog (berat/low pitch)
	speech_blip_player = AudioStreamPlayer.new()
	speech_blip_player.stream = _generate_heavy_blip()
	speech_blip_player.volume_db = -5.0
	speech_blip_player.pitch_scale = 0.45 # Beep TV/narasi yang berat
	add_child(speech_blip_player)
	
	# Buat UI Narasi Monolog terpusat penuh di tengah layar
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(container)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font_vt323)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15, 1.0))
	container.add_child(label)
	
	# Monolog Bahasa Inggris / Indonesia sesuai bahasa terpilih
	var lines = [
		"Kamu sangat mengecewakan.",
		"Padahal aku sudah memberimu kesempatan."
	] if SaveManager.get_language() == "id" else [
		"You are so disappointing.",
		"And I even gave you a chance."
	]
	
	# Ketik monolog satu per satu di layar gelap
	for text in lines:
		label.text = text
		label.visible_characters = 0
		label.modulate.a = 1.0
		
		# Ketik per huruf dengan suara beep berat
		for i in range(text.length() + 1):
			label.visible_characters = i
			if i > 0 and text[i-1] != " " and text[i-1] != ".":
				speech_blip_player.play()
			await get_tree().create_timer(0.06).timeout
			
		await get_tree().create_timer(1.2).timeout
		
		# Fade out kalimat
		var tw = create_tween()
		tw.tween_property(label, "modulate:a", 0.0, 0.5)
		await tw.finished
		await get_tree().create_timer(0.3).timeout
	
	canvas_layer.queue_free()
	
	# --- JUMPSCARE EXECUTION ---
	ashy_sprite.pivot_offset = ashy_sprite.size / 2.0
	ashy_sprite.scale = initial_scale
	ashy_sprite.modulate.a = 0.0
	ashy_sprite.visible = true
	
	await get_tree().create_timer(0.05).timeout
	
	# Putar suara teriakan jumpscare bersamaan dengan loncatan
	_play_scream_sound()
	
	# Ambil tipe transisi
	var trans_enum = Tween.TRANS_BACK
	match transition_type:
		"TRANS_EXPO": trans_enum = Tween.TRANS_EXPO
		"TRANS_BOUNCE": trans_enum = Tween.TRANS_BOUNCE
		"TRANS_QUAD": trans_enum = Tween.TRANS_QUAD
		"TRANS_LINEAR": trans_enum = Tween.TRANS_LINEAR
	
	# Animasi melompat dan menabrak layar
	var base_center = (get_viewport_rect().size / 2.0 - ashy_sprite.size / 2.0) + Vector2(0, target_y_offset)
	ashy_sprite.position = base_center
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ashy_sprite, "scale", target_scale, jump_duration).set_trans(trans_enum).set_ease(Tween.EASE_OUT)
	tween.tween_property(ashy_sprite, "modulate:a", 1.0, 0.08)

	# Mulai guncangan layar saat Ashy mencapai puncak benturan
	await tween.finished
	shake_intensity = shake_amount
	_apply_impact_flash()
	_apply_glitch_shader()
	_apply_vignette_blur()
	
	await get_tree().create_timer(scene_duration).timeout
	
	# Hentikan guncangan layar & sembunyikan sprite jumpscare untuk masuk ke layar restart
	shake_intensity = 0.0
	ashy_sprite.visible = false
	
	_show_restart_button()

func _show_restart_button():
	var btn_layer = CanvasLayer.new()
	add_child(btn_layer)
	
	# CenterContainer untuk memastikan posisi persis di tengah layar
	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_layer.add_child(container)
	
	var restart_btn = Button.new()
	restart_btn.text = "  [ Coba Lagi? ]  " if SaveManager.get_language() == "id" else "  [ Restart? ]  "
	restart_btn.custom_minimum_size = Vector2(260, 64)
	
	# Styling retro VT323
	restart_btn.add_theme_font_override("font", font_vt323)
	restart_btn.add_theme_font_size_override("font_size", 40)
	restart_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	restart_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.2, 0.2, 1.0))
	restart_btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.1, 0.1, 1.0))
	
	# Flat / transparent style
	var style_flat = StyleBoxFlat.new()
	style_flat.bg_color = Color(0, 0, 0, 0.75)
	style_flat.border_color = Color(0.8, 0.15, 0.15, 0.8)
	style_flat.set_border_width_all(2)
	style_flat.set_corner_radius_all(6)
	restart_btn.add_theme_stylebox_override("normal", style_flat)
	
	container.add_child(restart_btn)
	
	# Animasi fade-in tombol yang cepat
	restart_btn.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(restart_btn, "modulate:a", 1.0, 0.25)
	
	# Event click
	restart_btn.pressed.connect(func():
		restart_btn.disabled = true
		
		# Sembunyikan tombol agar layar bersih saat audio menyadarkan diri berputar
		restart_btn.visible = false
		
		if restart_stream:
			var restart_player = AudioStreamPlayer.new()
			restart_player.stream = restart_stream
			restart_player.volume_db = 8.0
			add_child(restart_player)
			restart_player.play()
			
			# Tunggu sampai suara restart selesai terputar penuh baru pindah scene
			var duration = restart_stream.get_length()
			if duration > 0.0:
				await get_tree().create_timer(duration).timeout
			else:
				await restart_player.finished
		else:
			await get_tree().create_timer(0.5).timeout
			
		get_tree().change_scene_to_file("res://TheBond.tscn")
	)

func _generate_heavy_blip() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	
	var tone_duration := 0.05
	var tone_frequency := 180.0 # Frekuensi rendah untuk beep berat
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
		data[i] = int(wave * volume_fade * 50) + 128
		
	wav.data = data
	return wav

func _play_scream_sound():
	blip_player = AudioStreamPlayer.new()
	var scream_ashy = "res://assets/Audio/ashyscream.mp3"
	var scream_path = "res://assets/Audio/scream.wav"
	var scream_ogg_path = "res://assets/Audio/scream.ogg"
	
	if ResourceLoader.exists(scream_ashy):
		blip_player.stream = load(scream_ashy)
	elif ResourceLoader.exists(scream_path):
		blip_player.stream = load(scream_path)
	elif ResourceLoader.exists(scream_ogg_path):
		blip_player.stream = load(scream_ogg_path)
	else:
		blip_player.stream = _generate_scream_sound()
		
	blip_player.volume_db = 10.0
	blip_player.pitch_scale = 1.0
	add_child(blip_player)
	blip_player.play()

func _apply_impact_flash():
	# Kilatan merah/putih cepat saat menabrak layar
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0, 0, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.2)
	tw.tween_callback(flash.queue_free)

func _apply_glitch_shader():
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float glitch_intensity = 0.8;
	uniform vec4 color_red : source_color = vec4(0.8, 0.0, 0.0, 1.0);
	uniform vec4 color_black : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	float rand(vec2 co){
		return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
	}
	
	void fragment() {
		vec2 uv = UV;
		float time = TIME;
		
		if (glitch_intensity > 0.0) {
			float slice_y = floor(uv.y * 30.0);
			float r = rand(vec2(time * 5.0, slice_y));
			if (r > 0.4) {
				uv.x += (rand(vec2(time, slice_y)) - 0.5) * 0.6 * glitch_intensity;
			}
			if (rand(vec2(time * 2.0, uv.x)) > 0.8) {
				uv.y += (rand(vec2(time, uv.x)) - 0.5) * 0.2 * glitch_intensity;
			}
		}
		
		vec4 tex = texture(TEXTURE, uv);
		
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
	var mat = ShaderMaterial.new()
	mat.shader = shader
	ashy_sprite.material = mat
	
	# Tween glitch_intensity ke 0 agar glitch hanya ada di awal (entrance)
	var tween = create_tween()
	tween.tween_method(func(val: float): mat.set_shader_parameter("glitch_intensity", val), 0.8, 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _apply_vignette_blur():
	var cr = ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
	void fragment() {
		vec4 c = texture(screen_texture, SCREEN_UV);
		float d = distance(UV, vec2(0.5, 0.5));
		c.rgb = mix(c.rgb, vec3(1.0, 0.0, 0.0), d * 0.3);
		COLOR = c;
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	cr.material = mat
	add_child(cr)

func _process(delta):
	var base_pos = (get_viewport_rect().size / 2.0 - ashy_sprite.size / 2.0) + Vector2(0, target_y_offset)
	if shake_intensity > 0:
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity, shake_intensity)
		ashy_sprite.position = base_pos + Vector2(offset_x, offset_y)
	else:
		ashy_sprite.position = base_pos

func _generate_scream_sound() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	
	var duration := 1.5
	var frame_count := int(wav.mix_rate * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	
	for i in range(frame_count):
		var t := float(i) / wav.mix_rate
		
		# Envelope dengan sudden burst dan decay parau
		var env := 1.0
		if t < 0.03:
			env = t / 0.03
		else:
			env = exp(-(t - 0.03) * 1.8)
			
		# Pitch scream turun dari 950 Hz ke 280 Hz (suara teriakan manusia serak)
		var base_freq := 950.0 - 670.0 * (t / duration)
		
		# Modulasi tenggorokan / raspiness intens
		var throat_mod := sin(t * 85.0 * PI) * 180.0
		var pitch_inst := base_freq + throat_mod
		
		# Multi-harmonic vocal sound (vowel formants)
		var f1 := sin(t * pitch_inst * TAU)
		var f2 := sin(t * (pitch_inst * 1.48) * TAU) * 0.7
		var f3 := sin(t * (pitch_inst * 2.12) * TAU) * 0.4
		
		# Heavy white noise & vocal distortion untuk efek teriakan keras
		var noise := (randf() - 0.5) * 1.5
		
		var raw_sample := (f1 * 0.4 + f2 * 0.3 + f3 * 0.2 + noise * 0.6) * env
		
		# Hard clipping / distortion agar terasa visceral
		raw_sample = clamp(raw_sample * 1.6, -1.0, 1.0)
		
		data[i] = int(raw_sample * 124.0) + 128
		
	wav.data = data
	return wav
