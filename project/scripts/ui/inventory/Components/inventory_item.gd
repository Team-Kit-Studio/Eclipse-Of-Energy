extends Node2D
## Визуальное представление предмета в инвентаре.
## Обрабатывает клики мыши и эмитит сигналы для хотбара/инвентаря.

var data: ItemData = null
var is_picked: bool = false
var is_equipped: bool = false

## Сигнал клика ЛКМ по предмету
signal item_clicked
## Сигнал клика ПКМ по предмету (передает глобальную позицию)
signal item_right_clicked(global_position: Vector2)

@onready var sprite: Sprite2D = $Sprite2D
@onready var amount_label: Label = $HandLabel
@onready var overlay: ColorRect = $Overlay

@onready var hover_area: Area2D = $HoverArea
@onready var hover_shape: CollisionShape2D = $HoverArea/CollisionShape2D

var size: Vector2:
	get:
		var s = data.get_size()
		return Vector2(s.x, s.y) * 64


func _exit_tree() -> void:
	if is_picked:
		var dz = get_tree().root.find_child("DropZone", true, false)
		if dz and dz.has_method("hide_zone"):
			dz.hide_zone()

func _ready() -> void:
	add_to_group("inventory_item")

	if hover_area:
		hover_area.input_pickable = true
		if hover_area.collision_layer == 0:
			hover_area.collision_layer = 1

	if data:
		sprite.texture = data.texture
		sprite.rotation_degrees = 90.0 if data.is_rotated else 0.0
		update_visual()
		update_equipped_state()

func _process(_delta: float) -> void:
	if is_picked:
		global_position = get_global_mouse_position()

func set_grid_position(pos: Vector2) -> void:
	global_position = pos + size / 2

func update_visual() -> void:
	if not data or not sprite.texture:
		return

	var expected_size = size
	var tex_size = sprite.texture.get_size()

	if data.is_rotated:
		sprite.scale = Vector2(expected_size.y / tex_size.x, expected_size.x / tex_size.y)
	else:
		sprite.scale = expected_size / tex_size

	# ВАЖНО: узел InventoryItem — Node2D, его origin = ЦЕНТР предмета,
	# а у Control (Overlay) origin = верхний-левый угол. Поэтому позиция
	# оверлея = -size/2, иначе он сползает в правый-нижний угол предмета
	# и накрывает соседнюю ячейку.
	if overlay:
		overlay.size = expected_size
		overlay.position = -expected_size / 2.0

	if hover_shape and hover_shape.shape is RectangleShape2D:
		var rect := hover_shape.shape as RectangleShape2D
		rect.size = expected_size
		hover_shape.position = Vector2.ZERO

	if amount_label:
		if data.max_stack_size > 1 and data.amount > 1:
			amount_label.text = str(data.amount)
			amount_label.visible = true
			var padding = 2
			amount_label.position = Vector2(
				size.x / 2.0 - amount_label.size.x - padding,
				size.y / 2.0 - amount_label.size.y - padding
			)
		else:
			amount_label.visible = false

func update_equipped_state() -> void:
	if overlay:
		# Дублируем геометрию оверлея: на случай, если update_visual ещё не отработал
		if data:
			var expected_size = size
			overlay.size = expected_size
			overlay.position = -expected_size / 2.0
		overlay.visible = is_equipped
		if is_equipped:
			overlay.color = Color(0.5, 0.5, 0.5, 0.6)
		else:
			overlay.color = Color(0, 0, 0, 0)

func set_equipped(equipped: bool) -> void:
	is_equipped = equipped
	update_equipped_state()

## Обработка ввода мыши на предмете
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			item_clicked.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			item_right_clicked.emit(get_global_mouse_position())

func _input(event: InputEvent) -> void:
	if is_picked and event is InputEventKey and event.keycode == KEY_R and event.is_pressed():
		do_rotation()
		get_tree().root.set_input_as_handled()

func do_rotation() -> void:
	data.is_rotated = !data.is_rotated
	update_visual()

	var tween = create_tween()
	var target = 90.0 if data.is_rotated else 0.0
	tween.tween_property(sprite, "rotation_degrees", target, 0.2).set_trans(Tween.TRANS_CUBIC)

func _get_drop_zone() -> Node:
	return get_tree().root.find_child("DropZone", true, false)

func get_picked_up() -> void:
	add_to_group("held_item")
	is_picked = true
	z_index = 100

	var dz = _get_drop_zone()
	if dz and dz.has_method("show_zone"):
		dz.show_zone()

	if amount_label and data and data.amount > 1:
		amount_label.visible = true
		update_visual()

func get_placed(pos: Vector2) -> void:
	is_picked = false
	global_position = pos + size / 2
	z_index = 0
	remove_from_group("held_item")

	var dz = _get_drop_zone()
	if dz and dz.has_method("hide_zone"):
		dz.hide_zone()
