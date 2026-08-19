extends CanvasLayer

signal minigame_finished

var bg: ColorRect
var plate_slot: TextureRect
var mixing_glass_slot: TextureRect

var bread_item: TextureRect
var sachet_item: TextureRect

var choco_mixed = false
var bread_on_plate = false
var milk_on_plate = false

var dragged_item = null
var drag_offset = Vector2.ZERO
var original_pos = Vector2.ZERO

var font_vt323 = preload("res://assets/Fonts/VT323-Regular.ttf")

var instruction_container: MarginContainer
var instruction_panel: PanelContainer
var instruction_label: Label

func _ready():
	layer = 80
	
	# Transparan soft (35% dim) agar latar kitchen di belakangnya TETAP KELIHATAN
	bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	_create_slots()
	_create_items()
	
	# Panel Instruksi di bagian paling bawah layar
	instruction_container = MarginContainer.new()
	instruction_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instruction_container.offset_top = -85
	instruction_container.offset_bottom = -15
	instruction_container.add_theme_constant_override("margin_left", 50)
	instruction_container.add_theme_constant_override("margin_right", 50)
	instruction_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instruction_container)
	
	instruction_panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	sb.border_width_top = 2
	sb.border_color = Color(0.5, 0.5, 0.6, 0.6)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	instruction_panel.add_theme_stylebox_override("panel", sb)
	instruction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_container.add_child(instruction_panel)
	
	instruction_label = Label.new()
	instruction_label.text = "Campurkan sachet ke dalam gelas, lalu taruh roti dan susu cokelat di atas piring!" if SaveManager.get_language() == "id" else "Mix the sachet into the water glass, then put the bread and chocolate milk on the plate!"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_override("font", font_vt323)
	instruction_label.add_theme_font_size_override("font_size", 28)
	instruction_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	instruction_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	instruction_label.add_theme_constant_override("shadow_offset_x", 2)
	instruction_label.add_theme_constant_override("shadow_offset_y", 2)
	instruction_panel.add_child(instruction_label)

func _create_slots():
	plate_slot = TextureRect.new()
	plate_slot.texture = preload("res://assets/Minigame/plate.png")
	plate_slot.position = Vector2(400, 220)
	plate_slot.custom_minimum_size = Vector2(200, 200)
	plate_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(plate_slot)
	
	mixing_glass_slot = TextureRect.new()
	mixing_glass_slot.texture = preload("res://assets/Minigame/cup_empty.png")
	mixing_glass_slot.position = Vector2(800, 220)
	mixing_glass_slot.custom_minimum_size = Vector2(150, 150)
	mixing_glass_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(mixing_glass_slot)

func _create_items():
	bread_item = _spawn_item("res://assets/Minigame/bread.png", Vector2(100, 150))
	bread_item.set_meta("item_id", "bread")
	
	sachet_item = _spawn_item("res://assets/Minigame/choco.png", Vector2(100, 350))
	sachet_item.set_meta("item_id", "sachet")
	
func _spawn_item(tex_path: String, pos: Vector2) -> TextureRect:
	var item = TextureRect.new()
	item.texture = load(tex_path)
	item.position = pos
	item.custom_minimum_size = Vector2(100, 100)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_on_item_input.bind(item))
	add_child(item)
	return item

func _on_item_input(event: InputEvent, item: TextureRect):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragged_item = item
				drag_offset = event.position
				original_pos = item.position
				item.move_to_front()
			elif dragged_item == item:
				_handle_drop(item)
				dragged_item = null
				
	elif event is InputEventMouseMotion and dragged_item == item:
		item.position += event.relative

func _handle_drop(item: TextureRect):
	var item_id = item.get_meta("item_id")
	var item_rect = Rect2(item.position, item.size)
	
	var mixing_rect = Rect2(mixing_glass_slot.position, mixing_glass_slot.size)
	var plate_rect_area = Rect2(plate_slot.position, plate_slot.size)
	
	if item_id == "sachet" and item_rect.intersects(mixing_rect) and not choco_mixed:
		# Mix sachet with water
		choco_mixed = true
		mixing_glass_slot.texture = preload("res://assets/Minigame/choco_milk.png")
		item.queue_free() # Remove sachet
		
		# Now the mixing glass becomes draggable as choco_milk
		mixing_glass_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if not mixing_glass_slot.gui_input.is_connected(_on_item_input):
			mixing_glass_slot.gui_input.connect(_on_item_input.bind(mixing_glass_slot))
		mixing_glass_slot.set_meta("item_id", "choco_milk")
		
	elif item_id == "bread" and item_rect.intersects(plate_rect_area):
		bread_on_plate = true
		item.position = plate_slot.position + Vector2(20, 20)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_check_win()
		
	elif item_id == "choco_milk" and item_rect.intersects(plate_rect_area):
		milk_on_plate = true
		item.position = plate_slot.position + Vector2(80, 20)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_check_win()
		
	else:
		# Snap back
		if item_id != "choco_milk": # choco_milk is originally a slot, its original pos is mixing slot
			var tween = create_tween()
			tween.tween_property(item, "position", original_pos, 0.2)

func _check_win():
	if bread_on_plate and milk_on_plate:
		# Sembunyikan teks instruksi panduan
		if instruction_label:
			instruction_label.hide()
			
		# Tampilkan kata "Done!" tepat di panel bagian bawah yang sama
		var win_label = Label.new()
		win_label.text = "Selesai!" if SaveManager.get_language() == "id" else "Done!"
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		win_label.add_theme_font_override("font", font_vt323)
		win_label.add_theme_font_size_override("font_size", 48)
		win_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.35, 1.0))
		win_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		win_label.add_theme_constant_override("shadow_offset_x", 2)
		win_label.add_theme_constant_override("shadow_offset_y", 2)
		instruction_panel.add_child(win_label)
		
		await get_tree().create_timer(1.5).timeout
		minigame_finished.emit()
		queue_free()
