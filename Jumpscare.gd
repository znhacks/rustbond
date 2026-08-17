extends Control

@onready var bg = $TextureRect
var blip_player: AudioStreamPlayer
var shake_intensity = 0.0

func _ready():
	# Scale dari tengah layar
	await get_tree().process_frame # Wait one frame for layout to settle
	bg.pivot_offset = get_viewport_rect().size / 2.0
	bg.scale = Vector2(0.2, 0.2)
	
	var tween = create_tween()
	tween.tween_property(bg, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	
	shake_intensity = 80.0
	_apply_glitch_shader()
	_apply_vignette_blur()
	
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = _generate_8bit_blip()
	blip_player.volume_db = 8.0
	blip_player.pitch_scale = 3.0
	add_child(blip_player)
	blip_player.play()
	
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file("res://TheBond.tscn")

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
	bg.material = mat
	
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
	if shake_intensity > 0:
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity, shake_intensity)
		bg.position = Vector2(offset_x, offset_y)

func _generate_8bit_blip() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	
	var tone_duration := 0.1
	var tone_frequency := 300.0
	var frame_count := int(wav.mix_rate * tone_duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	
	for i in range(frame_count):
		var time := float(i) / wav.mix_rate
		var wave := 1.0 if sin(time * tone_frequency * TAU) > 0.0 else -1.0
		data[i] = int(wave * 40) + 128
		
	wav.data = data
	return wav
