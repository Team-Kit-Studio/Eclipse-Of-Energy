extends CharacterBody2D

## Общие маски физических слоёв (см. game_layers.gd).
const Layers = preload("res://project/scripts/core/game_layers.gd")

## Ресурс скина НПС (см. npc_skin.gd).
const NPCSkinRes = preload("res://project/scenes/characters/Entity/skins/npc_skin.gd")

## Отношение НПС к игроку.
enum Faction {
	ALLY,   # Союзник: атаки игрока пролетают мимо (неуязвим).
	ENEMY   # Враг: получает урон от атак игрока.
}

@onready var interact: AnimatedSprite2D = $Area2D/AnimatedSprite2D
@onready var Anim: AnimationPlayer = $AnimationPlayer
@onready var dialog_manager: Node2D = $DialogManager
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var quest_marker: Label = $Area2D/Quest_Marker   # метка (Label)
@onready var ray_cast_2d: RayCast2D = $RayCast2D
## Компонент здоровья (урон проходит только НПС-врагам).
@onready var health_component: HealthComponent = $HealthComponent


@export var npc_id: String
@export var npc_name: String
@export var dialog_resource: Dialog
## Фракция НПС: определяет слой коллизии и получаемый урон.
@export var faction: Faction = Faction.ALLY
## Максимальное здоровье (используется НПС-врагами).
@export var max_hp: int = 60

# --- Параметры НПС-врага (работают только при faction = ENEMY) ---
## Радиус обнаружения игрока (пикселей).
@export var aggro_range: float = 150.0
## Дистанция ближней атаки (пикселей).
@export var attack_range: float = 46.0
## Урон за удар.
@export var attack_damage: float = 12.0
## Перезарядка между ударами (секунд).
@export var attack_cooldown: float = 1.1
## Задержка от начала анимации до нанесения урона (секунд).
@export var attack_windup: float = 0.25

# --- Свой спрайт (для НПС с нестандартной внешностью, напр. Криптозавр) ---
## Если задан — заменяет стандартный спрайт НПС и включает простую анимацию.
@export var custom_sprite_frames: SpriteFrames
## Масштаб своего спрайта.
@export var sprite_scale: Vector2 = Vector2.ONE
## Смещение своего спрайта (подгонка относительно точки отсчёта).
@export var sprite_offset: Vector2 = Vector2.ZERO
## Скрыть тень персонажа при своём спрайте.
@export var hide_shadow: bool = false
## Простая анимация idle/walk/attack напрямую на AnimatedSprite2D (без AnimationPlayer).
@export var simple_animations: bool = false

var triger: bool = false
var current_state: String = "start"
var current_branch_index: int = 0
## Множитель скорости анимации (1.0 = нормальная). Управляется ActorFollower.
var animation_speed: float = 1.0

@export var quests: Array[Quest] = []
var quest_manager: Node = null
var force_hide_marker: bool = false

# Движение
var is_being_controlled_by_cutscene: bool = false
var input_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2i = Vector2i.LEFT
@export var speed: float = 100.0

# --- Состояние ИИ НПС-врага ---
## 0 = стойка, 1 = преследование, 2 = атака.
var _enemy_state: int = 0
## Таймер перезарядки атаки.
var _attack_timer: float = 0.0
## Таймер до нанесения урона в текущем ударе.
var _strike_timer: float = 0.0
## Ленивая ссылка на игрока.
var _player: Node2D = null
## Отбрасывание от взрывов.
var _kb_velocity: Vector2 = Vector2.ZERO
var _kb_time: float = 0.0

# Скины
## Набор скинов НПС (настраивается в инспекторе). Если пуст — используются
## встроенные скины "suit"/"no_suit" на основе AnimationPlayer.
@export var skins: Array[NPCSkinRes] = []
@export var default_skin: String = "suit"
var current_skin: String = default_skin

