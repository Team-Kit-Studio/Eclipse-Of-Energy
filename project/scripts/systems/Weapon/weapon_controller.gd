extends Node2D
class_name WeaponController
## Контроллер оружия в руках игрока. Поддерживает два типа сцен:
##   • дальнобойное (weapon_range_base.tscn) — стреляет снарядами;
##   • ближнего боя (weapon_melee_base.tscn) — машет по ЛКМ.
## Активный слот хотбара передаёт ресурс (.tres), а контроллер сам выбирает сцену
## по item_data.attack_mode — одна точка входа обслуживает оба типа.

## Сцена оружия ближнего боя (дальнобойная уже стоит как дочерний $Weapon).
const MELEE_SCENE: PackedScene = preload("res://project/scenes/Weapons/Melee/weapon_melee_base.tscn")

## Направление на курсор (используется для зеркалирования спрайта).
var direction: Vector2

## Дальнобойное оружие (дочерний узел из сцены игрока).
@onready var ranged_weapon: Weapon = $Weapon
## Оружие ближнего боя — создаётся лениво, только когда нужно.
var melee_weapon: Weapon = null
## Текущее активное оружие (на него работает и прицеливание).
var active_weapon: Weapon = null

## Исходное боковое смещение оружия от контроллера (позиция «в руке»).
## Сохраняется в _ready и восстанавливается при горизонтальном взгляде.
var _base_weapon_x: float = 0.0

## Скорость плавного перехода боковой позиции оружия между «в руке» и «по центру».
## Больше = быстрее (реактивнее), меньше = плавнее/медленнее.
@export var position_lerp_speed: float = 14.0
## Насколько оружие приподнимается вверх (по Y, вверх = отрицательное значение)
## при взгляде вверх. Остальные направления не влияют.
@export var up_raise: float = 16.0
## Насколько оружие смещается вниз (по Y, вниз = положительное значение)
## при взгляде вниз. Остальные направления не влияют.
@export var down_raise: float = 16.0

func _ready() -> void:
	_base_weapon_x = ranged_weapon.position.x
	active_weapon = ranged_weapon

func _process(_delta: float) -> void:
	rotate_weapon()

## Передаёт ресурс оружия (.tres) из активного слота хотбара. Сцена оружия
## выбирается по типу атаки (дальнобойное / ближний бой).
## item_data == null или не-оружие -> оружие убирается.
func set_weapon(item_data: ItemData) -> void:
	if ranged_weapon == null:
		return
	var is_weapon: bool = item_data != null and item_data.is_weapon()
	if not is_weapon:
		_unequip_all()
		return
	if item_data.is_melee():
		_ensure_melee()
		if ranged_weapon.visible:
			ranged_weapon.unequip()
		active_weapon = melee_weapon
	else:
		if melee_weapon and melee_weapon.visible:
			melee_weapon.unequip()
		active_weapon = ranged_weapon
	active_weapon.equip(item_data)

## Создаёт сцену оружия ближнего боя (однократно) на месте «в руке».
func _ensure_melee() -> void:
	if melee_weapon != null:
		return
	melee_weapon = MELEE_SCENE.instantiate()
	add_child(melee_weapon)
	melee_weapon.position = Vector2(_base_weapon_x, 0)

## Убирает всё оружие (нет активного слота с оружием).
func _unequip_all() -> void:
	ranged_weapon.unequip()
	if melee_weapon:
		melee_weapon.unequip()
	active_weapon = ranged_weapon

## Наводит оружие на курсор.
## - Зеркалирование scale.x всегда по знаку X (пересечение центра/оси игрока), а не по сектору,
##   чтобы оружие переворачивалось ровно в момент, когда курсор проходит через ось X.
## - Секторная логика (вверх/вниз/в сторону) задаёт позицию оружия:
##   при взгляде вверх — по центру, слегка приподнято и за спиной игрока (z=-1);
##   при взгляде вниз — по центру перед игроком (z=1);
##   при горизонтальном взгляде — в руке (z=1).
##   Позиция между секторами сглаживается (lerp), поэтому оружие не дёргается.
func rotate_weapon() -> void:
	if not visible or active_weapon == null:
		return
	# Пока открыт инвентарь — не прицеливаемся (оружие замирает в текуном положении).
	var pl: Node = Global.player
	if pl and pl.has_method("is_inventory_open") and pl.is_inventory_open():
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	direction = mouse_pos - global_position
	active_weapon.pivot.look_at(mouse_pos)

	# Зеркалирование: вправо/прямо = +|scale.x|, влево = -|scale.x| (по пересечению центра).
	scale.x = abs(scale.x) if direction.x >= 0 else -abs(scale.x)

	# Целевая позиция оружия: в руке (_base_weapon_x) при горизонтальном взгляде,
	# ровно по центру игрока при взгляде вверх/вниз.
	# Контроллер может быть смещён в сторону (position.x != 0) ради «руки», поэтому
	# чтобы оружие вставало по центру игрока, компенсируем это смещение: x = -position.x / scale.x
	# (учитывает и зеркалирование при взгляде влево, т.к. scale.x меняет знак).
	var center_x: float = -position.x / scale.x
	var target: Vector2
	if abs(direction.y) > abs(direction.x):
		if direction.y < 0:
			# Взгляд вверх: оружие по центру, слегка приподнято и спрятано
			# за спиной игрока (z_index = -1).
			target = Vector2(center_x, -up_raise)
			z_index = -1
		else:
			# Взгляд вниз: оружие по центру перед игроком, смещено вниз (down_raise).
			target = Vector2(center_x, down_raise)
			z_index = 1
	else:
		# Горизонтальный взгляд: оружие в руке.
		target = Vector2(_base_weapon_x, 0)
		z_index = 1

	# Плавно доводим позицию до целевого значения (без рывков при смене сектора)
	var pull: float = minf(1.0, position_lerp_speed * get_process_delta_time())
	active_weapon.position = active_weapon.position.lerp(target, pull)
