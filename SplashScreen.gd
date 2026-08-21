extends Control

@onready var icon_texture = $CanvasLayer/IconTexture
@onready var title_label = $CanvasLayer/TitleLabel
@onready var dev_label = $CanvasLayer/DeveloperLabel
@onready var warning_container = $CanvasLayer/WarningContainer
@onready var warning_title = $CanvasLayer/WarningContainer/PanelContainer/VBoxContainer/WarningTitle
@onready var warning_text = $CanvasLayer/WarningContainer/PanelContainer/VBoxContainer/WarningText
@onready var proceed_button = $CanvasLayer/WarningContainer/PanelContainer/VBoxContainer/ProceedButton

var font_title: Font = preload("res://assets/Fonts/Martyric_PersonalUse.ttf")
var font_helpme: Font = preload("res://assets/Fonts/HelpMe.ttf")
var font_vt323: Font = preload("res://assets/Fonts/VT323-Regular.ttf")

func _ready() -> void:
	# Hide all elements initially
	icon_texture.modulate.a = 0.0
	title_label.modulate.a = 0.0
	dev_label.modulate.a = 0.0
	warning_container.modulate.a = 0.0
	
	icon_texture.show()
	title_label.show()
	dev_label.show()
	warning_container.show()
	
	# Apply fonts and styles
	title_label.add_theme_font_override("font", font_title)
	title_label.add_theme_font_size_override("font_size", 90)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	
	dev_label.add_theme_font_override("font", font_vt323)
	dev_label.add_theme_font_size_override("font_size", 54)
	dev_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	dev_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	dev_label.add_theme_constant_override("shadow_offset_x", 3)
	dev_label.add_theme_constant_override("shadow_offset_y", 3)
	
	warning_title.add_theme_font_override("font", font_helpme)
	warning_title.add_theme_font_size_override("font_size", 48)
	warning_title.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
	
	warning_text.add_theme_font_override("font", font_vt323)
	warning_text.add_theme_font_size_override("font_size", 28)
	warning_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	
	if SaveManager.get_language() == "id":
		warning_title.text = "PERINGATAN KONTEN & DISCLAIMER"
		warning_text.text = "Game ini mengandung lampu kelap-kelip, efek glitch cepat, jumpscare mendadak, dan efek suara keras.\n\nDISCLAIMER:\nPengembang TIDAK BERTANGGUNG JAWAB atas segala masalah kesehatan, gangguan fisik/mental, atau kerugian yang dialami selama bermain. Anda telah diperingatkan secara jelas.\n\nLanjutkan dengan risiko Anda sendiri."
		proceed_button.text = "[ SAYA SETUJU & LANJUT ]"
	else:
		warning_title.text = "CONTENT WARNING & DISCLAIMER"
		warning_text.text = "This game contains flashing lights, rapid glitch effects, sudden jumpscares, and loud sound effects.\n\nDISCLAIMER:\nThe developer assumes NO RESPONSIBILITY OR LIABILITY for any health issues, physical or mental distress, or consequences experienced during gameplay. You have been explicitly warned.\n\nProceed at your own risk."
		proceed_button.text = "[ I AGREE & PROCEED ]"
		
	_apply_proceed_button_style(proceed_button)
	proceed_button.pressed.connect(_on_proceed_pressed)
	
	_run_splash_sequence()

func _apply_proceed_button_style(btn: Button) -> void:
	btn.add_theme_font_override("font", font_vt323)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.1, 0.1, 1.0))
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.02, 0.02, 0.85)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(0.75, 0.15, 0.15, 0.85)
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_right = 8
	sb_normal.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", sb_normal)
	
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.25, 0.04, 0.04, 0.95)
	sb_hover.border_color = Color(0.95, 0.25, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hover)

func _run_splash_sequence() -> void:
	await get_tree().create_timer(0.3).timeout
	
	# --- SLIDE 1: ICON ---
	await _fade_in_and_out(icon_texture, 1.0, 1.2, 0.8)
	await get_tree().create_timer(0.3).timeout
	
	# --- SLIDE 2: RUSTBOND ---
	await _fade_in_and_out(title_label, 1.0, 1.2, 0.8)
	await get_tree().create_timer(0.3).timeout
	
	# --- SLIDE 3: BY JDEVS ---
	await _fade_in_and_out(dev_label, 1.0, 1.2, 0.8)
	await get_tree().create_timer(0.4).timeout
	
	# --- SLIDE 4: CONTENT WARNING (Wait for Proceed click) ---
	var tw = create_tween()
	tw.tween_property(warning_container, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _on_proceed_pressed() -> void:
	proceed_button.disabled = true
	TransitionManager.play_splash()
	TransitionManager.transition_to_scene("res://MainMenu.tscn")

func _fade_in_and_out(target_node: Control, hold_time: float, fade_in_time: float, fade_out_time: float) -> void:
	# Fade In
	var tw_in = create_tween()
	tw_in.tween_property(target_node, "modulate:a", 1.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_in.finished
	
	# Hold
	await get_tree().create_timer(hold_time).timeout
	
	# Fade Out
	var tw_out = create_tween()
	tw_out.tween_property(target_node, "modulate:a", 0.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_out.finished
