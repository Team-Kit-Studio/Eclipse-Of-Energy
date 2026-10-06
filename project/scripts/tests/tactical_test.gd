extends Node2D
## Автотест тактических механик: взрыв (AoE + отбрасывание), бросок гранаты, мина.
## Запускается как обычная сцена; в консоль печатает строки TEST_*: true/false.

const EXPLOSION_SCENE := "res://project/scenes/Weapons/Tactical/explosion.tscn"
const GRENADE_SCENE := "res://project/scenes/Weapons/Tactical/grenade.tscn"
const MINE_SCENE := "res://project/scenes/Weapons/Tactical/mine.tscn"
const MELEE_SCENE := "res://project/scenes/Weapons/Melee/weapon_melee_base.tscn"
const GRENADE_DATA := "res://project/data/Resources/items/Tactical/tactical_grenade_frag.tres"
const MINE_DATA := "res://project/data/Resources/items/Tactical/tactical_mine.tres"
const SWORD_DATA := "res://project/data/Resources/Weapons/Primary/weapon_sword.tres"
const BULLET_SCENE := "res://project/scenes/Weapons/Bullets/bullet_base.tscn"
const BULLET_MG := "res://project/data/Resources/Weapons/bullet/bullet_machinegun.tres"
const DUMMY_SCRIPT := "res://project/scripts/tests/dummy_entity.gd"
const HEALTH_SCENE := "res://project/scenes/ui/HealthBar/health_component.tscn"

@onready var dummy: Node2D = $Dummy

func _ready() -> void:
	# Даём физике зарегистрировать тело dummy.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _test_explosion()
	await _test_grenade()
	await _test_grenade_bounce()
	await _test_melee()
	await _test_mine_triggers_on_placer()
	await _test_mine()
	await _test_bullet_wall()
	await _test_bullet_enemy()
	await _test_bullet_ally()
	await _test_damage_popup()
	print("TESTS_DONE")
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _test_explosion() -> void:
	var before: int = dummy.get("hp")
	var scene: PackedScene = load(EXPLOSION_SCENE)
	var ex: Node = scene.instantiate()
	add_child(ex)
	(ex as Node2D).global_position = dummy.global_position
	ex.setup(80.0, 30, 200.0, 0.2, null, null, "")
	await get_tree().process_frame
	print("TEST_EXPLOSION_DAMAGE: ", dummy.get("hp") == before - 30, " (hp=", dummy.get("hp"), ")")
	print("TEST_EXPLOSION_KNOCKBACK: ", dummy.get("knockback_applied"))

func _test_grenade() -> void:
	var tdata = load(GRENADE_DATA)
	var scene: PackedScene = load(GRENADE_SCENE)
	var g: Node = scene.instantiate()
	add_child(g)
	(g as Node2D).global_position = Vector2.ZERO
	g.setup(tdata, 100, null)
	g.throw(Vector2.RIGHT)
	var start_x: float = (g as Node2D).global_position.x
	# Фаза полёта: движение есть, вращения нет.
	await _wait(0.15)
	print("TEST_GRENADE_FLIGHT_MOVES: ", (g as Node2D).global_position.x > start_x + 10.0)
	print("TEST_GRENADE_FLIGHT_NO_SPIN: ", is_equal_approx(g.angular_velocity, 0.0))
	# Пройдено больше throw_distance -> идёт катание: есть вращение и оно замедляется.
	await _wait(0.5)
	print("TEST_GRENADE_ROLL_SPINS: ", absf(g.angular_velocity) > 0.01)
	print("TEST_GRENADE_ROLL_SLOWS: ", g.linear_velocity.length() < tdata.throw_speed)
	g.queue_free()
	await get_tree().process_frame

func _test_grenade_bounce() -> void:
	# Стена справа; бросаем гранату вправо — должна отскочить и закрутиться назад.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wcs := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(20, 400)
	wcs.shape = wrect
	wall.add_child(wcs)
	add_child(wall)
	wall.global_position = Vector2(200, 400)

	var tdata = load(GRENADE_DATA)
	var scene: PackedScene = load(GRENADE_SCENE)
	var g: Node = scene.instantiate()
	add_child(g)
	(g as Node2D).global_position = Vector2(-200, 400)
	g.setup(tdata, 100, null)
	g.throw(Vector2.RIGHT)
	# Полёт (~0.47 с) + катание до стены (~0.4 с); ждём с запасом.
	await _wait(1.15)
	print("TEST_GRENADE_BOUNCE_DIR: ", g.linear_velocity.x < 0.0, " (vx=", g.linear_velocity.x, ")")
	print("TEST_GRENADE_BOUNCE_SPIN: ", g.angular_velocity < 0.0, " (av=", g.angular_velocity, ")")
	g.queue_free()
	wall.queue_free()
	await get_tree().process_frame

func _test_melee() -> void:
	dummy.set("hp", 100)
	dummy.global_position = Vector2(40, 0)
	# Ближний бой бьёт от тела-владельца, поэтому создаём CharacterBody2D-держателя.
	var shooter := CharacterBody2D.new()
	shooter.collision_layer = 0
	shooter.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	shooter.add_child(cs)
	add_child(shooter)
	var scene: PackedScene = load(MELEE_SCENE)
	var w: Node = scene.instantiate()
	shooter.add_child(w)
	w.equip(load(SWORD_DATA))
	await get_tree().physics_frame
	if w.pivot:
		w.pivot.look_at(dummy.global_position)
	w.Atack()
	await get_tree().process_frame
	print("TEST_MELEE_HIT: ", dummy.get("hp") < 100, " (hp=", dummy.get("hp"), ")")
	shooter.queue_free()
	await get_tree().process_frame

