extends StaticBody2D
## Сундук-контейнер: хранит предметы и открывает внешний инвентарь игрока по F.

## Менеджер перетаскивания предметов.
@onready var inventory_manager = InventoryManage

## Изначальные предметы — задаются в инспекторе.
@export var storage: Array[ItemData] = []

## Сохранённая раскладка сундука (после первого открытия/перетаскиваний).
## Формат: [{ "data": ItemData, "origin": Vector2i }, ...]
var saved_layout: Array[Dictionary] = []

## Панель-подсказка взаимодействия.
@onready var hint_marker: Panel = $Panel

## При старте прячет подсказку взаимодействия.
func _ready() -> void:
	if hint_marker:
		hint_marker.visible = false

## Показывает/скрывает подсказку при наведении игрока.
func set_highlight(is_active: bool) -> void:
	if hint_marker:
		hint_marker.visible = is_active

## Открывает/закрывает инвентарь этого сундука (вызывается игроком по F).
func player_interact() -> void:
	# После реорганизации дерева UI ExternalInventory живёт в сцене игрока (Arena),
	# поэтому берём его через Global.player, а не по жёсткому пути /root/Main/UI/...
	var player = Global.player
	if player == null:
		return
	var external_inventory = player.external_inventory
	if external_inventory == null:
		return
	
	if external_inventory.visible and external_inventory.is_bound_to(self):
		# Закрываем этот сундук
		external_inventory.close_container()
	else:
		# Если держим предмет из другого инвентаря - сначала закроем всё
		if inventory_manager and inventory_manager.has_held():
			var source_info = inventory_manager.get_source()
			if source_info.inventory != external_inventory:
				if player and player.has_method("close_all_inventories"):
					player.close_all_inventories()
		
		# Открываем этот сундук
		external_inventory.open_container(self)

## Возвращает предметы сундука для UI. При первом открытии — копии (origin = авторасстановка).
func get_inventory_layout() -> Array[Dictionary]:
	# Если ещё ни разу не сохраняли раскладку — отдадим "просто предметы",
	# чтобы UI сам их разложил (origin = (-1,-1) значит "авторасстановка").
	if saved_layout.is_empty():
		var layout: Array[Dictionary] = []
		for it in storage:
			if it == null:
				continue
			# Дублируем ресурс: иначе сундук отдаёт ССЫЛКУ на общий .tres, и
			# использование/экипировка предмета в одном месте ломает его в другом.
			layout.append({"data": it.duplicate(), "origin": Vector2i(-1, -1)})
		return layout

	return saved_layout

## Сохраняет раскладку сундука при закрытии и синхронизирует список storage.
func set_inventory_layout(layout: Array[Dictionary]) -> void:
	saved_layout = layout

	# Обновляем storage, чтобы список предметов в сундуке соответствовал факту
	storage.clear()
	for e in saved_layout:
		if e.has("data") and e["data"] != null:
			storage.append(e["data"])
