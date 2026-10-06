class_name Grenade
extends RigidBody2D
## Осколочная граната: бросается по ЛКМ в две фазы — сначала полёт по фиксированному
## расстоянию без вращения, затем «приземление» и катание. Катание вращается по мере
## движения и замедляется; при отскоке от стены направление и вращение меняются.
## По таймеру фитиля взрывается (AoE-урон + отбрасывание).

const TacticalDataScript = preload("res://project/scripts/Weapons/Tactical/tactical_data.gd")

## Ресурс снаряда (TacticalData): скорость броска, фитиль, параметры взрыва.
var _data: TacticalDataScript
## Урон взрыва (берётся из ItemData.damage).
var _damage: int = 0
## Оставшееся время до взрыва (сек).
var _fuse_left: float = 0.0
var _exploded: bool = false

## Фаза движения снаряда.
enum Phase { FLY, ROLL, STOPPED }
var _phase: Phase = Phase.FLY
## Направление броска — вдоль него снаряд летит, а затем катится.
var _dir: Vector2 = Vector2.RIGHT
## Пройденное в полёте расстояние (px): по достижении throw_distance снаряд «падает».
var _traveled: float = 0.0
## Текущая скорость катания (px/сек): затухает от roll_friction.
var _roll_speed: float = 0.0

## Насколько быстро граната «катится»: угловая скорость на единицу линейной (рад/сек на px/сек).
@export var roll_spin: float = 0.06
## Вращать ли снаряд уже во время полёта. По умолчанию false — летит без вращения,
## крутится только при катании (после приземления).
@export var spin_in_flight: bool = false

## Настраивает снаряд. Вызывать после add_child и установки global_position.
func setup(data: TacticalDataScript, damage: int, _thrower: Node) -> void:
	_data = data
	_damage = damage
	gravity_scale = 0.0          # Вид сверху: мировая гравитация не нужна.
	_fuse_left = data.fuse_time
	_phase = Phase.FLY
	_traveled = 0.0
	_roll_speed = 0.0
	angular_velocity = 0.0

func _process(delta: float) -> void:
	if _exploded:
		return
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		_explode()

## Двухфазное движение:
##   FLY     — полёт на фиксированное расстояние БЕЗ вращения;
##   ROLL    — «приземление»: катание, вращение ∝ скорости и следует за фактическим
##             направлением движения (в т.ч. после отскока от стены), с замедлением;
##   STOPPED — снаряд стоит на месте до взрыва.
func _physics_process(delta: float) -> void:
	if _exploded:
		return
	match _phase:
		Phase.FLY:
			_traveled += _data.throw_speed * delta
			if _traveled >= _data.throw_distance:
				_land()
				return
			_apply_motion(_data.throw_speed, spin_in_flight)
		Phase.ROLL:
			_roll_speed = maxf(_roll_speed - _data.roll_friction * delta, 0.0)
			if _roll_speed <= 5.0:
				_phase = Phase.STOPPED
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
				return
			_apply_motion(_roll_speed, true)
		Phase.STOPPED:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0

## Задаёт скорость движения вдоль текущего направления. Направление берётся из
## фактической скорости тела: физика могла развернуть её при отскоке от стены,
## поэтому после рикошета снаряд поедет (и закрутится) в новую сторону.
## spin=false (полёт) — без вращения; spin=true (катание) — вращение ∝ скорости.
func _apply_motion(speed: float, spin: bool) -> void:
	var v := linear_velocity
	if v.length() > 1.0:
		_dir = v.normalized()
	linear_velocity = _dir * speed
	# Катится ровно тогда, когда движется: вращение пропорционально скорости.
	angular_velocity = speed * roll_spin * _dir_sign() if spin else 0.0

## Приземление: переход от полёта к катанию (с более низкой начальной скоростью).
func _land() -> void:
	_phase = Phase.ROLL
	_roll_speed = _data.roll_speed
	linear_velocity = _dir * _roll_speed

## Знак вращения по направлению движения (вправо/вниз — по часовой).
func _dir_sign() -> float:
	var s := signf(_dir.x) if absf(_dir.x) >= absf(_dir.y) else signf(_dir.y)
	return s if s != 0.0 else 1.0

## Инициализирует бросок: направление и первая фаза — полёт без вращения.
func throw(direction: Vector2) -> void:
	_dir = direction.normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT
	_phase = Phase.FLY
	_traveled = 0.0
	_roll_speed = 0.0
	angular_velocity = 0.0
	linear_velocity = _dir * _data.throw_speed

func _explode() -> void:
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
		push_error("Grenade: не удалось загрузить сцену взрыва: " + _data.explosion_scene_path)
		return
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	var explosion: Node = scene.instantiate()
	root.add_child(explosion)
	if explosion is Node2D:
		(explosion as Node2D).global_position = global_position
	if explosion.has_method("setup"):
		# Граната задевает всех в радиусе (включая метателя) — ignore не передаём.
		explosion.setup(_data.explosion_radius, _damage, _data.knockback_force, _data.knockback_duration, null, _data.explosion_texture, _data.sfx_path)
