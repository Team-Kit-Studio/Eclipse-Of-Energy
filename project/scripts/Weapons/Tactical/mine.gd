class_name Mine
extends Area2D
## Мина-растяжка: ставится рядом с игроком, взводится с задержкой (с отсчётом над
## миной) и при пересечении любой сущности с HealthComponent (включая игрока)
## взрывается и исчезает.

const TacticalDataScript = preload("res://project/scripts/Weapons/Tactical/tactical_data.gd")

## Ресурс снаряда (TacticalData): задержка взведения, параметры взрыва.
var _data: TacticalDataScript
## Урон взрыва (берётся из ItemData.damage).
var _damage: int = 0
## Оставшееся время взведения (сек). Пока > 0 — мина не срабатывает.
var _arm_left: float = 0.0
var _armed: bool = false
var _exploded: bool = false
var _configured: bool = false

@onready var _countdown: Label = $Countdown

## Настраивает мину. Вызывать после add_child и установки global_position.
## placer оставлен в сигнатуре для совместимости: мина теперь опасна и для него.
func setup(data: TacticalDataScript, damage: int, _placer: Node = null) -> void:
	_data = data
	_damage = damage
	_arm_left = data.arm_time
	_configured = true
	_update_countdown()

## Отсчёт взведения: пока мина не активна — показываем цифры над ней.
func _process(delta: float) -> void:
	if not _configured or _exploded or _armed:
		return
	_arm_left -= delta
	if _arm_left <= 0.0:
		_arm()
	else:
		_update_countdown()

func _arm() -> void:
	_armed = true
	_arm_left = 0.0
	if _countdown:
		_countdown.visible = false
	# Если сущность уже стоит на мине в момент взведения — срабатываем сразу.
	for body in get_overlapping_bodies():
		if _try_detonate(body):
			return

func _update_countdown() -> void:
	if _countdown:
		_countdown.text = str(maxi(int(ceil(_arm_left)), 0))

func _on_body_entered(body: Node2D) -> void:
	if _exploded or not _armed:
		return
	_try_detonate(body)

## Пытается подорвать мину от переданного тела. Возвращает true, если подорвалась.
func _try_detonate(body: Node) -> bool:
	if body == null:
		return false
	var entity := _resolve_entity(body)
	if entity == null:
		return false
	_detonate()
	return true

## Поднимается от коллайдера вверх до сущности, умеющей получать урон.
func _resolve_entity(collider: Object) -> Node:
	var node := collider as Node
	while node and node != self:
		if node.has_method("take_damage") or node.has_method("apply_knockback"):
			return node
		node = node.get_parent()
	return null

func _detonate() -> void:
	if _exploded:
		return
	_exploded = true
	_spawn_explosion()
	queue_free()

func _spawn_explosion() -> void:
	if _data == null or _data.explosion_scene_path.is_empty():
		return
	var scene: PackedScene = load(_data.explosion_scene_path)
	if scene == null:
		push_error("Mine: не удалось загрузить сцену взрыва: " + _data.explosion_scene_path)
		return
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	var explosion: Node = scene.instantiate()
	root.add_child(explosion)
	if explosion is Node2D:
		(explosion as Node2D).global_position = global_position
	if explosion.has_method("setup"):
		# Мина опасна для всех, включая установившего.
		explosion.setup(_data.explosion_radius, _damage, _data.knockback_force, _data.knockback_duration, null, _data.explosion_texture, _data.sfx_path)
