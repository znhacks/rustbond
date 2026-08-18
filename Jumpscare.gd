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
var shake_intensity = 0.0

func _ready():
	# Sembunyikan dan persiapkan sprite terlebih dahulu agar tidak glitch/terpotong saat pertama kali loading
	ashy_sprite.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	
	ashy_sprite.pivot_offset = ashy_sprite.size / 2.0
	ashy_sprite.scale = initial_scale
	ashy_sprite.modulate.a = 0.0
	ashy_sprite.visible = true
	
	# Delay sangat singkat (0.05s) memastikan scene dan texture sudah benar-benar siap dirender
	await get_tree().create_timer(0.05).timeout
	
	# Putar suara bersamaan dengan mulainya loncatan
	_play_scream_sound()
	
	# Ambil tipe transisi
	var trans_enum = Tween.TRANS_BACK
	match transition_type:
		"TRANS_EXPO": trans_enum = Tween.TRANS_EXPO
		"TRANS_BOUNCE": trans_enum = Tween.TRANS_BOUNCE
		"TRANS_QUAD": trans_enum = Tween.TRANS_QUAD
		"TRANS_LINEAR": trans_enum = Tween.TRANS_LINEAR
	
	# Animasi melompat dan menabrak layar (durasi 0.35s agar gerakan meluncur terlihat jelas & dramatis)
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
	get_tree().change_scene_to_file("res://TheBond.tscn")

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
