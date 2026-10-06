extends GridContainer
## Сетка инвентаря: раскладка предметов по ячейкам, перетаскивание (drag&drop),
## подсветка допустимых позиций, экспорт/импорт раскладки для контейнеров.

const SLOT_SIZE: int = 64

@export var inventory_slot_scene: PackedScene
@export var inventory_item_scene: PackedScene

@export var grid_width: int = 10
@export var grid_height: int = 5

var grid: Array[ItemData] = []
var visual_map: Dictionary = {} # ItemData -> InventoryItem(Node2D)

var held_item_intersects: bool = false

# ✅ ОПТИМИЗАЦИЯ: кэширование и проверка движения мыши
var cached_held_visual: Node2D = null
var last_mouse_pos := Vector2.ZERO

@onready var inventory_manager = InventoryManage

func _ready() -> void:
	create_slots()
	init_grid()

func create_slots() -> void:
	columns = grid_width
	for y in range(grid_height):
		for x in range(grid_width):
			var slot = inventory_slot_scene.instantiate()
			add_child(slot)

func init_grid() -> void:
	grid.resize(grid_width * grid_height)
	grid.fill(null)

# ✅ ОПТИМИЗИРОВАННЫЙ _process
func _process(_delta: float) -> void:
	# Кэшируем вместо поиска каждый кадр
	if not is_instance_valid(cached_held_visual):
		cached_held_visual = get_tree().get_first_node_in_group("held_item")
	
	var held_visual = cached_held_visual

	if held_visual:
		var current_mouse = get_global_mouse_position()
		
		# Обновляем ТОЛЬКО если мышь двинулась > 5px
		if current_mouse.distance_to(last_mouse_pos) > 5.0:
			last_mouse_pos = current_mouse
			
			if get_global_rect().has_point(current_mouse):
				held_item_intersects = true
				update_highlight()
			else:
				held_item_intersects = false
				clear_highlights()
	else:
		cached_held_visual = null
		if held_item_intersects:
			held_item_intersects = false
			clear_highlights()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if shift_pressed:
				handle_shift_click()
			else:
				handle_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			handle_right_click()

## Shift+ЛКМ: если открыт второй инвентарь (например сундук) — быстро переносим
## предмет туда (сундук <-> игрок). Если второго инвентаря нет — экипируем в
## хотбар, но ТОЛЬКО из инвентаря самого игрока (из сундука экипировка запрещена).
func handle_shift_click() -> void:
	var mouse_grid_pos = screen_to_grid(get_global_mouse_position())
	var item = get_item_at(mouse_grid_pos)
	if item == null:
		return
	
	# 1) Быстрый перенос в другой открытый инвентарь (сундук <-> игрок)
	if transfer_item_to_other(item):
		return
	
	# 2) Иначе — экипировка в хотбар, но только из инвентаря игрока
	if not _is_player_inventory():
		return
	
	var hotbar = get_tree().root.find_child("Hotbar", true, false)
	if not hotbar or not hotbar.has_method("try_equip_item"):
		return
	
	if hotbar.try_equip_item(item):
		print("Предмет экипирован в хотбар: ", item.name)
	else:
		print("Не удалось экипировать предмет в хотбар")


## true, если эта сетка принадлежит инвентарю самого игрока.
func _is_player_inventory() -> bool:
	var player: Node = Global.player
	if player == null:
		player = get_tree().root.find_child("Player", true, false)
	if player == null:
		return false
	return _get_inventory_root() == player.get("player_inventory")


## Возвращает второй открытый инвентарь (сундук, если мы в инвентаре игрока,
## и наоборот), либо null, если второго инвентаря нет.
func _find_other_inventory() -> Node:
	var my_root: Node = _get_inventory_root()
	var player: Node = Global.player
	if player == null:
		player = get_tree().root.find_child("Player", true, false)
	if player == null:
		return null
	var player_inv: Node = player.get("player_inventory")
	var external_inv: Node = player.get("external_inventory")
	if my_root == player_inv and external_inv != null and external_inv.visible:
		return external_inv
	if my_root == external_inv and player_inv != null and player_inv.visible:
		return player_inv
	return null


