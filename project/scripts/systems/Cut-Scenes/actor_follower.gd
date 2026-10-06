extends PathFollow2D
class_name ActorFollower
## Ведёт актёра (CharacterBody2D) вдоль Path2D. Используется катсценами:
## синхронизирует скорость, направление и анимацию ходьбы.

## Сигнал: актёр дошёл до конца пути.
signal finished

## Скорость движения по пути (px/сек).
@export var speed: float = 100.0
## Путь к актёру, если он не задан напрямую.
@export var actor_path: NodePath
## Режим катсцены (актёр управляется катсценой).
@export var cutscene_mode: bool = true

## Управляемый актёр.
var actor: CharacterBody2D = null
## Идёт ли движение.
var is_moving: bool = false

## Запускает движение актёра по кривой.
func start() -> void:
	if is_moving:
		return
		
	if not actor and actor_path:
		actor = get_node_or_null(actor_path) as CharacterBody2D

	if not actor:
		push_error("ActorFollower: не назначен актёр")
		return

	progress = 0.0
	is_moving = true
	set_process(true)

## Каждый кадр двигает актёра к следующей точке кривой и обновляет анимацию.
func _process(delta: float) -> void:
	if not is_moving or not actor:
		return

	var total_length = get_parent().curve.get_baked_length()
	var next_progress = progress + speed * delta

	if next_progress >= total_length:
		_finish()
		return

	progress = next_progress

	var target_local = get_parent().curve.sample_baked(progress)
	var target_pos = get_parent().global_position + target_local
	var direction = (target_pos - actor.global_position).normalized()

	if direction.length() < 0.01:
		_finish()
		return

	actor.velocity = direction * speed

	if "input_direction" in actor:
		actor.input_direction = direction
	if "last_direction" in actor and actor.has_method("get_clean_direction"):
		actor.last_direction = actor.get_clean_direction(direction)

	# Синхронизируем скорость анимации с текущей скоростью движения
	if "animation_speed" in actor:
		actor.animation_speed = speed / 100.0   # 100 – базовая скорость
	if "footstep_pitch" in actor:
		actor.footstep_pitch = clamp(speed / 100.0, 0.7, 2.0)

## Завершает движение: гасит скорость и восстанавливает анимацию; шлёт сигнал finished.
func _finish() -> void:
	is_moving = false
	set_process(false)
	if actor and is_instance_valid(actor):
		actor.velocity = Vector2.ZERO
		if "input_direction" in actor:
			actor.input_direction = Vector2.ZERO
		if "animation_speed" in actor:
			actor.animation_speed = 1.0   # возвращаем стандартную скорость
		if "footstep_pitch" in actor:
			actor.footstep_pitch = 1.0
	finished.emit()
