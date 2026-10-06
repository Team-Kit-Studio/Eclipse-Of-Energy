extends PanelContainer
class_name Hotbar
## Панель быстрого доступа (хотбар).
## Содержит 6 слотов для оружия и расходников.

enum SlotType {
	PRIMARY,        # Слот 1: Основное оружие
	SECONDARY,      # Слот 2: Второе оружие
	TACTICAL,       # Слот 3: Боевые расходники
	MEDICAL,        # Слот 4: Медицинские расходники
	FREE,           # Слот 5: Свободный
	FREE_2          # Слот 6: Свободный
}

signal slot_changed(slot_index: int, item: ItemData)
signal item_used(item: ItemData)
## Испускается при смене активного (выбранного) слота хотбара.
signal active_slot_changed(index: int)

const SLOT_SIZE: int = 64
const LARGE_SLOT_SIZE: int = 128

@onready var slots_container: HBoxContainer = $MarginContainer/SlotsContainer

## Массив слотов хотбара
var slots: Array[HotbarSlot] = []
## Индекс выбранного слота (для визуального выделения); -1 = выделения нет.
var selected_slot_index: int = -1
## Индекс активного слота (выбранного цифрами); -1 = оружие не вынуто.
var active_slot_index: int = -1

## Кулдаун для колесика мыши
var wheel_cooldown: float = 0.0

func _ready() -> void:
	_initialize_slots()
	_setup_input_actions()
	# На старте активного слота нет: обводка не показывается, оружие не вынуто.
	# Активация слота — только цифрами (или кликом), а не колесиком.
	active_slot_index = -1
	selected_slot_index = -1
	_update_slot_visuals()

func _process(delta: float) -> void:
	if wheel_cooldown > 0:
		wheel_cooldown -= delta

func _initialize_slots() -> void:
	var slot_types: Array[SlotType] = [
		SlotType.PRIMARY, SlotType.SECONDARY, SlotType.TACTICAL, 
		SlotType.MEDICAL, SlotType.FREE, SlotType.FREE_2
	]
	
	for i in range(slot_types.size()):
		var slot_node: InventorySlot = slots_container.get_child(i) as InventorySlot
		if slot_node == null:
			push_error("Hotbar: слот %d не является InventorySlot!" % i)
			continue
		var hotbar_slot = HotbarSlot.new(slot_node, slot_types[i], i)
		slots.append(hotbar_slot)
		
		# Слоты хотбара принимают клики мыши
		slot_node.clickable = true
		
		# Подключаем ЛКМ (снятие по Shift+клику). Контекстное меню из слотов
		# хотбара НЕ показываем — оно доступно только в инвентаре.
		slot_node.slot_clicked.connect(_on_slot_clicked.bind(i))

## Настройка действий ввода для клавиш 1-4
func _setup_input_actions() -> void:
	for i in range(slots.size()):
		var action_name = "hotbar_%d" % (i + 1)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key = InputEventKey.new()
			key.keycode = KEY_1 + i
			InputMap.action_add_event(action_name, key)

func _unhandled_input(event: InputEvent) -> void:
	# ВАЖНО: клики ЛКМ/ПКМ обрабатываются самими слотами хотбара (_gui_input).
	# Здесь мы НЕ перехватываем мышь глобально, чтобы не мешать инвентарю и меню.
	if event is InputEventMouseButton:
		# Колесико переключает слоты ТОЛЬКО если слот уже активирован
		# (оружие «достали»). Активация из «холодного» состояния — только цифрами.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and wheel_cooldown <= 0.0:
			if active_slot_index != -1:
				_change_active_slot(-1)
				wheel_cooldown = 0.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and wheel_cooldown <= 0.0:
			if active_slot_index != -1:
				_change_active_slot(1)
				wheel_cooldown = 0.15
		return

	for i in range(slots.size()):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_slot_by_key(i)

## Переключение активного слота колесиком мыши (работает только при активном слоте).
func _change_active_slot(direction: int) -> void:
	if slots.size() == 0 or active_slot_index == -1: return
	active_slot_index += direction
	if active_slot_index < 0:
		active_slot_index = slots.size() - 1
	elif active_slot_index > slots.size() - 1:
		active_slot_index = 0
	select_slot(active_slot_index)

## Активация слота по клавише 1-4.
## Повторное нажатие уже активной цифры — убирает оружие (дезактивирует слот).
func _select_slot_by_key(index: int) -> void:
	if index == active_slot_index:
		active_slot_index = -1
		select_slot(-1)
		return
	select_slot(index)
	active_slot_index = index
	# Медицинские расходники используются сразу при выборе слота.
	# Тактические (гранаты/мины) — НЕ здесь: они бросаются/ставятся по ЛКМ.
	var slot = slots[index]
	if slot.item_data and slot.item_data.is_medical():
		_use_item(slot)

## Визуально выделяет слот. index = -1 снимает выделение (никакой слот не активен).
func select_slot(index: int) -> void:
	if index < -1 or index >= slots.size(): return
	selected_slot_index = index
	_update_slot_visuals()
	active_slot_changed.emit(index)

## Возвращает предмет в указанном слоте хотбара (или null, если слот пустой/неверный).
func get_slot_item(index: int) -> ItemData:
	if index < 0 or index >= slots.size(): return null
	return slots[index].item_data

