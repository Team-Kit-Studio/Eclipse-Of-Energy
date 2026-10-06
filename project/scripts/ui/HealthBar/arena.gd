extends Node2D
class_name Arena
## Корневой узел сцены UI игрока (Arena).
## Служит единой точкой конфигурации данных игрока в сцене игрока.
## Здесь настраивается стартовый инвентарь, который при запуске
## переносится в PlayerInventory. В будущем здесь же будет HP и т.д.

## Стартовые предметы инвентаря. Настраиваются в сцене игрока (Arena),
## затем передаются в PlayerInventory при инициализации.
@export var starting_inventory: Array[ItemData] = []

@onready var player_inventory: InventoryPanel = $UI/PlayerUI/PlayerInventory
@onready var external_inventory: InventoryPanel = $UI/PlayerUI/ExternalInventory
@onready var hotbar: Hotbar = $UI/PlayerUI/Hotbar
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var skills_bar: TextureProgressBar = %SkillsBar

func _ready() -> void:
	# Ждём кадр, чтобы PlayerInventory успел создать слоты сетки,
	# после чего переносим в него стартовые данные инвентаря.
	await get_tree().process_frame
	_transfer_inventory_to_player()
	EventBus.on_player_health_updated.connect(_on_player_health_updated)

## Переносит стартовые данные инвентаря из Arena в PlayerInventory.
func _transfer_inventory_to_player() -> void:
	if player_inventory == null:
		return
	for item in starting_inventory:
		if item:
			player_inventory.add_item(item)

## Обновляет значение полосы здоровья при изменении HP игрока.
func _on_player_health_updated(current: float, _max: float) -> void:
	health_bar.value = current
