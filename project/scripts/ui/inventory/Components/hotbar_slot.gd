extends RefCounted
class_name HotbarSlot
## Обёртка слота хотбара: хранит предмет и правила, что слот принимает.

## Узел-слот, тип слота, индекс и текущий предмет.
var slot_node: InventorySlot
var slot_type: Hotbar.SlotType
var index: int
var item_data: ItemData = null

## Конструктор: создаёт слот по узлу, типу и индексу.
func _init(node: InventorySlot, type: Hotbar.SlotType, idx: int) -> void:
	slot_node = node
	slot_type = type
	index = idx

## Проверяет, подходит ли предмет данному слоту (по типу оружия/размеру).
func can_accept_item(item: ItemData) -> bool:
	match slot_type:
		Hotbar.SlotType.PRIMARY:
			return item.weapon_type == ItemData.WeaponType.PRIMARY
		Hotbar.SlotType.SECONDARY:
			return item.weapon_type == ItemData.WeaponType.SECONDARY
		Hotbar.SlotType.TACTICAL:
			return item.weapon_type == ItemData.WeaponType.CONSUMABLE_TACTICAL
		Hotbar.SlotType.MEDICAL:
			return item.weapon_type == ItemData.WeaponType.CONSUMABLE_MEDICAL
		Hotbar.SlotType.FREE, Hotbar.SlotType.FREE_2:
			# Свободные слоты принимают только предметы 1x1
			return item.get_size() == Vector2i(1, 1)
	return false

## Кладёт предмет в слот и обновляет визуал.
func set_item(item: ItemData) -> void:
	item_data = item
	update_visual()

## Очищает слот.
func clear() -> void:
	item_data = null
	slot_node.clear_item()

## Обновляет иконку и количество в слоте.
func update_visual() -> void:
	if item_data != null:
		slot_node.set_item_icon(item_data.texture)
		if item_data.stackable and item_data.amount > 1:
			slot_node.set_amount(str(item_data.amount))
		else:
			slot_node.clear_amount()
	else:
		slot_node.clear_item()
