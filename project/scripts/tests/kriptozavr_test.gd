extends Node2D
## Автотест: Криптозавр как НПС-враг — преследование и атака только при прямой видимости.

const KRIPTOZAVR: PackedScene = preload("res://project/scenes/characters/Entity/kriptozavr.tscn")


## Тестовый «игрок»: считает полученный урон.
class DummyPlayer extends CharacterBody2D:
	var damage_taken: float = 0.0

	func take_damage(amount: float) -> void:
		damage_taken += amount


func _ready() -> void:
	_run()


func _run() -> void:
	var dummy := DummyPlayer.new()
	dummy.name = "Player"
	dummy.collision_layer = 2
	add_child(dummy)
	var cam := Camera2D.new()
	dummy.add_child(cam)
	Global.player = dummy

	var kripto: Node2D = KRIPTOZAVR.instantiate()
	add_child(kripto)

	# Фаза A: прямая видимость, дистанция 120 (в пределах aggro_range 150).
	kripto.global_position = Vector2.ZERO
	dummy.global_position = Vector2(120, 0)
	await _wait_physics(35)
	var chase_dx: float = kripto.global_position.x
	print("TEST_KRIP_CHASE=", chase_dx > 15.0, " (dx=", chase_dx, ")")
	var flip_right: bool = kripto.get_node("AnimatedSprite2D").flip_h
	print("TEST_KRIP_FACING_RIGHT=", flip_right == false, " (flip_h=", flip_right, ")")

	# Фаза B: стена (слой WORLD) перекрывает линию обзора — враг должен стоять.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 400)
	cs.shape = rect
	wall.add_child(cs)
	add_child(wall)
	wall.global_position = Vector2(60, 0)
	await _wait_physics(2)

	kripto.global_position = Vector2.ZERO
	kripto.velocity = Vector2.ZERO
	for i in 35:
		await get_tree().physics_frame
		if i % 5 == 0:
			print("DBG_B i=", i, " x=", kripto.global_position.x, " los=", kripto._has_line_of_sight(dummy))
	print("TEST_KRIP_WALL_IDLE=", absf(kripto.global_position.x) < 8.0, " (dx=", kripto.global_position.x, ")")

	# Фаза C: ближняя атака (дистанция 30, стены нет) — игрок должен получить урон.
	wall.queue_free()
	kripto.global_position = Vector2.ZERO
	kripto.velocity = Vector2.ZERO
	dummy.global_position = Vector2(30, 0)
	await _wait_physics(220)
	print("TEST_KRIP_ATTACK_REPEAT=", dummy.damage_taken > 12.0, " (dmg=", dummy.damage_taken, ")")

	print("TEST_KRIP_DONE")

	# Фаза D: визуальная проверка ходьбы вправо (кадр замораживается для скриншота).
	kripto.global_position = Vector2.ZERO
	kripto.velocity = Vector2.ZERO
	dummy.global_position = Vector2(120, 0)
	await _wait_physics(12)
	var spr: AnimatedSprite2D = kripto.get_node("AnimatedSprite2D")
	print("TEST_KRIP_WALK_FACE_RIGHT=", spr.flip_h == false, " anim=", spr.animation, " flip=", spr.flip_h)
	kripto.set_physics_process(false)


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame