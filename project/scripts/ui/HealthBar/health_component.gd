extends Node2D
class_name HealthComponent
## Компонент здоровья сущности. Хранит текущее/максимальное HP, сообщает о
## уроне/лечении/смерти и показывает всплывающее число урона.

## Сигнал: сущность получила урон (величина).
signal on_unit_damaged(amount: float)
## Сигнал: сущность вылечена (величина).
signal on_unit_healed(amount: float)
## Сигнал: сущность погибла.
signal on_unit_dead

## Сцена всплывающего числа урона.
const DAMAGE_POPUP_SCENE: PackedScene = preload("res://project/scenes/ui/HealthBar/damage_popup.tscn")

## Показывать ли всплывающие числа урона над сущностью.
@export var show_damage_popup: bool = true

## Текущее здоровье.
var current_health: float
## Максимальное здоровье.
var max_health: float

## Инициализирует здоровье (текущее = максимальное).
func init_health(value: float) -> void:
	current_health = value
	max_health = value

## Наносит урон: уменьшает HP, шлёт сигнал и число урона; при HP <= 0 — смерть.
func take_damage(value: float) -> void:
	if current_health > 0.0:
		current_health -= value
		on_unit_damaged.emit(value)
		_spawn_damage_popup(value)
		if current_health <= 0.0:
			die()

## Убивает сущность (HP = 0 + сигнал on_unit_dead).
func die() -> void:
	print("Я умер")
	current_health = 0.0
	on_unit_dead.emit()

## Лечит сущность (не выше максимума).
func heal(value: float) -> void:
	if current_health >= max_health:
		return
	current_health = min(max_health, current_health + value)
	on_unit_healed.emit(value)

## Показывает число урона над сущностью; цвет — по остатку здоровья.
func _spawn_damage_popup(value: float) -> void:
	if not show_damage_popup or DAMAGE_POPUP_SCENE == null:
		return
	var ratio: float = current_health / max_health if max_health > 0.0 else 0.0
	var popup: Node = DAMAGE_POPUP_SCENE.instantiate()
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(popup)
	if popup is Node2D:
		(popup as Node2D).global_position = global_position + Vector2(0, -18)
	if popup.has_method("setup"):
		popup.setup(value, ratio)
