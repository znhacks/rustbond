extends CanvasLayer

var crt_rect: ColorRect

func _ready():
	layer = 95 # Above normal game UI (layer 0), below TransitionManager (layer 100)
	_setup_crt_overlay()

func _setup_crt_overlay():
	crt_rect = ColorRect.new()
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;

	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
	uniform float scanline_count : hint_range(100.0, 1000.0) = 350.0;
	uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
	uniform float noise_intensity : hint_range(0.0, 1.0) = 0.035;
	uniform float distortion : hint_range(0.0, 0.5) = 0.03;
	uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.25;
	uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0015;

	float random(vec2 st) {
		return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
	}

	vec2 warp(vec2 uv) {
		vec2 dc = abs(0.5 - uv);
		dc *= dc;
		uv.x += (uv.x - 0.5) * dc.y * distortion;
		uv.y += (uv.y - 0.5) * dc.x * distortion;
		return uv;
	}

	void fragment() {
		vec2 uv = warp(SCREEN_UV);
		
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			vec2 offset = vec2(chromatic_aberration, 0.0);
			float r = texture(screen_texture, uv - offset).r;
			float g = texture(screen_texture, uv).g;
			float b = texture(screen_texture, uv + offset).b;
			vec3 col = vec3(r, g, b);
			
			// Scanlines
			float scanline = sin(uv.y * scanline_count * 3.14159 * 2.0);
			scanline = (scanline + 1.0) * 0.5;
			scanline = pow(scanline, 1.5);
			col *= (1.0 - scanline_intensity + scanline * scanline_intensity);
			
			// Static noise
			float n = random(uv + vec2(TIME * 15.0, TIME * 25.0));
			col += (n - 0.5) * noise_intensity;
			
			// Vignette shadow
			float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
			vig = clamp(pow(16.0 * vig, vignette_intensity), 0.0, 1.0);
			col *= vig;
			
			COLOR = vec4(col, 1.0);
		}
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	crt_rect.material = mat
	add_child(crt_rect)
