extends CanvasLayer

var container: MarginContainer
var label: Label
var blink_tween: Tween

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready():
	layer = 85 # Top layer above game UI, below CRTOverlay (95) and TransitionManager (100)
	
	_create_ui()
	
	# Start hidden until entering gameplay
	visible = false
	container.modulate.a = 0.0

func _create_ui():
	container = MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.offset_top = 20
	container.offset_right = -25
	container.offset_left = -220
	container.offset_bottom = 60
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hbox)
	
	# Skip label text
	label = Label.new()
	label.text = "Skip [ Space ]" if SaveManager.get_language() == "en" else "Lompati [ Space ]"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font_vt323)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hbox.add_child(label)
	
	_start_blinking()

func _start_blinking():
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(label, "modulate:a", 0.35, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blink_tween.tween_property(label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta):
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name
		var scene_path = current_scene.scene_file_path
		
		# Sembunyikan jika berada di Main Menu atau Splash Screen
		if scene_name == "MainMenu" or scene_name == "SplashScreen" or scene_path == "res://MainMenu.tscn" or scene_path == "res://SplashScreen.tscn":
			if visible:
				hide_overlay()
		else:
			# Tampilkan jika berada di dalam permainan
			if not visible and container.modulate.a < 0.1:
				show_overlay()

func show_overlay():
	visible = true
	var tw = create_tween()
	tw.tween_property(container, "modulate:a", 1.0, 0.4)

func hide_overlay():
	var tw = create_tween()
	tw.tween_property(container, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func(): visible = false)