var animations: Dictionary = {
	"suit": {
		"idle_right": "State_Idle_FromSide",
		"idle_left":  "State_Idle_FromSide",
		"idle_up":    "State_Idle_Up",
		"idle_down":  "State_Idle_Down",
		"run_right":  "State_Run_FromSide",
		"run_left":   "State_Run_FromSide",
		"run_up":     "State_Run_Up",
		"run_down":   "State_Run_Down"
	},
	"no_suit": {
		"idle_right": "State_Idle_FromSide_No_Costume",
		"idle_left":  "State_Idle_FromSide_No_Costume",
		"idle_up":    "State_Idle_Up",
		"idle_down":  "State_Idle_Down_No_Costume",
		"run_right":  "State_Run_FromSide",
		"run_left":   "State_Run_FromSide",
		"run_up":     "State_Run_Up",
		"run_down":   "State_Run_Down_No_Costume"
	}
}

func _ready() -> void:
	current_skin = default_skin
	_setup_custom_sprite()
	_apply_faction()
	if faction != Faction.ENEMY:
		Global.npc = self
		if dialog_resource:
			dialog_resource.load_from_json("res://project/data/Resources/Dialog/Components_Scripts/dialog_data.json")
		dialog_manager.npc = self
	
	# Ждем пока игрок будет инициализирован
	await get_tree().process_frame
	
	# Квесты/диалоги — только для союзников-НПС.
	if faction != Faction.ENEMY and Global.player:
		quest_manager = Global.player.quest_manager
		if quest_manager:
			quest_manager.quest_updated.connect(_on_quests_changed)
			quest_manager.quest_list_updated.connect(_on_quests_changed)
		# Подписываемся на завершение диалога, чтобы обновить метку
		if not dialog_manager.is_connected("dialog_finished", _on_dialog_finished):
			dialog_manager.dialog_finished.connect(_on_dialog_finished)
	if sprite:
		if last_direction.x != 0:
			sprite.flip_h = last_direction.x > 0
	update_quest_marker()
	print("NPC Ready, Quest loaded: ", quests.size())

## Применяет фракцию: враг — слой «enemy» + группа + здоровье; союзник — слой «NPC».
func _apply_faction() -> void:
	match faction:
		Faction.ENEMY:
			collision_layer = Layers.ENEMY
			add_to_group("enemy")
			# Врага нельзя «заговорить»: отключаем зону взаимодействия игрока.
			var area := get_node_or_null("Area2D") as Area2D
			if area:
				area.monitoring = false
				area.monitorable = false
			if health_component:
				health_component.init_health(max_hp)
				if not health_component.on_unit_dead.is_connected(_on_died):
					health_component.on_unit_dead.connect(_on_died)
		Faction.ALLY:
			collision_layer = Layers.NPC
			if health_component:
				health_component.init_health(max_hp)

## Получение урона. Союзники неуязвимы — урон проходит только врагам.
func take_damage(amount: float) -> void:
	if faction != Faction.ENEMY or health_component == null:
		return
	health_component.take_damage(amount)

## Отбрасывание от взрывов (используется НПС-врагами).
func apply_knockback(direction: Vector2, force: float, duration: float) -> void:
	if direction == Vector2.ZERO or force <= 0.0:
		return
	_kb_velocity = direction.normalized() * force
	_kb_time = maxf(duration, 0.0)

## Смерть НПС-врага: убираем его со сцены.
func _on_died() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if is_being_controlled_by_cutscene:
		_check_door_with_ray()
		update_animation()
		move_and_slide()
		return
	# НПС-враг: свой ИИ (стойка/преследование/атака).
	if faction == Faction.ENEMY:
		_enemy_ai(delta)
		move_and_slide()
		return
	velocity = Vector2.ZERO
	update_animation()
	move_and_slide()

func _check_door_with_ray() -> void:
	if not ray_cast_2d or not is_being_controlled_by_cutscene:
		return
	var dir = last_direction
	if dir == Vector2i.ZERO:
		return
	ray_cast_2d.target_position = Vector2(dir * 80)
	ray_cast_2d.force_raycast_update()

	if ray_cast_2d.is_colliding():
		var collider = ray_cast_2d.get_collider()
		if collider and collider.is_in_group("door") and collider.has_method("force_open"):
			collider.force_open()

func get_clean_direction(raw_input: Vector2) -> Vector2i:
	if abs(raw_input.y) > abs(raw_input.x):
		return Vector2i(0, int(sign(raw_input.y)))
	return Vector2i(int(sign(raw_input.x)), 0) if raw_input.x != 0 else Vector2i.ZERO

