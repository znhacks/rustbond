extends CanvasLayer

@onready var bg = $ColorRect
@onready var tape1 = $Tape1
@onready var tape2 = $Tape2
@onready var tape3 = $Tape3

var is_transitioning = false

func _ready():
	bg.modulate.a = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Sembunyikan tape di luar layar
	_reset_tapes()

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
	
	tape1.modulate.a = 1.0
	tape2.modulate.a = 1.0
	tape3.modulate.a = 1.0
	
	var tween = create_tween().set_parallel(true)
	# Fade in hitam
	tween.tween_property(bg, "modulate:a", 1.0, 0.4)
	
	# Tapes masuk dengan cepat dan nge-bounce
	var t1_target = Vector2((screen_size.x - tape1.size.x) / 2, screen_size.y * 0.25 - tape1.size.y / 2)
	var t2_target = Vector2((screen_size.x - tape2.size.x) / 2, screen_size.y * 0.5 - tape2.size.y / 2)
	var t3_target = Vector2((screen_size.x - tape3.size.x) / 2, screen_size.y * 0.75 - tape3.size.y / 2)
	
	tween.tween_property(tape1, "position", t1_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tape2, "position", t2_target, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	tween.tween_property(tape3, "position", t3_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	
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
	
	await out_tween.finished
	
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_tapes()
	is_transitioning = false
