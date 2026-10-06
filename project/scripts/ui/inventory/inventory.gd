extends PanelContainer
class_name InventoryPanel
## Панель инвентаря игрока.
## Управляет отображением предметов и их состоянием (экипирован/не экипирован).

@export var items: Array[ItemData] = []
@export var inventory_item_scene: PackedScene

@onready var item_grid: Node = %ItemGrid
@onready var inventory_manager = InventoryManage

var bound_container: Node = null
var current_context_menu: ItemContextMenu = null

## Словарь для отслеживания экипированных предметов
## Ключ: item_id предмета, Значение: ссылка на визуальный узел InventoryItem
var equipped_items: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	for item_data in items:
		if item_data: add_item(item_data)

func _get_drop_zone() -> Node: 
	return get_tree().root.find_child("DropZone", true, false)

func _hide_drop_zone_if_needed() -> void:
	var dz = _get_drop_zone()
	if dz and dz.has_method("hide_zone"): 
		dz.hide_zone()

## Добавляет предмет в инвентарь
func add_item(item_data: ItemData) -> void:
	var inventory_item = inventory_item_scene.instantiate()
	inventory_item.data = item_data
	add_child(inventory_item)
	if not item_grid.try_add_item(item_data, inventory_item):
		inventory_item.queue_free()

func _clear_visual_items() -> void:
	for child in get_children():
		if child.is_in_group("inventory_item") and not child.is_in_group("held_item"):
			child.queue_free()

func open_container(container: Node) -> void:
	bound_container = container
	_clear_visual_items()
	item_grid.clear_grid_data_only()
	await get_tree().process_frame
	var layout: Array[Dictionary] = []
	if container and container.has_method("get_inventory_layout"):
		layout = container.get_inventory_layout()
	for e in layout:
		var data: ItemData = e.get("data", null)
		var origin: Vector2i = e.get("origin", Vector2i(-1, -1))
		if data == null: continue
		var inv_item = inventory_item_scene.instantiate()
		inv_item.data = data
		add_child(inv_item)
		if not item_grid.try_add_item_at(data, inv_item, origin):
			if not item_grid.try_add_item(data, inv_item):
				inv_item.queue_free()
	visible = true

func close_container() -> void:
	_hide_drop_zone_if_needed()
	if inventory_manager and inventory_manager.has_held():
		var source_info = inventory_manager.get_source()
		if source_info.inventory == self: pass
		else: inventory_manager.return_item()
	if bound_container and bound_container.has_method("set_inventory_layout"):
		var layout = item_grid.export_layout()
		bound_container.set_inventory_layout(layout)
	if item_grid and item_grid.has_method("on_inventory_closed"):
		item_grid.on_inventory_closed()
	_clear_visual_items()
	bound_container = null
	visible = false

func is_bound_to(container: Node) -> bool: 
	return bound_container == container

func close_player_inventory() -> void:
	_hide_drop_zone_if_needed()
	if inventory_manager and inventory_manager.has_held():
		var source_info = inventory_manager.get_source()
		if source_info.inventory == self: 
			inventory_manager.return_item()
	if item_grid and item_grid.has_method("on_inventory_closed"):
		item_grid.on_inventory_closed()
	visible = false

func has_item_by_id(item_id: String) -> bool:
	if not item_grid: return false
	for item_data in item_grid.grid:
		if item_data != null and item_data.item_id == item_id: return true
	return false

# --- Методы для управления экипировкой ---

## Помечает предмет как экипированный (делает его серым в инвентаре).
## Хотбар хранит ССЫЛКУ на оригинальный предмет, поэтому ищем его по ссылке.
func equip_item(item_data: ItemData) -> void:
	if not item_data:
		return
	
	# Находим визуальный узел предмета
	for child in get_children():
		if child.is_in_group("inventory_item"):
			var child_data: ItemData = child.get("data")
			if child_data == item_data:
				if child.has_method("set_equipped"):
					child.set_equipped(true)
				equipped_items[item_data.item_id] = child
				return

## Убирает флаг экипировки с предмета (возвращает нормальный вид).
func unequip_item(item_data: ItemData) -> void:
	if not item_data:
		return
	
	# Ищем визуальный узел предмета
	for child in get_children():
		if child.is_in_group("inventory_item"):
			var child_data: ItemData = child.get("data")
			if child_data == item_data:
				if child.has_method("set_equipped"):
					child.set_equipped(false)
					print("Предмет снят с экипировки: ", item_data.name)
				if equipped_items.has(item_data.item_id):
					equipped_items.erase(item_data.item_id)
				return

## Обновляет визуал предмета (иконку/количество) после изменения из хотбара
func refresh_item_visual(item_data: ItemData) -> void:
	if item_data and item_grid and item_grid.has_method("update_existing_visual"):
		item_grid.update_existing_visual(item_data)

# --- Методы для контекстного меню ---