func _test_mine_triggers_on_placer() -> void:
	# Мина теперь опасна и для установившего: должна взорваться на dummy.
	var mdata = load(MINE_DATA)
	var scene: PackedScene = load(MINE_SCENE)
	var m: Node = scene.instantiate()
	add_child(m)
	(m as Node2D).global_position = dummy.global_position
	m.setup(mdata, 75, dummy)
	await _wait(3.3)                 # отсчёт взведения (arm_time = 3.0)
	print("TEST_MINE_TRIGGERS_ON_PLACER: ", not is_instance_valid(m))

func _test_mine() -> void:
	var mdata = load(MINE_DATA)
	var scene: PackedScene = load(MINE_SCENE)
	var m: Node = scene.instantiate()
	add_child(m)
	var mpos := Vector2(220, 0)
	(m as Node2D).global_position = mpos
	# placer = null, чтобы любое тело (dummy) подрывало мину.
	m.setup(mdata, 75, null)
	# Ждём взведения (arm_time = 3.0 с).
	await _wait(3.3)
	var before: int = dummy.get("hp")
	dummy.global_position = mpos
	await _wait(0.3)
	print("TEST_MINE_DETONATED: ", not is_instance_valid(m))
	print("TEST_MINE_DAMAGE: ", dummy.get("hp") < before, " (hp=", dummy.get("hp"), ")")

## Спавнит тестовую пулю с заданным ресурсом, позицией и поворотом.
func _spawn_bullet(data_path: String, pos: Vector2, rot: float) -> Node:
	var scene: PackedScene = load(BULLET_SCENE)
	var b: Node = scene.instantiate()
	add_child(b)
	b.setup(load(data_path), null)
	(b as Node2D).global_position = pos
	(b as Node2D).global_rotation = rot
	return b

## Создаёт dummy-сущность на заданном слое (скрипт dummy_entity.gd, hp = 100).
func _make_dummy(layer: int, pos: Vector2) -> Node:
	var d := CharacterBody2D.new()
	d.collision_layer = layer
	d.collision_mask = 0
	d.set_script(load(DUMMY_SCRIPT))
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	d.add_child(cs)
	add_child(d)
	d.global_position = pos
	return d

## Пуля гаснет у стены и НЕ входит в неё (нет просвечивания/туннелирования).
func _test_bullet_wall() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 200)
	cs.shape = rect
	wall.add_child(cs)
	add_child(wall)
	wall.global_position = Vector2(200, 700)
	var wall_left := 190.0

	var b := _spawn_bullet(BULLET_MG, Vector2(0, 700), 0.0)
	var max_x := -INF
	var guard := 0
	while is_instance_valid(b) and guard < 300:
		max_x = maxf(max_x, (b as Node2D).global_position.x)
		await get_tree().physics_frame
		guard += 1
	print("TEST_BULLET_WALL_FREED: ", not is_instance_valid(b))
	print("TEST_BULLET_WALL_NO_PENETRATION: ", max_x <= wall_left + 4.0, " max_x=", max_x)
	wall.queue_free()
	await get_tree().process_frame

## Пуля наносит урон врагу (слой enemy) и гаснет.
func _test_bullet_enemy() -> void:
	var enemy := _make_dummy(32, Vector2(150, 800))
	var b := _spawn_bullet(BULLET_MG, Vector2(0, 800), 0.0)
	await _wait(0.5)
	print("TEST_BULLET_ENEMY_DAMAGE: ", enemy.get("hp") < 100, " (hp=", enemy.get("hp"), ")")
	print("TEST_BULLET_ENEMY_FREED: ", not is_instance_valid(b))
	enemy.queue_free()
	await get_tree().process_frame

## Пуля пролетает сквозь союзника (слой NPC) без урона.
func _test_bullet_ally() -> void:
	var ally := _make_dummy(64, Vector2(150, 900))
	var b := _spawn_bullet(BULLET_MG, Vector2(0, 900), 0.0)
	await _wait(0.4)
	print("TEST_BULLET_ALLY_NO_DAMAGE: ", ally.get("hp") == 100, " (hp=", ally.get("hp"), ")")
	if is_instance_valid(b):
		b.queue_free()
	ally.queue_free()
	await get_tree().process_frame

## Компонент здоровья показывает всплывающее число урона.
func _test_damage_popup() -> void:
	var target := CharacterBody2D.new()
	target.collision_layer = 32
	add_child(target)
	target.global_position = Vector2(300, 900)
	var hc: Node = (load(HEALTH_SCENE) as PackedScene).instantiate()
	target.add_child(hc)
	await get_tree().physics_frame
	hc.init_health(100.0)
	hc.take_damage(30.0)
	await get_tree().process_frame
	var popup := get_tree().current_scene.find_child("DamagePopup", true, false)
	print("TEST_DAMAGE_POPUP_SPAWNED: ", popup != null)
	if popup:
		popup.queue_free()
	target.queue_free()
	await get_tree().process_frame