## Переносит предмет в другой открытый инвентарь. Возвращает true при успехе.
func transfer_item_to_other(item: ItemData) -> bool:
	var other_inv: Node = _find_other_inventory()
	if other_inv == null:
		return false
	var other_grid: Node = other_inv.get("item_grid")
	if other_grid == null or other_grid == self:
		return false
	var visual: Node2D = _get_visual(item)
	var origin: Vector2i = get_item_origin(item)
	# Убираем из текущей сетки
	pick_up_item_from_grid(item)
	# Пытаемся положить в другую сетку
	if other_grid.try_add_item(item, visual):
		return true
	# Не хватило места — откатываем обратно
	if origin != Vector2i(-1, -1):
		try_add_item_at(item, visual, origin)
	else:
		try_add_item(item, visual)
	return false


# =========================================================
# Helpers: найти корень Inventory и корректно репарентить предметы
# =========================================================

func _get_inventory_root() -> Node:
	var p: Node = self
	while p:
		if p.has_method("add_item"):
			return p
		p = p.get_parent()
	return null

func _reparent_to_inventory_root(visual_node: Node2D) -> void:
	var inv_root = _get_inventory_root()
	if inv_root == null:
		return

	if visual_node.get_parent() != inv_root:
		if visual_node.get_parent():
			visual_node.get_parent().remove_child(visual_node)
		inv_root.add_child(visual_node)

func _get_visual(item: ItemData) -> Node2D:
	if not visual_map.has(item):
		return null
	var v = visual_map[item]
	if not is_instance_valid(v):
		visual_map.erase(item)
		return null
	return v

# =========================================================
# Подсветка
# =========================================================

func clear_highlights() -> void:
	for slot in get_children():
		if slot.has_method("set_state"):
			slot.set_state(InventorySlot.SlotState.DEFAULT)

func highlight_cells(origin: Vector2i, item_size: Vector2i, state: InventorySlot.SlotState) -> void:
	for y in range(item_size.y):
		for x in range(item_size.x):
			var idx = index_from_pos(origin + Vector2i(x, y))
			if idx >= 0 and idx < get_child_count():
				var slot = get_child(idx)
				if slot.has_method("set_state"):
					slot.set_state(state)

func update_highlight() -> void:
	clear_highlights()

	var held_visual = cached_held_visual
	if not held_visual or not held_item_intersects:
		return

	var held_item: ItemData = held_visual.data
	var item_px_size = Vector2(held_item.get_size()) * SLOT_SIZE
	var grid_pos = get_grid_pos_centered(item_px_size)
	var item_size = held_item.get_size()

	# 1) Свободно -> VALID
	if can_place_item(held_item, grid_pos):
		highlight_cells(grid_pos, item_size, InventorySlot.SlotState.VALID)
		return

	# 2) Стакинг -> VALID
	var mouse_grid_pos = screen_to_grid(get_global_mouse_position())
	var item_under_mouse = get_item_at(mouse_grid_pos)
	if item_under_mouse and item_under_mouse != held_item:
		if item_under_mouse.name == held_item.name and item_under_mouse.amount < item_under_mouse.max_stack_size:
			var target_origin = get_item_origin(item_under_mouse)
			highlight_cells(target_origin, Vector2i(1, 1), InventorySlot.SlotState.VALID)
			return

	# 3) SWAP -> SWAP
	var overlapping_items = get_unique_items_in_area(grid_pos, item_size)
	if overlapping_items.size() == 1:
		var target_item: ItemData = overlapping_items[0]
		var target_visual: Node2D = _get_visual(target_item)

		if target_visual == null:
			highlight_cells(grid_pos, item_size, InventorySlot.SlotState.INVALID)
			return

		var held_rect = Rect2(held_visual.global_position, held_visual.size)
		var target_rect = Rect2(target_visual.global_position, target_visual.size)

		if held_rect.intersects(target_rect):
			var intersection = held_rect.intersection(target_rect)
			var intersection_area = intersection.size.x * intersection.size.y
			var min_area = min(held_rect.size.x * held_rect.size.y, target_rect.size.x * target_rect.size.y)

			if (intersection_area / min_area) > 0.5:
				var target_origin = get_item_origin(target_item)

				_silent_pick_up(target_item)
				var can_swap = can_place_item(held_item, grid_pos)
				_silent_place(target_item, target_origin)

				if can_swap:
					highlight_cells(grid_pos, item_size, InventorySlot.SlotState.SWAP)
					return

	# 4) Нельзя -> INVALID
	highlight_cells(grid_pos, item_size, InventorySlot.SlotState.INVALID)