func _on_item_right_clicked(item_data: ItemData, at_position: Vector2) -> void:
	if item_data == null:
		return
	
	if current_context_menu != null and current_context_menu.current_item == item_data:
		current_context_menu.close_menu()
		return
	
	if current_context_menu != null:
		current_context_menu.queue_free()
		current_context_menu = null
	
	var context_menu_scene = preload("res://project/scenes/ui/inventory/components/contex_menu.tscn")
	var context_menu = context_menu_scene.instantiate()
	get_tree().root.add_child(context_menu)
	
	current_context_menu = context_menu
	# Если предмет уже экипирован — меню покажет "Снять" вместо "Экипировать"
	var is_equipped: bool = equipped_items.has(item_data.item_id)
	# Экипировать можно только предметы из инвентаря самого игрока
	# (из сундука/чужого инвентаря — нельзя).
	var allow_equip: bool = _is_player_inventory()
	context_menu.setup(item_data, Hotbar.SlotType.FREE, at_position, is_equipped, allow_equip)
	context_menu.action_selected.connect(_on_inventory_context_menu_action.bind(item_data))
	context_menu.menu_closed.connect(_on_menu_closed)

func _on_menu_closed() -> void:
	current_context_menu = null
	var player = get_tree().root.find_child("Player", true, false)
	if player and player.has_method("hide_item_tooltip"):
		player.hide_item_tooltip()

## true, если эта панель — инвентарь самого игрока (не сундук/чужой инвентарь).
func _is_player_inventory() -> bool:
	var player: Node = Global.player
	if player == null:
		player = get_tree().root.find_child("Player", true, false)
	if player == null:
		return false
	return self == player.get("player_inventory")

func _on_inventory_context_menu_action(action: String, item_data: ItemData) -> void:
	match action:
		"equip":
			# Запрещаем экипировку, если предмет не в инвентаре игрока
			if not _is_player_inventory():
				print("Нельзя экипировать предмет из чужого инвентаря/сундука")
				return
			var hotbar = get_tree().root.find_child("Hotbar", true, false)
			if hotbar and hotbar.has_method("try_equip_item"):
				if hotbar.try_equip_item(item_data):
					# Предмет НЕ удаляется из инвентаря, просто помечается как экипированный
					pass
				else:
					print("Невозможно экипировать: нет подходящего слота или он занят")
		"unequip":
			# Снять предмет с хотбара (через ПКМ на экипированном предмете в инвентаре)
			var hotbar = get_tree().root.find_child("Hotbar", true, false)
			if hotbar and hotbar.has_method("unequip_item"):
				if not hotbar.unequip_item(item_data):
					print("Невозможно снять: предмет не найден в хотбаре")
		"use":
			if item_data.is_usable:
				_use_item_from_inventory(item_data)
		"reload":
			if item_data.is_weapon():
				item_data.reload()
				if item_grid: item_grid.update_existing_visual(item_data)
		"unload":
			if item_data.is_weapon() and item_data.ammo_current > 0:
				_unload_weapon_to_inventory(item_data)
		"drop":
			_drop_item_from_inventory(item_data)
		"description":
			var player = get_tree().root.find_child("Player", true, false)
			if player and player.has_method("show_item_tooltip"):
				var menu_pos = current_context_menu.menu_panel.global_position if current_context_menu else Vector2.ZERO
				var menu_size = current_context_menu.menu_panel.size if current_context_menu else Vector2.ZERO
				player.show_item_tooltip(item_data, menu_pos, menu_size)

func _remove_item_from_grid(item_data: ItemData) -> void:
	if item_grid and item_grid.has_method("pick_up_item_from_grid"):
		item_grid.pick_up_item_from_grid(item_data)

func _use_item_from_inventory(item_data: ItemData) -> void:
	item_data.amount -= 1
	if item_data.amount <= 0:
		_remove_item_from_grid(item_data)
		_remove_visual_item(item_data)
	else:
		if item_grid: item_grid.update_existing_visual(item_data)
	
	var player = get_tree().root.find_child("Player", true, false)
	if player and player.has_method("use_consumable"):
		player.use_consumable(item_data)

func _unload_weapon_to_inventory(item_data: ItemData) -> void:
	if item_data.ammo_current <= 0: return
	
	var ammo_item = ItemData.new()
	ammo_item.item_id = item_data.ammo_type
	ammo_item.name = "Патроны"
	ammo_item.amount = item_data.ammo_current
	ammo_item.max_stack_size = 100
	ammo_item.texture = item_data.texture
	
	add_item(ammo_item)
	item_data.ammo_current = 0
	if item_grid: item_grid.update_existing_visual(item_data)

func _drop_item_from_inventory(item_data: ItemData) -> void:
	var player = get_tree().root.find_child("Player", true, false)
	if not player: return
	
	var drop_pos = player.global_position + Vector2(0, 16)
	var drop_scene = preload("res://project/scenes/objects/interactive/drop_item.tscn")
	var dropped = drop_scene.instantiate()
	dropped.set("data", item_data)
	dropped.global_position = drop_pos
	get_tree().current_scene.add_child(dropped)
	
	_remove_item_from_grid(item_data)
	_remove_visual_item(item_data)

func _remove_visual_item(item_data: ItemData) -> void:
	for child in get_children():
		if child.is_in_group("inventory_item") and not child.is_in_group("held_item"):
			if child.has_method("get") and child.get("data") == item_data:
				child.queue_free()
				return
