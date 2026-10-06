@tool
extends Weapon
class_name WeaponRange
## Дальнобойное оружие. Единая сцена, которая меняет свой .tres-ресурс (data).
## Именно здесь будет реализована механика стрельбы и взаимодействия с оружием.

## Единая сцена пули. Все оружия используют ОДНУ сцену снаряда; различие —
## только в ресурсе BulletData (текстура, скорость, урон, дальность, эффекты).
const BULLET_SCENE: PackedScene = preload("res://project/scenes/Weapons/Bullets/bullet_base.tscn")

## Спрайт оружия (текстура берётся из data.texture).
@onready var sprite: Sprite2D = %Sprite2D
## Точка вылета пуль (дуло) — её позиция задаётся из data.muzzle_offset.
@onready var marker: Marker2D = %Marker2D

## Флаг: подписаны ли мы на изменения ресурса data (для мгновенного обновления в редакторе).
var _listening: bool = false
## Таймер до следующего выстрела (в секундах). При 0 можно стрелять.
var cooldown: float = 0.0

## Последние применённые позиции спрайта/дула — чтобы в редакторе замечать изменения .tres.
var _applied_sprite: Vector2 = Vector2(18, 0)
var _applied_muzzle: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	# В редакторе (@tool) каждый кадр проверяем, не изменились ли позиции в ресурсе .tres
	# (например muzzle_offset). Если изменились — пере-применяем, не требуя переоткрытия сцены.
	if Engine.is_editor_hint():
		if data and (data.muzzle_offset != _applied_muzzle or data.sprite_offset != _applied_sprite):
			apply_data()
		return

	# В игре: стрельба по ЛКМ — только когда оружие экипировано (visible) и есть ресурс data.
	if not visible or data == null:
		return
	# Пока открыт инвентарь — не стреляем: ЛКМ нужен для переноса предметов,
	# и стрельба с открытым инвентарём сбивает игрока.
	var pl: Node = Global.player
	if pl and pl.has_method("is_inventory_open") and pl.is_inventory_open():
		cooldown = maxf(cooldown - delta, 0.0)
		return
	cooldown = maxf(cooldown - delta, 0.0)
	if Input.is_action_pressed("Atack") and cooldown <= 0.0:
		Atack()
		cooldown = data.fire_rate

func _ready() -> void:
	# @tool: применяем data и в редакторе, чтобы сразу видеть текстуру оружия,
	# назначив data на ноду WeaponRangeBase в инспекторе (без запуска проекта).
	# В игре data на старте пуст (задаётся через equip), поэтому ничего не ломается.
	_listen_to_data()
	if data:
		apply_data()
	

func _exit_tree() -> void:
	# Отписываемся при удалении ноды, чтобы не оставлять «висячие» соединения.
	_unlisten_to_data()

## Подписываемся на сигнал changed ресурса: при изменении .tres (например muzzle_offset)
## редактор мгновенно пере-применит визуал (спрайт и маркер).
func _listen_to_data() -> void:
	if data and not data.changed.is_connected(_on_data_changed):
		data.changed.connect(_on_data_changed)
		_listening = true

## Отписываемся от сигнала changed ресурса.
func _unlisten_to_data() -> void:
	if data and data.changed.is_connected(_on_data_changed):
		data.changed.disconnect(_on_data_changed)
		_listening = false

## Обработчик изменения ресурса: пере-применяем спрайт и позицию дула.
func _on_data_changed() -> void:
	if data:
		apply_data()

## Атака: создаёт пулю (единая сцена BULLET_SCENE + ресурс data.bullet) у дула (marker)
## и разворачивает её в сторону прицела.
func Atack() -> void:
	# Безопасно: стреляем только когда оружие экипировано и задан ресурс пули.
	if data == null or data.bullet == null:
		return
	var shooter: Node2D = _get_shooter()
	# Дробовик выпускает несколько дробинок за выстрел (data.projectiles).
	var pellets: int = maxi(data.projectiles, 1)
	# Пули добавляем в КОРЕНЬ сцены, а не в оружие: при развороте игрока контроллер
	# оружия получает scale.x = -1, и пули-дети наследовали бы это зеркалирование
	# (летели бы в обратную сторону/отражались). В корне сцены масштаб = 1.
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	for i in pellets:
		var bullet: Bullet = BULLET_SCENE.instantiate()
		# Важно: сначала добавляем пулю в дерево, и только потом задаём глобальные
		# позицию/поворот. Если задать global_position ДО add_child, у безродительской
		# ноды global == local, и в локальную позицию запишутся МИРОВЫЕ координаты
		# маркера — пуля получит двойное смещение и вылетит не из дула.
		scene_root.add_child(bullet)
		bullet.setup(data.bullet, shooter)
		bullet.global_position = marker.global_position
		bullet.global_rotation = pivot.global_rotation + deg_to_rad(randf_range(-data.spread, data.spread))

## Возвращает тело-владельца оружия (игрока), чтобы пуля при спавне не сталкивалась
## с собственным телом стрелка и не уничтожала сама себя (collision_layer игрока = 2).
func _get_shooter() -> Node2D:
	var node: Node2D = self
	while node and not (node is CharacterBody2D):
		node = node.get_parent() as Node2D
	return node

## Экипирует оружие: принимает ресурс (.tres), настраивает текстуру и показывает сцену.
## Вызывается контроллером, когда активный слот хотбара содержит оружие.
func equip(item_data: ItemData) -> void:
	data = item_data
	_listen_to_data()
	apply_data()
	visible = true

## Снимает оружие: прячет сцену (слот больше не активен / пуст).
func unequip() -> void:
	visible = false

## Применяет текстуру из выбранного .tres-ресурса оружия (data.texture)
## и позиции спрайта/дула (sprite_offset, muzzle_offset) — под каждый ствол.
func apply_data() -> void:
	if data and data.texture:
		sprite.texture = data.texture
	# Позиции спрайта и точки вылета пуль настраиваются в ресурсе оружия
	sprite.position = data.sprite_offset if data else Vector2(18, 0)
	marker.position = data.muzzle_offset if data else Vector2.ZERO
	# Масштаб спрайта тоже настраивается в ресурсе оружия
	sprite.scale = data.sprite_scale if data else Vector2.ONE
	# Запоминаем применённые значения (для отслеживания изменений в редакторе)
	_applied_sprite = data.sprite_offset if data else Vector2(18, 0)
	_applied_muzzle = data.muzzle_offset if data else Vector2.ZERO
