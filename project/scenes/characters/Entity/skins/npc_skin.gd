class_name NPCSkin
extends Resource
## Скин НПС: набор анимаций по направлениям.
##
## Позволяет для ЛЮБОГО НПС задать произвольное число скинов. Для каждого
## направления (вверх/вниз/влево/вправо) можно указать анимацию стойки, ходьбы
## и атаки. Анимации берутся либо из AnimationPlayer (стандартный скелет НПС),
## либо — если задан [member sprite_frames] — напрямую из AnimatedSprite2D.
##
## Для боковых спрайтов без направлений (например, Криптозавр) достаточно
## заполнить «общие» поля [member idle], [member run], [member attack].

## Уникальный идентификатор скина (используется в [code]set_skin[/code] и
## [member NPC.default_skin]).
@export var skin_id: String = "default"

## Свои кадры для скина. Если заданы — AnimatedSprite2D анимируется ими напрямую,
## а имена анимаций берутся из полей ниже.
@export var sprite_frames: SpriteFrames
## Масштаб спрайта для этого скина (применяется только при заданных [member sprite_frames]).
@export var sprite_scale: Vector2 = Vector2.ONE
## Смещение спрайта для этого скина (применяется только при заданных [member sprite_frames]).
@export var sprite_offset: Vector2 = Vector2.ZERO
## Цвет-модуляция спрайта (тон/перекраска персонажа этим скином).
@export var modulate: Color = Color.WHITE
## Инвертировать разворот спрайта. Включи, если спрайт по умолчанию смотрит
## ВПРАВО (тогда при движении вправо его нужно отражать).
@export var flip_facing: bool = false

@export_group("Общие (для боковых спрайтов без направлений)")
## Имя анимации стойки (используется, если для направления ничего не задано).
@export var idle: StringName
## Имя анимации ходьбы (используется, если для направления ничего не задано).
@export var run: StringName
## Имя анимации атаки (используется, если для направления ничего не задано).
@export var attack: StringName

@export_group("Стойка — по направлениям")
@export var idle_up: StringName
@export var idle_down: StringName
@export var idle_left: StringName
@export var idle_right: StringName

@export_group("Ходьба — по направлениям")
@export var run_up: StringName
@export var run_down: StringName
@export var run_left: StringName
@export var run_right: StringName

@export_group("Атака — по направлениям")
@export var attack_up: StringName
@export var attack_down: StringName
@export var attack_left: StringName
@export var attack_right: StringName


## Возвращает имя анимации для состояния ("idle"/"run"/"attack") и направления
## ("up"/"down"/"left"/"right"). Сначала ищет анимацию для направления, затем —
## общую. Возвращает пустую строку, если ничего не задано.
func get_animation(state: String, dir: String) -> StringName:
	var per_dir: Dictionary = _direction_table(state)
	var d: StringName = per_dir.get(dir, &"")
	if d != &"":
		return d
	return _generic(state)


## «Общая» (не привязанная к направлению) анимация состояния.
func _generic(state: String) -> StringName:
	match state:
		"run":
			return run
		"attack":
			return attack
	return idle


func _direction_table(state: String) -> Dictionary:
	match state:
		"run":
			return {"up": run_up, "down": run_down, "left": run_left, "right": run_right}
		"attack":
			return {"up": attack_up, "down": attack_down, "left": attack_left, "right": attack_right}
	return {"up": idle_up, "down": idle_down, "left": idle_left, "right": idle_right}