## ИИ НПС-врага: стойка → преследование → ближняя атака. Требует прямой видимости.
func _enemy_ai(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	# Отбрасывание от взрывов перекрывает поведение.
	if _kb_time > 0.0:
		_kb_time -= delta
		velocity = _kb_velocity
		_kb_velocity = _kb_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		update_animation()
		return
	var player := _get_player()
	if player == null:
		_enemy_state = 0
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		update_animation()
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	# Преследуем/бьём только при прямой видимости (без стен и объектов между нами).
	var can_see := _has_line_of_sight(player)
	if dist <= attack_range and can_see:
		_enemy_attack(delta, player, to_player)
	elif dist <= aggro_range and can_see:
		_enemy_state = 1
		var dir := to_player.normalized()
		velocity = dir * speed
		_set_facing(dir)
		update_animation()
	else:
		_enemy_state = 0
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		update_animation()

## Удар в ближнем бою: разворот к игроку и циклическая атака
## (замах → урон → перезарядка → снова замах).
func _enemy_attack(delta: float, player: Node2D, to_player: Vector2) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	_set_facing(to_player)
	_enemy_state = 2
	# Новый замах, когда предыдущий удар завершён и перезарядка прошла.
	if _strike_timer <= 0.0 and _attack_timer <= 0.0:
		_strike_timer = attack_windup
		_restart_attack_animation()
	if _strike_timer > 0.0:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
			_attack_timer = attack_cooldown
	update_animation()

## Перезапускает анимацию атаки с первого кадра (для каждого удара).
func _restart_attack_animation() -> void:
	if _uses_sprite_frames():
		_play_frames_animation("attack", _direction_key(), true)
	elif Anim:
		var n := _resolve_player_animation("attack", _direction_key())
		if n != "":
			Anim.stop()
			Anim.play(n)

## Разворачивает НПС-врага к заданному направлению.
func _set_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	last_direction = get_clean_direction(dir)
	_apply_facing()

## Применяет разворот спрайта по last_direction (с учётом flip_facing скина).
func _apply_facing() -> void:
	if sprite == null or last_direction.x == 0:
		return
	var flip := last_direction.x > 0
	var skin := _active_skin()
	if skin and skin.flip_facing:
		flip = not flip
	sprite.flip_h = flip

## Лениво находит игрока (через автозагрузку Global).
func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = Global.player as Node2D
	return _player

## Прямая видимость игрока: луч не должен упираться в стены/объекты.
func _has_line_of_sight(player: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var params := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	params.collision_mask = Layers.WORLD | Layers.INTERACTIVE
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	return hit.is_empty()

func update_animation() -> void:
	var is_moving: bool = velocity.length() > 10.0
	if is_moving:
		var dir := Vector2.ZERO
		if abs(velocity.x) > abs(velocity.y):
			dir.x = sign(velocity.x)
		else:
			dir.y = sign(velocity.y)
		if dir != Vector2.ZERO:
			last_direction = get_clean_direction(dir)
	_apply_facing()

	# Состояние: стойка / ходьба / атака.
	var state := "idle"
	if faction == Faction.ENEMY and _enemy_state == 2:
		state = "attack"
	elif is_moving:
		state = "run"
	var dir_key := _direction_key()

	# Режим SpriteFrames — анимируем AnimatedSprite2D напрямую.
	if _uses_sprite_frames():
		_play_frames_animation(state, dir_key)
		return

	# Режим AnimationPlayer.
	if not Anim:
		return
	var anim_name := _resolve_player_animation(state, dir_key)
	if anim_name != "":
		Anim.speed_scale = animation_speed
		Anim.play(anim_name)

## Возвращает активный скин (по current_skin) или null.
func _active_skin() -> NPCSkinRes:
	for s in skins:
		if s and s.skin_id == current_skin:
			return s
	return null

## Есть ли скин/кадры, которые надо проигрывать напрямую на AnimatedSprite2D.
func _uses_sprite_frames() -> bool:
	if simple_animations:
		return true
	var skin := _active_skin()
	return skin != null and skin.sprite_frames != null

## Ключ направления по последнему направлению взгляда.
func _direction_key() -> String:
	match last_direction:
		Vector2i(1, 0): return "right"
		Vector2i(-1, 0): return "left"
		Vector2i(0, -1): return "up"
		Vector2i(0, 1): return "down"
	return "down"

## Имя анимации для AnimationPlayer: из активного скина либо из встроенной таблицы.
func _resolve_player_animation(state: String, dir_key: String) -> String:
	var skin := _active_skin()
	if skin:
		var n := skin.get_animation(state, dir_key)
		if n != &"":
			return String(n)
	# Встроенные скины (suit/no_suit) — только стойка/ходьба.
	var anim_block: Dictionary = animations.get(current_skin, animations["suit"])
	if state == "run":
		return String(anim_block.get("run_" + dir_key, anim_block["idle_" + dir_key]))
	return String(anim_block["idle_" + dir_key])

## Анимирует AnimatedSprite2D напрямую (режим SpriteFrames).
func _play_frames_animation(state: String, dir_key: String, restart: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: StringName = &""
	var skin := _active_skin()
	if skin and skin.sprite_frames:
		anim = skin.get_animation(state, dir_key)
	elif simple_animations:
		# legacy-режим: общие имена idle/walk/attack на custom_sprite_frames.
		match state:
			"attack": anim = &"attack"
			"run": anim = &"walk"
			_: anim = &"idle"
	if anim == &"" or not sprite.sprite_frames.has_animation(anim):
		return
	if restart or sprite.animation != anim:
		sprite.play(anim)
		if state == "attack":
			sprite.frame = 0

## Применяет активный скин к спрайту (кадры/масштаб/смещение) и опц. прячет тень.
func _setup_custom_sprite() -> void:
	if sprite:
		var skin := _active_skin()
		if skin:
			sprite.modulate = skin.modulate
		if skin and skin.sprite_frames:
			sprite.sprite_frames = skin.sprite_frames
			sprite.scale = skin.sprite_scale
			sprite.offset = skin.sprite_offset
			_play_frames_animation("idle", _direction_key())
		elif custom_sprite_frames:
			sprite.sprite_frames = custom_sprite_frames
			sprite.scale = sprite_scale
			sprite.offset = sprite_offset
			sprite.play("idle")
	if hide_shadow and has_node("shadow"):
		var sh := get_node("shadow") as Node2D
		if sh:
			sh.visible = false

func update_animation_based_on_state() -> void:
	update_animation()

func set_skin(skin_name: String) -> void:
	if _has_skin(skin_name):
		current_skin = skin_name
		_setup_custom_sprite()
		update_animation()
	else:
		push_error("NPC: неизвестный скин " + skin_name)

## Есть ли скин с таким id (пользовательский или встроенный).
func _has_skin(skin_name: String) -> bool:
	if animations.has(skin_name):
		return true
	for s in skins:
		if s and s.skin_id == skin_name:
			return true
	return false

func set_is_controlled(flag: bool) -> void:
	is_being_controlled_by_cutscene = flag

# Иконка чата (старая анимация) больше не используется, но оставлена для совместимости
func icon_up() -> void:
	var tween = get_tree().create_tween()
	interact.play("ChatIcon_Up")
	tween.tween_property(interact, "modulate", Color(10.453, 0.931, 0.0), 0.5)

func icon_down() -> void:
	var tween = get_tree().create_tween()
	interact.play("ChatIcon_Down")
	tween.tween_property(interact, "modulate", Color(1,1,1,0), 0.5)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if faction != Faction.ALLY:
		return
	if body.name == "Player":
		icon_up()
		triger = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if faction != Faction.ALLY:
		return
	if body.name == "Player":
		icon_down()
		triger = false

# ------------------ МЕТКА КВЕСТА / ДИАЛОГА ------------------
func update_quest_marker() -> void:
	if not quest_marker:
		return
	# У НПС-врагов метки квестов/диалога не показываем.
	if faction == Faction.ENEMY or force_hide_marker:
		quest_marker.visible = false
		return
		
	var has_quest = has_available_quest()
	var has_dialog = has_available_dialog()

	if has_quest and has_dialog:
		quest_marker.text = "!"
		quest_marker.add_theme_color_override("font_color", Color.GOLD)
		quest_marker.visible = true
	elif has_quest:
		quest_marker.text = "!"
		quest_marker.add_theme_color_override("font_color", Color.RED)
		quest_marker.visible = true
	elif has_dialog:
		quest_marker.text = "?"
		quest_marker.add_theme_color_override("font_color", Color.RED)
		quest_marker.visible = true
	else:
		quest_marker.visible = false

# Есть ли доступный квест (не начатый или in_progress с целью "talk_to" для этого NPC)
func has_available_quest() -> bool:
	for quest in quests:
		if quest.state == "not_started":
			return true
		elif quest.state == "in_progress":
			for obj in quest.objectives:
				if obj.target_id == npc_id and obj.target_type == "talk_to" and not obj.is_completed:
					return true
	return false

# Есть ли доступный диалог (не null в текущем состоянии)
func has_available_dialog() -> bool:
	return dialog_resource != null and get_current_dialog() != null

func _on_quests_changed(_param = null):
	update_quest_marker()

func _on_dialog_finished():
	update_quest_marker()

# ------------------ ДИАЛОГИ ------------------
func get_current_dialog():
	if dialog_resource == null:
		return null
	var npc_dialogs = dialog_resource.get_npc_dialog(npc_id) 
	if current_branch_index < npc_dialogs.size():
		for dialog in npc_dialogs[current_branch_index]["dialogs"]:
			if dialog["state"] == current_state:
				return dialog
	return null

func set_dialog_tree(branch_index):
	current_branch_index = branch_index
	current_state = "start"

func set_dialog_state(state):
	current_state = state

func start_dialog(type: String = "full", text: String = "", at_position: Vector2 = Vector2.ZERO, ignore_triger: bool = false, wait_for_input: bool = true, actor_path: String = "") -> void:
	if faction == Faction.ENEMY:
		return
	if not ignore_triger and not triger:
		return
	match type:
		"full":
			$Area2D/AnimatedSprite2D.visible = false
			var npc_dialogs = dialog_resource.get_npc_dialog(npc_id)
			if npc_dialogs.is_empty():
				return
			dialog_manager.show_npc_dialog(self)
		"filler":
			dialog_manager.show_npc_text(self, text, wait_for_input)
		"text_at_position":
			dialog_manager.show_text_at_position(text, at_position, wait_for_input)
		"over_actor":
			dialog_manager.show_text_over_actor(actor_path, text, wait_for_input)

func start_dialog_and_wait(type: String = "full", text: String = "", at_position: Vector2 = Vector2.ZERO, ignore_triger: bool = true, wait_for_input: bool = true, actor_path: String = "") -> Signal:
	start_dialog(type, text, at_position, ignore_triger, wait_for_input, actor_path)
	return dialog_manager.dialog_finished

func show_text_over_actor(actor_path: String, text: String, wait_for_input: bool = true) -> void:
	dialog_manager.show_text_over_actor(actor_path, text, wait_for_input)

func show_text_over_actor_and_wait(actor_path: String, text: String, wait_for_input: bool = true) -> Signal:
	return dialog_manager.show_text_over_actor_and_wait(actor_path, text, wait_for_input)

# ------------------ КВЕСТЫ ------------------
func offer_quest(quest_id: String) -> void:
	print("Попытка предложить квест: ", quest_id)
	for quest in quests:
		if quest.quest_id == quest_id and quest.state == "not_started":
			quest.state = "in_progress"
			quest_manager.add_quest(quest)
			update_quest_marker()
			return
	print("Квест не найден или уже начат")

func set_force_hide_marker(val: bool) -> void:
	force_hide_marker = val
	update_quest_marker()

func get_quest_dialog() -> Dictionary:
	var active_quests = quest_manager.get_active_quests()
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.target_id == npc_id and objective.target_type == "talk_to" and not objective.is_completed:
				if current_state == "start":
					return {"text": objective.objective_dialog, "options": {}}
	return {"text": "", "options": {}}

func get_dialog_origin() -> Vector2:
	return global_position + Vector2(0, -32)
