class_name Explosion
extends Node2D
## Общий взрыв для гранат и мин: AoE-урон + отбрасывание сущностей в радиусе.
## Визуал — процедурная вспышка-плейсхолдер; при желании подставляется своя
## текстура (explosion_texture) и звук (sfx_path) без правки кода.

## Слои поражаемых сущностей: игрок и враги (союзные НПС исключены).
const Layers = preload("res://project/scripts/core/game_layers.gd")
const ENTITY_MASK: int = Layers.PLAYER | Layers.ENEMY
## Базовый радиус полигона-вспышки (до масштабирования под actual radius).
const BASE_RADIUS: float = 24.0

var _radius: float = 100.0
var _damage: int = 0
var _knockback_force: float = 0.0
var _knockback_duration: float = 0.25
var _ignore: Node = null

@onready var _visual: Polygon2D = $Visual
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

## Настраивает и запускает взрыв. Вызывать после add_child и установки global_position.
## ignore — узел, который взрыв НЕ задевает (например, установивший мину).
func setup(
	radius: float,
	damage: int,
	knockback_force: float,
	knockback_duration: float,
	ignore: Node = null,
	texture: Texture2D = null,
	sfx_path: String = ""
) -> void:
	_radius = radius
	_damage = damage
	_knockback_force = knockback_force
	_knockback_duration = knockback_duration
	_ignore = ignore
	if texture and _sprite:
		_sprite.texture = texture
	_play_audio(sfx_path)
	_apply_damage()
	_play_visual()

# ─────────────────────── Урон и отбрасывание ───────────────────────

func _apply_damage() -> void:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = ENTITY_MASK

	var hits := space.intersect_shape(params, 32)
	var damaged: Dictionary = {}
	for hit in hits:
		var entity := _resolve_entity(hit.get("collider"))
		if entity == null or entity == _ignore or damaged.has(entity):
			continue
		damaged[entity] = true
		_damage_entity(entity)

## Поднимается от коллайдера вверх до сущности, умеющей получать урон.
func _resolve_entity(collider: Object) -> Node:
	var node := collider as Node
	while node and node != self:
		if node.has_method("take_damage") or node.has_method("apply_knockback"):
			return node
		node = node.get_parent()
	return null

func _damage_entity(entity: Node) -> void:
	if _damage > 0 and entity.has_method("take_damage"):
		entity.take_damage(_damage)
	if _knockback_force > 0.0 and entity.has_method("apply_knockback"):
		var dir := Vector2.RIGHT
		if entity is Node2D:
			dir = (entity as Node2D).global_position - global_position
			dir = Vector2.RIGHT if dir.length() < 0.001 else dir.normalized()
		entity.apply_knockback(dir, _knockback_force, _knockback_duration)

# ─────────────────────── Визуал и звук ───────────────────────

func _play_audio(sfx_path: String) -> void:
	if sfx_path.is_empty() or _audio == null:
		return
	var stream: AudioStream = load(sfx_path)
	if stream != null:
		_audio.stream = stream
		_audio.play()

func _play_visual() -> void:
	var target_scale: float = _radius / BASE_RADIUS
	var has_texture: bool = _sprite != null and _sprite.texture != null

	var obj: Node2D
	if has_texture:
		_visual.visible = false
		_sprite.visible = true
		obj = _sprite
	else:
		_sprite.visible = false
		_visual.visible = true
		obj = _visual

	obj.scale = Vector2.ONE * (target_scale * 0.3)
	obj.modulate = Color(1.0, 0.85, 0.4, 0.9)

	var tween := create_tween()
	var grow := tween.tween_property(obj, "scale", Vector2.ONE * target_scale, 0.18)
	grow.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(obj, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