# =========================================================
# "Тихие" функции
# =========================================================

func _silent_pick_up(item: ItemData) -> void:
	for i in range(grid.size()):
		if grid[i] == item:
			grid[i] = null

func _silent_place(item: ItemData, origin: Vector2i) -> void:
	var s = item.get_size()
	for dy in range(s.y):
		for dx in range(s.x):
			var idx = index_from_pos(origin + Vector2i(dx, dy))
			grid[idx] = item

# =========================================================
# Клики
# =========================================================

func handle_left_click() -> void:
	var held_visual = cached_held_visual
	
	# 1) Взять предмет
	if not held_visual:
		var grid_pos = screen_to_grid(get_global_mouse_position())
		var item = get_item_at(grid_pos)
		if item:
			var v = _get_visual(item)
			if v:
				# Сообщаем менеджеру о взятии предмета
				var inventory_node = _get_inventory_root()
				inventory_manager.pick_up(item, v, self, inventory_node)
				pick_up_item_from_grid(item)
				v.get_picked_up()
		return
	
	# 2) Действия с предметом в руке
	var held_item: ItemData = held_visual.data
	var item_px_size = Vector2(held_item.get_size()) * SLOT_SIZE
	var dest_grid_pos = get_grid_pos_centered(item_px_size)
	
	# Получаем информацию об источнике
	var source_info = inventory_manager.get_source()
	
	# A) Положить в пустое место
	if can_place_item(held_item, dest_grid_pos):
		# Если источник - другой инвентарь, удаляем оттуда
		if source_info.grid != self and source_info.grid:
			source_info.grid.pick_up_item_from_grid(held_item)
		
		place_item(held_item, dest_grid_pos, held_visual)
		held_visual.get_placed(grid_to_screen(dest_grid_pos))
		
		# Сообщаем менеджеру о размещении
		inventory_manager.place(held_item, held_visual)
		clear_highlights()
		return
	
	# B) Стакинг
	var mouse_grid_pos = screen_to_grid(get_global_mouse_position())
	var item_under_mouse = get_item_at(mouse_grid_pos)
	
	if item_under_mouse and item_under_mouse != held_item:
		if item_under_mouse.try_merge(held_item):
			update_existing_visual(item_under_mouse)
			
			if held_item.amount <= 0:
				# Удаляем из источника
				if source_info.grid:
					source_info.grid.pick_up_item_from_grid(held_item)
				
				held_visual.queue_free()
				inventory_manager.clear()
			else:
				held_visual.update_visual()
			
			clear_highlights()
			return
	
	# C) SWAP
	var overlapping_items = get_unique_items_in_area(dest_grid_pos, held_item.get_size())
	if overlapping_items.size() == 1:
		var target_item: ItemData = overlapping_items[0]
		var target_visual: Node2D = _get_visual(target_item)
		if target_visual == null:
			return
		
		var held_rect = Rect2(held_visual.global_position, held_visual.size)
		var target_rect = Rect2(target_visual.global_position, target_visual.size)
		
		if held_rect.intersects(target_rect):
			var intersection = held_rect.intersection(target_rect)
			var intersection_area = intersection.size.x * intersection.size.y
			var min_area = min(held_rect.size.x * held_rect.size.y, target_rect.size.x * target_rect.size.y)
			
			if (intersection_area / min_area) > 0.5:
				var target_origin = get_item_origin(target_item)
				
				# Убираем целевой предмет из текущего инвентаря
				pick_up_item_from_grid(target_item)
				
				if can_place_item(held_item, dest_grid_pos):
					# Если источник - другой инвентарь, удаляем оттуда
					if source_info.grid != self and source_info.grid:
						source_info.grid.pick_up_item_from_grid(held_item)
					
					# Кладём держимый предмет
					place_item(held_item, dest_grid_pos, held_visual)
					held_visual.get_placed(grid_to_screen(dest_grid_pos))
					
					# Обновляем менеджер - теперь держим целевой предмет
					inventory_manager.place(held_item, held_visual)
					inventory_manager.pick_up(target_item, target_visual, self, _get_inventory_root())
					
					# Берём целевой предмет в руку
					target_visual.get_picked_up()
				else:
					# Возвращаем целевой предмет на место
					place_item(target_item, target_origin, target_visual)
				
				clear_highlights()

