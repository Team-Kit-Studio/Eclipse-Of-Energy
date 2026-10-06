extends Node2D
class_name Bullet
## Единая сцена пули (bullet_base.tscn) + ресурс BulletData.
## Пуля летит swept-лучом: перед каждым шагом проверяет пространство впереди,
## поэтому гаснет у самой поверхности стены (не просвечивает сквозь неё и не
## тунелирует на высокой скорости) и наносит урон врагам.

## Общие маски физических слоёв (см. game_layers.gd).
const Layers = preload("res://project/scripts/core/game_layers.gd")

## Ресурс пули (BulletData): текстура, скорость, урон, дальность, эффекты.
var data: BulletData
## Тело стрелка (игрок) — пуля не задевает его (исключается из запроса).
var shooter: Node2D = null
## Пройденная дистанция — чтобы пуля исчезала после data.travel_range.
var _traveled: float = 0.0

## Спрайт пули (текстура берётся из data.texture).
@onready var sprite: Sprite2D = $Sprite2D

## Настраивает пулю: применяет ресурс и запоминает стрелка.
## Вызывать после add_child и установки global_position/global_rotation.
func setup(p_data: BulletData, p_shooter: Node2D) -> void:
	data = p_data
	shooter = p_shooter
	apply_data()

## Применяет визуал из ресурса пули (текстуру).
func apply_data() -> void:
	if data and data.texture and sprite:
		sprite.texture = data.texture

## Движение swept-лучом. Луч выносится вперёд на половину длины пули, поэтому
## пуля гаснет у поверхности стены, а не входит в неё на кадр (и не тунелирует).
func _physics_process(delta: float) -> void:
	if not data:
		return
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var step: float = data.bullet_speed * delta
	var reach: float = step + _half_length()

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + forward * reach,
		Layers.BULLET_BLOCKERS | Layers.ENEMY
	)
	if shooter is CollisionObject2D:
		query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_on_hit(hit.get("collider"))
		return

	global_position += forward * step
	_traveled += step
	if data.travel_range > 0.0 and _traveled >= data.travel_range:
		queue_free()

## Половина длины пули в мире (по текстуре) — на неё выносим луч вперёд.
func _half_length() -> float:
	if data and data.texture and sprite:
		return data.texture.get_size().x * 0.5 * sprite.global_scale.x
	return 8.0

## Попадание: наносит урон цели (если умеет получать урон) и уничтожает пулю.
func _on_hit(collider: Object) -> void:
	if data.damage > 0 and collider is Node and (collider as Node).has_method("take_damage"):
		(collider as Node).take_damage(data.damage)
	queue_free()