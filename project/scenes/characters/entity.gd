extends CharacterBody2D
class_name BaseEntity

@export var data: EntityData

# Узлы визуализации
@onready var visuals: Node2D = $visuals
@onready var shadow_sprite: AnimatedSprite2D = $visuals/Shadow
@onready var main_sprite: AnimatedSprite2D = $visuals/Sprites
@onready var anim_player: AnimationPlayer = $visuals/Anim
@onready var audio_sfx: AudioStreamPlayer2D = $AudioSFX 
@onready var health_component: HealthComponent = $HealthComponent

var can_move: bool = true
var is_being_controlled_by_cutscene: bool = false

var input_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2i = Vector2i.DOWN
var current_skin: String = ""
var was_moving: bool = false
var is_running: bool = true # По умолчанию игрок бежит

# Отбрасывание (knockback) от взрывов: пока таймер активен, тело движется
# заданной скоростью, игнорируя обычное управление, и постепенно затухает.
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_time_left: float = 0.0

func _ready() -> void:
	if not data:
		push_error("EntityData не назначена для %s" % name)
		return
	
	current_skin = data.default_skin
	if data.footstep_sound and audio_sfx:
		audio_sfx.stream = data.footstep_sound
		if audio_sfx.stream is AudioStreamMP3 or audio_sfx.stream is AudioStreamOggVorbis:
			audio_sfx.stream.loop = true

func _physics_process(delta: float) -> void:
	# Виртуальный метод для ввода. Переопределяется в Player.gd
	_handle_input()

	# Отбрасывание от взрыва перекрывает обычное движение.
	if _knockback_time_left > 0.0:
		_knockback_time_left -= delta
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, data.friction * delta)
		_update_animation()
		move_and_slide()
		return

	if is_being_controlled_by_cutscene or not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, data.friction * delta)
		_stop_footsteps()
		move_and_slide()
		# Во время катсцены актёр может двигаться по пути (ActorFollower задаёт velocity
		# и input_direction). Обновляем анимацию, чтобы проигрывалась ходьба в сторону движения,
		# а не застывшая idle-анимация.
		_update_animation()
		return

	_handle_movement(delta)
	move_and_slide()
	_check_footsteps()

# --- Виртуальные методы (переопределяются в наследниках) ---
func _handle_input() -> void:
	pass # По умолчанию сущность не реагирует на ввод (подходит для NPC/образцов)

# В функции _handle_movement(delta) замените расчет скорости:
func _handle_movement(delta: float) -> void:
	# Выбираем скорость из ресурса в зависимости от состояния
	var current_speed = data.run_speed if is_running else data.walk_speed
	
	var target_velocity = input_direction * current_speed
	var accel_value = data.acceleration if input_direction != Vector2.ZERO else data.friction
	velocity = velocity.move_toward(target_velocity, accel_value * delta)
	_update_animation()

# --- Общие методы ---
func _update_animation() -> void:
	var is_moving = velocity.length() > 10.0
	
	if is_moving:
		last_direction = _get_clean_direction(_get_move_facing())
	
	if last_direction == Vector2i.ZERO:
		last_direction = Vector2i.DOWN

	var skin_data = data.get_skin_data(current_skin)
	if not skin_data: return

	var anim_name = ""
	match last_direction:
		Vector2i.DOWN:
			anim_name = skin_data.anim_run_down if is_moving else skin_data.anim_idle_down
		Vector2i.UP:
			anim_name = skin_data.anim_run_up if is_moving else skin_data.anim_idle_up
		Vector2i.LEFT, Vector2i.RIGHT:
			anim_name = skin_data.anim_run_side if is_moving else skin_data.anim_idle_side

	if not anim_player.is_playing() or anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
	if not shadow_sprite.is_playing() or shadow_sprite.animation != anim_name:
		shadow_sprite.play(anim_name)

	if last_direction.x != 0:
		var flip = last_direction.x > 0 
		main_sprite.flip_h = flip
		shadow_sprite.flip_h = flip

func _get_clean_direction(raw_input: Vector2) -> Vector2i:
	if abs(raw_input.y) > abs(raw_input.x):
		return Vector2i(0, int(sign(raw_input.y)))
	return Vector2i(int(sign(raw_input.x)), 0) if raw_input.x != 0 else Vector2i.ZERO

## Направление «взгляда» при движении. По умолчанию (NPC) — по ходу движения.
## Игрок переопределяет этот метод, чтобы всегда смотреть в сторону прицела (курсора),
## даже когда двигается в другую сторону.
func _get_move_facing() -> Vector2:
	return input_direction if input_direction != Vector2.ZERO else velocity.normalized()

func _check_footsteps() -> void:
	if velocity.length() > 10.0 and audio_sfx and not audio_sfx.playing:
		audio_sfx.play()
	elif velocity.length() <= 10.0:
		_stop_footsteps()

func _stop_footsteps() -> void:
	if audio_sfx and audio_sfx.playing:
		audio_sfx.stop()

func set_skin(skin_name: String) -> void:
	if data.get_skin_data(skin_name):
		current_skin = skin_name
		_update_animation()
	else:
		push_error("Скин '%s' не найден в EntityData" % skin_name)

func set_is_controlled(flag: bool) -> void:
	is_being_controlled_by_cutscene = flag

## Единая точка нанесения урона сущности (используется снарядами/взрывами).
func take_damage(amount: float) -> void:
	if health_component and amount > 0.0:
		health_component.take_damage(amount)

## Отбрасывание от взрыва: тело летит в заданном направлении и затухает,
## временно перекрывая обычное управление (см. _physics_process).
func apply_knockback(direction: Vector2, force: float, duration: float) -> void:
	if direction == Vector2.ZERO or force <= 0.0:
		return
	_knockback_velocity = direction.normalized() * force
	_knockback_time_left = maxf(duration, 0.0)



func _on_health_component_on_unit_damaged(_amount: float) -> void:
	EventBus.on_player_health_updated.emit(health_component.current_health, data.max_hp)


func _on_health_component_on_unit_dead() -> void:
	can_move = false
	hide()


func _on_health_component_on_unit_healed(_amount: float) -> void:
	# Обновляем бар HP и при лечении (раньше событие шло только при уроне).
	EventBus.on_player_health_updated.emit(health_component.current_health, data.max_hp)