func handle_right_click() -> void:
	var held_visual = cached_held_visual
	
	# --- СЦЕНАРИЙ 1: Предмет в руке (выкладываем поштучно) ---
	if held_visual:
		var held_data: ItemData = held_visual.data
		if not held_data.stackable: return
		
		var source_info = inventory_manager.get_source()
		var mouse_grid_pos = screen_to_grid(get_global_mouse_position())
		var item_under_mouse = get_item_at(mouse_grid_pos)
		
		if item_under_mouse == null:
			var item_px_size = Vector2(held_data.get_size()) * SLOT_SIZE
			var place_pos = get_grid_pos_centered(item_px_size)
			if can_place_item(held_data, place_pos):
				var single_data = held_data.duplicate()
				single_data.amount = 1
				var new_visual = inventory_item_scene.instantiate()
				new_visual.data = single_data
				place_item(single_data, place_pos, new_visual)
				held_data.amount -= 1
				if held_data.amount <= 0:
					if source_info.grid: source_info.grid.pick_up_item_from_grid(held_data)
					held_visual.queue_free()
					inventory_manager.clear()
				else: 
					held_visual.update_visual()
				clear_highlights()
			return
			
		if item_under_mouse.name == held_data.name and item_under_mouse.amount < item_under_mouse.max_stack_size:
			item_under_mouse.amount += 1
			held_data.amount -= 1
			update_existing_visual(item_under_mouse)
			if held_data.amount <= 0:
				if source_info.grid: source_info.grid.pick_up_item_from_grid(held_data)
				held_visual.queue_free()
				inventory_manager.clear()
			else: 
				held_visual.update_visual()
			clear_highlights()

	# --- СЦЕНАРИЙ 2: Рука пуста (открываем контекстное меню) ---
	else:
		var mouse_grid_pos = screen_to_grid(get_global_mouse_position())
		var item = get_item_at(mouse_grid_pos)
		if item == null: return
		
		var inv_root = _get_inventory_root()
		if inv_root and inv_root.has_method("_on_item_right_clicked"):
			inv_root._on_item_right_clicked(item, get_global_mouse_position())

# =========================================================
# API (для сундуков/очистки)
# =========================================================

func clear_grid_data_only() -> void:
	grid.fill(null)
	visual_map.clear()
	cached_held_visual = null
	clear_highlights()

func export_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var processed: Array[ItemData] = []

	for i in range(grid.size()):
		var it: ItemData = grid[i]
		if it and not processed.has(it):
			processed.append(it)
			result.append({"data": it, "origin": get_item_origin(it)})

	return result

func try_add_item(item: ItemData, visual_node: Node2D) -> bool:
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if can_place_item(item, pos):
				place_item(item, pos, visual_node)
				return true
	return false

func try_add_item_at(item: ItemData, visual_node: Node2D, origin: Vector2i) -> bool:
	if origin.x < 0 or origin.y < 0:
		return false

	if can_place_item(item, origin):
		place_item(item, origin, visual_node)
		return true

	return false

