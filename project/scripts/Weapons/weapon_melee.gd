class_name WeaponMelee
extends Weapon
## Оружие ближнего боя (ножи, мечи). По ЛКМ выполняет взмах (анимация) и наносит
## урон всем сущностям в радиусе data.attack_range перед владельцем.
## Сцена та же для всех мечей/ножей — различие только в ресурсе .tres.

## Слои сущностей, по которым бьёт ближний бой: игрок и враги (союзники исключены).
const Layers = preload("res://project/scripts/core/game_layers.gd")
const ENTITY_MASK: int = Layers.PLAYER | Layers.ENEMY

## Спрайт оружия (текстура берётся из data.texture).
@onready var sprite: Sprite2D = %Sprite2D
## Узел замаха — его вращение анимируется (сам Pivot смотрит на курсор).
@onready var swing: Node2D = $Pivot/Swing
## Точка на клинке (задаётся из data.muzzle_offset) — для эффектов/вспышек.
@onready var marker: Marker2D = %Marker2D

## Таймер до следующего удара (сек). При 0 можно бить.
var cooldown: float = 0.0
## Твин текущего взмаха (чтобы перезапускать и возвращать клинок в стойку).
var _swing_tween: Tween = null

## Угол замаха (в градусах) в каждую сторону от направления взгляда.
@export var swing_angle_deg: float = 75.0
## Длительность одного взмаха (сек).
@export var swing_time: float = 0.16

func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	# Бьём по ЛКМ только когда оружие экипировано и задан ресурс.
	if not visible or data == null:
		return
	# Пока открыт инвентарь — ЛКМ нужен для переноса предметов, не бьём.
	var pl: Node = Global.player
	if pl and pl.has_method("is_inventory_open") and pl.is_inventory_open():
		return
	if Input.is_action_pressed("Atack") and cooldown <= 0.0:
		Atack()
		cooldown = data.fire_rate

## Экипирует оружие: принимает ресурс (.tres), настраивает текстуру и показывает сцену.
func equip(item_data: ItemData) -> void:
	data = item_data
	apply_data()
	visible = true

## Снимает оружие: прячет сцену.
func unequip() -> void:
	visible = false

## Применяет текстуру и смещения из ресурса оружия.
func apply_data() -> void:
	if data and data.texture and sprite:
		sprite.texture = data.texture
	if sprite:
		sprite.position = data.sprite_offset if data else Vector2(18, 0)
		sprite.scale = data.sprite_scale if data else Vector2.ONE
	if marker and data:
		marker.position = data.muzzle_offset

## Удар: визуальный взмах + урон по сущностям в радиусе перед владельцем.
func Atack() -> void:
	if data == null:
		return
	_play_swing()
	_apply_melee_damage()

## Быстрый взмах: клинок проходит дугу и возвращается в стойку (вдоль прицела).
func _play_swing() -> void:
	if swing == null:
		return
	var half: float = deg_to_rad(swing_angle_deg)
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(swing, "rotation", -half, 0.0)
	var strike := _swing_tween.tween_property(swing, "rotation", half, swing_time)
	strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Возврат в стойку (0° — клинок смотрит вдоль прицела).
	var recover := _swing_tween.tween_property(swing, "rotation", 0.0, swing_time * 0.6)
	recover.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## Наносит урон сущностям в круге перед владельцем (радиус = attack_range).
func _apply_melee_damage() -> void:
	var reach: float = maxf(data.attack_range, 8.0)
	var shooter: Node2D = _get_shooter()
	var dir := Vector2.RIGHT
	if pivot:
		dir = pivot.global_transform.x.normalized()
	var origin: Vector2 = (shooter.global_position if shooter else global_position) + dir * reach * 0.5

	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = reach * 0.6
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, origin)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = ENTITY_MASK

	var hits := space.intersect_shape(params, 32)
	var damaged: Dictionary = {}
	for hit in hits:
		var entity := _resolve_entity(hit.get("collider"))
		if entity == null or entity == shooter or damaged.has(entity):
			continue
		damaged[entity] = true
		if entity.has_method("take_damage"):
			entity.take_damage(data.damage)

## Поднимается от коллайдера вверх до сущности, умеющей получать урон.
func _resolve_entity(collider: Object) -> Node:
	var node := collider as Node
	while node and node != self:
		if node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null

## Возвращает тело-владельца оружия (игрока) — его удар не задевает.
func _get_shooter() -> Node2D:
	var node: Node = self
	while node and not (node is CharacterBody2D):
		node = node.get_parent()
	return node as Node2D
