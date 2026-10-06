extends Button
class_name DropZone
## Зона сброса: выбросить предмет из руки. ЛКМ — весь стак, ПКМ — по одной штуке.

## Сцена выпавшего предмета и параметры точки сброса.
@export var dropped_item_scene: PackedScene
@export var drop_offset: Vector2 = Vector2(0, 16)
@export var merge_radius: float = 32.0

## Менеджер перетаскивания предметов.
@onready var InventoryManager: InventoryManage = InventoryManage

## При старте скрывает зону и подключает обработчик ЛКМ.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	
	# ✅ ЛКМ сигнал (подключишь в редакторе или оставь)
	pressed.connect(_on_left_click)

## Показывает зону сброса.
func show_zone() -> void:
	visible = true

## Прячет зону сброса.
func hide_zone() -> void:
	visible = false

## ЛКМ — выбрасывает весь стак.
func _on_left_click() -> void:
	_drop_from_hand(false)

## ПКМ — выбрасывает по одной штуке из стака.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_drop_from_hand(true)
		get_viewport().set_input_as_handled()

## Выбрасывает предмет из руки: весь стак или одну штуку.
func _drop_from_hand(one_by_one: bool) -> void:
	var held_visual = get_tree().get_first_node_in_group("held_item")
	if held_visual == null: return
	if dropped_item_scene == null: return
	
	var item_data: ItemData = held_visual.get("data")
	if item_data == null: return
	
	var player := get_tree().root.find_child("Player", true, false)
	var drop_pos := Vector2.ZERO
	if player and player is Node2D: 
		drop_pos = (player as Node2D).global_position + drop_offset
	
	if one_by_one and item_data.stackable and item_data.amount > 0:
		var single_data: ItemData = item_data.duplicate()
		single_data.amount = 1
		item_data.amount -= 1
		if held_visual.has_method("update_visual"): 
			held_visual.update_visual()
		_spawn_or_merge(single_data, drop_pos)
		if item_data.amount <= 0:
			# ВАЖНО: Сначала очищаем менеджер, потом уничтожаем визуал
			if InventoryManager.has_held():
				InventoryManager.clear()
			held_visual.queue_free()
			hide_zone()
		return
	
	_spawn_or_merge(item_data, drop_pos)
	
	# ВАЖНО: Сначала очищаем менеджер, потом уничтожаем визуал
	if InventoryManager.has_held():
		InventoryManager.clear()
	held_visual.queue_free()
	hide_zone()

## Создаёт новый выпавший предмет или доливает к такому же рядом (стак).
func _spawn_or_merge(data_to_drop: ItemData, pos: Vector2) -> void:
	# 1) Ищем такой же предмет рядом для стека
	var target = _find_nearby_stack(data_to_drop, pos)
	if target != null:
		var tdata: ItemData = target.get("data")
		tdata.amount += data_to_drop.amount
		if target.has_method("update_visual"):
			target.update_visual()
		return

	# 2) Создаём новый DroppedItem
	var dropped = dropped_item_scene.instantiate()
	dropped.set("data", data_to_drop)
	if dropped is Node2D:
		(dropped as Node2D).global_position = pos
	get_tree().current_scene.add_child(dropped)

## Ищет ближайший выпавший предмет того же типа в радиусе слияния.
func _find_nearby_stack(data_to_drop: ItemData, pos: Vector2) -> Node:
	if data_to_drop == null or not data_to_drop.stackable:
		return null

	var best: Node = null
	var best_dist := INF

	for n in get_tree().get_nodes_in_group("dropped_item"):
		if not is_instance_valid(n):
			continue
		if not (n is Node2D):
			continue

		var nd: ItemData = n.get("data")
		if nd == null:
			continue
		if nd.name != data_to_drop.name:
			continue

		var d := (n as Node2D).global_position.distance_to(pos)
		if d <= merge_radius and d < best_dist:
			best_dist = d
			best = n

	return best