# =========================================================
# Служебные функции сетки
# =========================================================

func get_grid_pos_centered(item_size_px: Vector2) -> Vector2i:
	var mouse_pos = get_global_mouse_position()
	var top_left_world = mouse_pos - item_size_px / 2.0
	var snap_offset = Vector2(SLOT_SIZE / 2.0, SLOT_SIZE / 2.0)
	return screen_to_grid(top_left_world + snap_offset)

func get_unique_items_in_area(origin: Vector2i, item_size: Vector2i) -> Array[ItemData]:
	var found_items: Array[ItemData] = []
	for y in range(item_size.y):
		for x in range(item_size.x):
			var pos = origin + Vector2i(x, y)
			var item = get_item_at(pos)
			if item and not found_items.has(item):
				found_items.append(item)
	return found_items

func place_item(item: ItemData, origin: Vector2i, visual_node: Node2D) -> void:
	_reparent_to_inventory_root(visual_node)

	var s = item.get_size()
	for dy in range(s.y):
		for dx in range(s.x):
			var idx = index_from_pos(origin + Vector2i(dx, dy))
			grid[idx] = item

	visual_map[item] = visual_node
	cached_held_visual = null

	var pixel_pos = grid_to_screen(origin)
	visual_node.set_grid_position(pixel_pos)

	refresh_slot_amounts()

func pick_up_item_from_grid(item: ItemData) -> void:
	for i in range(grid.size()):
		if grid[i] == item:
			grid[i] = null
	visual_map.erase(item)
	cached_held_visual = null
	refresh_slot_amounts()

func update_existing_visual(item: ItemData) -> void:
	var v = _get_visual(item)
	if v:
		v.update_visual()
	refresh_slot_amounts()

func refresh_slot_amounts() -> void:
	for child in get_children():
		if child.has_method("clear_amount"):
			child.clear_amount()

	var processed_items: Array = []
	for i in range(grid.size()):
		var item = grid[i]
		if item and not processed_items.has(item):
			processed_items.append(item)

			var last_idx := -1
			for j in range(grid.size()):
				if grid[j] == item:
					last_idx = j

			if last_idx != -1:
				var slot_node = get_child(last_idx)
				if slot_node.has_method("set_amount"):
					slot_node.set_amount(str(item.amount))

func can_place_item(item: ItemData, origin: Vector2i) -> bool:
	var s = item.get_size()

	if origin.x + s.x > grid_width or origin.y + s.y > grid_height:
		return false
	if origin.x < 0 or origin.y < 0:
		return false

	for dy in range(s.y):
		for dx in range(s.x):
			var idx = index_from_pos(origin + Vector2i(dx, dy))
			if idx < 0 or idx >= grid.size():
				return false
			if grid[idx] != null:
				return false

	return true

func get_item_at(grid_pos: Vector2i) -> ItemData:
	var idx = index_from_pos(grid_pos)
	if idx >= 0 and idx < grid.size():
		return grid[idx]
	return null

func get_item_origin(item: ItemData) -> Vector2i:
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if get_item_at(pos) == item:
				return pos
	return Vector2i(-1, -1)

func index_from_pos(pos: Vector2i) -> int:
	return pos.x + pos.y * grid_width

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local = screen_pos - global_position
	return Vector2i(int(local.x / SLOT_SIZE), int(local.y / SLOT_SIZE))

func grid_to_screen(grid_pos: Vector2i) -> Vector2:
	return global_position + Vector2(grid_pos) * SLOT_SIZE

# Функция для обработки закрытия инвентаря
func on_inventory_closed() -> void:
	# Если держим предмет и он не из этого инвентаря - возвращаем
	if inventory_manager and inventory_manager.has_held():
		var source_info = inventory_manager.get_source()
		if source_info.grid != self:
			# Предмет из другого инвентаря - возвращаем
			inventory_manager.return_item()
		
		# Сбрасываем состояние
		cached_held_visual = null
		held_item_intersects = false
		clear_highlights()
