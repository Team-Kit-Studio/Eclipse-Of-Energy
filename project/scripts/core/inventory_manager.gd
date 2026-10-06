extends Node
## Глобальный менеджер инвентаря (Автозагрузка / Autoload).
## Отвечает за перетаскивание предметов между сетками инвентаря и хотбара.

## Данные предмета, который сейчас "в руке" у курсора
var held_item_data: ItemData = null

## Визуальное представление предмета в руке (инстанс InventoryItem)
var held_item_visual: Node2D = null

## Ссылка на сетку (ItemGrid), откуда был взят предмет
var source_grid: Node = null

## Ссылка на инвентарь (Panel), откуда был взят предмет
var source_inventory: Node = null

## Взять предмет в "руку" (начало перетаскивания)
func pick_up(item_data: ItemData, visual: Node2D, grid: Node, inventory: Node) -> void:
	# Если уже что-то держим, сначала вернем это на место
	if held_item_data:
		return_item()
	
	held_item_data = item_data
	held_item_visual = visual
	source_grid = grid
	source_inventory = inventory
	
	if visual:
		visual.add_to_group("held_item")
		if visual.has_method("get_picked_up"):
			visual.get_picked_up()

## Попытаться положить предмет в целевую точку
func place(item_data: ItemData, visual: Node2D) -> bool:
	if held_item_data != item_data:
		return false
		
	if visual:
		visual.remove_from_group("held_item")
		
	held_item_data = null
	held_item_visual = null
	source_grid = null
	source_inventory = null
	return true

## Вернуть предмет обратно в исходную точку (если отменили перетаскивание)
func return_item() -> void:
	if not held_item_data or not source_grid:
		return
	
	# Проверяем, что визуал ещё существует
	if held_item_visual and not is_instance_valid(held_item_visual):
		_clear_held_state()
		return
		
	var origin: Vector2i = source_grid.get_item_origin(held_item_data)
	if origin != Vector2i(-1, -1):
		if source_grid.try_add_item_at(held_item_data, held_item_visual, origin):
			if held_item_visual and is_instance_valid(held_item_visual):
				held_item_visual.remove_from_group("held_item")
				if held_item_visual.has_method("get_placed"):
					held_item_visual.get_placed(source_grid.grid_to_screen(origin))
			_clear_held_state()
	else:
		if source_grid.try_add_item(held_item_data, held_item_visual):
			if held_item_visual and is_instance_valid(held_item_visual):
				held_item_visual.remove_from_group("held_item")
			_clear_held_state()

## Принудительная очистка (используется при закрытии инвентаря или дропе)
func clear() -> void:
	if held_item_visual and is_instance_valid(held_item_visual):
		held_item_visual.remove_from_group("held_item")
		held_item_visual.queue_free()
		
	_clear_held_state()

## Проверка, держим ли мы что-то в руке
func has_held() -> bool:
	return held_item_data != null

## Получить данные предмета в руке
func get_held_data() -> ItemData:
	return held_item_data

## Получить визуал предмета в руке
func get_held_visual() -> Node2D:
	return held_item_visual

## Получить информацию об источнике предмета
func get_source() -> Dictionary:
	return {"grid": source_grid, "inventory": source_inventory}

## Внутренний метод для сброса переменных
func _clear_held_state() -> void:
	held_item_data = null
	held_item_visual = null
	source_grid = null
	source_inventory = null