func _on_slot_clicked(slot_index: int) -> void:
	# Shift + ЛКМ по слоту хотбара — снять предмет
	if Input.is_key_pressed(KEY_SHIFT):
		_on_slot_shift_click(slot_index)
		return
	# Клик по слоту активирует его; повторный клик по активному — убирает оружие.
	if slot_index == active_slot_index:
		active_slot_index = -1
		select_slot(-1)
	else:
		select_slot(slot_index)
		active_slot_index = slot_index

## Возвращает предмет из хотбара в инвентарь (Shift+Click)
func _on_slot_shift_click(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	
	var slot = slots[slot_index]
	if not slot.item_data:
		return
	
	# Вызываем метод снятия предмета
	_unequip_item(slot)

## Снимает предмет со слота и возвращает в инвентарь
func _unequip_item(slot: HotbarSlot) -> void:
	if not slot.item_data:
		return
	
	var item_name: String = slot.item_data.name
	
	var inventory = _get_player_inventory()
	if not inventory:
		print("Инвентарь не найден")
		return
	
	# Убираем флаг экипировки с предмета в инвентаре (снимаем серый оверлей)
	if inventory.has_method("unequip_item"):
		inventory.unequip_item(slot.item_data)
	
	# Очищаем слот хотбара
	slot.clear()
	slot_changed.emit(slot.index, null)
	print("Предмет снят с хотбара: ", item_name)

## Использует предмет из слота (расходники)
func _use_item(slot: HotbarSlot) -> void:
	if slot.item_data == null: return
	
	slot.item_data.amount -= 1
	item_used.emit(slot.item_data)
	
	var inventory = _get_player_inventory()
	# Синхронизируем количество с визуалом в инвентаре (тот же ресурс)
	if inventory and inventory.has_method("refresh_item_visual"):
		inventory.refresh_item_visual(slot.item_data)
	
	if slot.item_data.amount <= 0:
		if inventory and inventory.has_method("unequip_item"):
			inventory.unequip_item(slot.item_data)
		if inventory and inventory.has_method("_remove_item_from_grid"):
			inventory._remove_item_from_grid(slot.item_data)
		if inventory and inventory.has_method("_remove_visual_item"):
			inventory._remove_visual_item(slot.item_data)
		slot.clear()
		slot_changed.emit(slot.index, null)
	else:
		slot.update_visual()
		slot_changed.emit(slot.index, slot.item_data)

## Расходует одну единицу предмета из активного слота хотбара.
## Используется игроком при броске гранаты / установке мины по ЛКМ.
func consume_active_item() -> void:
	if active_slot_index < 0 or active_slot_index >= slots.size():
		return
	var slot = slots[active_slot_index]
	if slot.item_data == null:
		return
	_use_item(slot)

## Пытается экипировать предмет из инвентаря в хотбар.
## Предмет НЕ удаляется из инвентаря — он остаётся и помечается серым оверлеем.
## В слот хотбара сохраняется ССЫЛКА на оригинальный предмет (не копия),
## чтобы количество и состояние всегда были синхронизированы.
func try_equip_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false
	
	# Если предмет уже экипирован — ничего не делаем
	if _is_item_equipped(item_data):
		return false
	
	var target_slot = _find_suitable_slot(item_data)
	if target_slot == null: 
		print("Нет подходящего слота для: ", item_data.name)
		return false
	
	# Слот занят другим предметом — экипировать нельзя
	if target_slot.item_data != null:
		print("Слот занят: ", target_slot.item_data.name)
		return false
	
	# Слот пустой — экипируем предмет (не удаляя из инвентаря)
	target_slot.set_item(item_data)
	slot_changed.emit(target_slot.index, item_data)
	
	# Помечаем предмет в инвентаре как экипированный (серый оверлей)
	var inventory = _get_player_inventory()
	if inventory and inventory.has_method("equip_item"):
		inventory.equip_item(item_data)
	
	return true

## Проверяет, экипирован ли предмет (по ссылке или item_id) в какой-либо слот хотбара
func _is_item_equipped(item_data: ItemData) -> bool:
	for slot in slots:
		if slot.item_data == null:
			continue
		if slot.item_data == item_data or slot.item_data.item_id == item_data.item_id:
			return true
	return false

## Возвращает инвентарь игрока (PlayerInventory)
func _get_player_inventory() -> Node:
	return get_tree().root.find_child("PlayerInventory", true, false)

## Ищет подходящий пустой слот для предмета
func _find_suitable_slot(item_data: ItemData) -> HotbarSlot:
	for slot in slots:
		if slot.item_data == null and slot.can_accept_item(item_data):
			return slot
	return null

## Снимает предмет из инвентаря по ссылке (вызывается из контекстного
## меню инвентаря: ПКМ по экипированному предмету -> "Снять").
## Ищет слот хотбара, в котором лежит этот предмет, и освобождает его.
func unequip_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false
	for slot in slots:
		if slot.item_data == null:
			continue
		if slot.item_data == item_data or slot.item_data.item_id == item_data.item_id:
			_unequip_item(slot)
			return true
	return false

## Обновляет визуальное состояние всех слотов
func _update_slot_visuals() -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		slot.slot_node.set_state(InventorySlot.SlotState.SELECTED if i == selected_slot_index else InventorySlot.SlotState.DEFAULT)
		slot.update_visual()
