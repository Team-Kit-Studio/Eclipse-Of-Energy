extends CharacterBody2D

## Состояния игрока
enum state { MOVE, DAMAGE, ATTACK, DEATH }

## Скорость передвижения (пикселей/сек)
@export var speed: float = 100.0
## Ускорение при движении
@export var acceleration: float = 800.0
## Торможение (трение) при отсутствии ввода
@export var friction: float = 1000.0
## Стандартный скин (набор анимаций)
@export var default_skin: String = "suit"


# Ссылки на ноды
@onready var audio_sfx1: AudioStreamPlayer2D = $AudioSFX
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer
@onready var ShadowSprite: AnimatedSprite2D = %AnimatedSprite2D2
@onready var interact: Area2D = $interact

# Инвентари
@onready var player_inventory: CanvasItem = get_tree().root.find_child("PlayerInventory", true, false) as CanvasItem
@onready var external_inventory: CanvasItem = get_tree().root.find_child("ExternalInventory", true, false) as CanvasItem
@onready var inventory_manager = InventoryManage

# HUD
@onready var icon: TextureRect = $HUD/QuestTreker/Icon
@onready var amount: Label = $HUD/QuestTreker/Amount
@onready var quest_tracker: ColorRect = $HUD/QuestTracker
@onready var title: Label = $HUD/QuestTracker/Details/Title
@onready var objectives: VBoxContainer = $HUD/QuestTracker/Details/Objectives
@onready var quest_manager = $QuestManager

## Может ли игрок двигаться
var can_move: bool = true
## Текущий отслеживаемый квест
var selected_quest: Quest = null
## Количество монет
var coin_amount: int = 0

# Анимация
var input_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2i = Vector2i.ZERO
var was_moving: bool = false
var current_target: Node = null
var current_state: state = state.MOVE

## Управляется ли игрок катсценой
var is_being_controlled_by_cutscene: bool = false

# Словарь анимаций для разных скинов
var animations: Dictionary = {
	"suit": {
		"idle_right": "State_Idle_FromSide",
		"idle_left": "State_Idle_FromSide",
		"idle_up": "State_Idle_Up",
		"idle_down": "State_Idle_Down",
		"run_right": "State_Run_FromSide",
		"run_left": "State_Run_FromSide",
		"run_up": "State_Run_Up",
		"run_down": "State_Run_Down"
	},
	"no_suit": {
		"idle_right": "State_Idle_FromSide_No_Costume",
		"idle_left": "State_Idle_FromSide_No_Costume",
		"idle_up": "State_Idle_Up",
		"idle_down": "State_Idle_Down_No_Costume",
		"run_right": "State_Run_FromSide",
		"run_left": "State_Run_FromSide",
		"run_up": "State_Run_Up",
		"run_down": "State_Run_Down_No_Costume"
	}
}
## Высота тона шагов (1.0 = нормальная). Управляется катсценой.
var footstep_pitch: float = 1.0
var current_skin: String = default_skin
## Множитель скорости анимации (1.0 = нормальная). Управляется катсценой.
var animation_speed: float = 1.0

func _ready() -> void:
	Global.player = self
	
	var step_sound = preload("res://project/assets/sounds/MSE/zhelezo.mp3")
	audio_sfx1.stream = step_sound
	quest_tracker.visible = false
	update_coins()
	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objective_updated)
	if audio_sfx1.stream is AudioStreamMP3:
		audio_sfx1.stream.loop = true
	elif audio_sfx1.stream is AudioStreamOggVorbis:
		audio_sfx1.stream.loop = true

func _physics_process(delta: float) -> void:
	# Если игроком управляет кат-сцена
	if is_being_controlled_by_cutscene:
		move_and_slide()
		update_animation_based_on_state()
		_check_movement_for_footsteps()
		return

	# Если инвентарь открыт или игрок заблокирован — стоим
	if is_inventory_open() or !can_move:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_stop_footsteps()
		input_direction = Vector2.ZERO
		update_animation_based_on_state()
		move_and_slide()
		return

	match current_state:
		state.MOVE:
			Move_State(delta)
		state.DAMAGE:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			_stop_footsteps()
		state.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			_stop_footsteps()
		state.DEATH:
			velocity = Vector2.ZERO
			_stop_footsteps()

	move_and_slide()
	update_nearest_target()
	_check_movement_for_footsteps()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_text_delete"):
		get_tree().quit()
	if event.is_action_pressed("Inventory"):
		if is_inventory_open():
			close_all_inventories()
		else:
			if player_inventory:
				if inventory_manager and inventory_manager.has_held():
					var source_info = inventory_manager.get_source()
					if source_info.inventory == external_inventory:
						if external_inventory and external_inventory.has_method("open_container"):
							external_inventory.open_container(source_info.inventory.bound_container)
						return
				player_inventory.visible = true
	if event.is_action_pressed("Interaction"):
		handle_f_action()
	if event.is_action_pressed("ui_quest_menu"):
		quest_manager.show_quest_log()



## Обрабатывает движение в состоянии MOVE
func Move_State(delta: float) -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")
	if input_direction != Vector2.ZERO:
		last_direction = get_clean_direction(input_direction)
	
	var current_speed: float = speed
		
	var target_velocity = input_direction * current_speed
	var accel_value = acceleration if input_direction != Vector2.ZERO else friction
	velocity = velocity.move_toward(target_velocity, accel_value * delta)
	update_animation_based_on_state()


## Обновляет анимацию в зависимости от направления и скорости
func update_animation_based_on_state() -> void:
	var is_moving = input_direction != Vector2.ZERO or velocity.length() > 10.0
	var direction = last_direction if is_moving else last_direction
	if direction == Vector2i.ZERO:
		direction = Vector2i.RIGHT
	var anim_block = animations[current_skin]
	var anim_name = ""

	if is_moving and velocity.length() > 10.0:
		match direction:
			Vector2i.RIGHT:
				anim_name = anim_block["run_right"]
			Vector2i.LEFT:
				anim_name = anim_block["run_left"]
			Vector2i.UP:
				anim_name = anim_block["run_up"]
			Vector2i.DOWN:
				anim_name = anim_block["run_down"]
	else:
		match direction:
			Vector2i.RIGHT, Vector2i.LEFT:
				anim_name = anim_block["idle_right"]
			Vector2i.UP:
				anim_name = anim_block["idle_up"]
			Vector2i.DOWN:
				anim_name = anim_block["idle_down"]
	AnimPlayer.speed_scale = animation_speed
	ShadowSprite.play(anim_name)
	AnimPlayer.play(anim_name)
	flip_anim()

## Преобразует сырой вектор ввода в одно из четырёх направлений
func get_clean_direction(raw_input: Vector2) -> Vector2i:
	if abs(raw_input.y) > abs(raw_input.x):
		return Vector2i(0, int(sign(raw_input.y)))
	return Vector2i(int(sign(raw_input.x)), 0) if raw_input.x != 0 else Vector2i.ZERO

## Зеркалирует спрайт по горизонтали
func flip_anim() -> void:
	if last_direction.x != 0:
		anim.flip_h = last_direction.x > 0
		ShadowSprite.flip_h = last_direction.x > 0

## Меняет текущий скин
func set_skin(skin_type: String) -> void:
	if animations.has(skin_type):
		current_skin = skin_type
		update_animation_based_on_state()
	else:
		push_error("Unknown skin: ", skin_type)

## Проверяет, нужно ли проигрывать звук шагов
func _check_movement_for_footsteps() -> void:
	var is_moving = velocity.length() > 10.0
	if is_moving:
		if not audio_sfx1.playing:
			audio_sfx1.pitch_scale = footstep_pitch
			audio_sfx1.play()
		was_moving = true
	elif was_moving:
		_stop_footsteps()

## Останавливает звук шагов
func _stop_footsteps() -> void:
	if audio_sfx1.playing:
		audio_sfx1.stop()
	was_moving = false

## Открыт ли любой инвентарь (личный или внешний)
func is_inventory_open() -> bool:
	var p_open = (player_inventory != null and player_inventory.visible)
	var e_open = (external_inventory != null and external_inventory.visible)
	return p_open or e_open

## Закрывает все открытые инвентари
func close_all_inventories() -> void:
	if inventory_manager and inventory_manager.has_held():
		var source_info = inventory_manager.get_source()
		if source_info.inventory == player_inventory:
			inventory_manager.return_item()
		elif external_inventory and external_inventory.visible:
			if external_inventory.has_method("close_container"):
				external_inventory.close_container()
	if external_inventory and external_inventory.visible:
		if external_inventory.has_method("close_container"):
			external_inventory.call("close_container")
	if player_inventory:
		player_inventory.visible = false

## Находит ближайший интерактивный объект среди пересекающихся областей
func update_nearest_target() -> void:
	if interact == null:
		return
	var areas = interact.get_overlapping_areas()
	var best_item: Node = null
	var best_item_dist = INF
	var best_container: Node = null
	var best_container_dist = INF
	var best_npc: Node = null
	var best_npc_dist = INF

	for area in areas:
		var distance = global_position.distance_to(area.global_position)
		if area.is_in_group("item"):
			if distance < best_item_dist:
				best_item_dist = distance
				best_item = area
			continue
		if area.is_in_group("interactable"):
			if distance < best_container_dist:
				best_container_dist = distance
				best_container = area
			continue
		if area.is_in_group("NPC"):
			if distance < best_npc_dist:
				best_npc_dist = distance
				best_npc = area
			continue
		var parent = area.get_parent()
		if parent:
			if parent.is_in_group("item"):
				if distance < best_item_dist:
					best_item_dist = distance
					best_item = parent
				continue
			if parent.is_in_group("interactable"):
				if distance < best_container_dist:
					best_container_dist = distance
					best_container = parent
				continue
			if parent.is_in_group("NPC"):
				if distance < best_npc_dist:
					best_npc_dist = distance
					best_npc = parent

	var new_target: Node = null
	if best_item != null and best_item_dist <= 50.0:
		new_target = best_item
	elif best_container != null and best_container_dist <= 50.0:
		new_target = best_container
	elif best_npc != null and best_npc_dist <= 50.0:
		new_target = best_npc

	if new_target != current_target:
		if current_target and current_target.has_method("set_highlight"):
			current_target.call("set_highlight", false)
		current_target = new_target
		if current_target and current_target.has_method("set_highlight"):
			current_target.call("set_highlight", true)

## Обрабатывает нажатие клавиши взаимодействия (F)
func handle_f_action() -> void:
	if current_target == null:
		return

	# Подбор предмета
	if current_target.is_in_group("item"):
		var item = current_target as DroppedItem
		if item.data == null:
			return
		if item.has_method("set_highlight"):
			item.set_highlight(false)

		if player_inventory and player_inventory.has_method("add_item"):
			player_inventory.add_item(item.data)
		else:
			push_error("Не удалось добавить предмет в инвентарь")
			return

		if is_item_needed(item.data.item_id):
			check_quest_objectives(item.data.item_id, "collection", item.data.amount)

		item.queue_free()
		current_target = null
		return

	# Взаимодействие с контейнерами
	elif current_target.is_in_group("interactable"):
		if external_inventory and external_inventory.visible and external_inventory.has_method("is_bound_to") and external_inventory.call("is_bound_to", current_target):
			close_all_inventories()
			return
		if inventory_manager and inventory_manager.has_held():
			var source_info = inventory_manager.get_source()
			if source_info.inventory != external_inventory:
				close_all_inventories()
		if player_inventory and not player_inventory.visible:
			player_inventory.visible = true
		if external_inventory and external_inventory.has_method("open_container"):
			external_inventory.call("open_container", current_target)
		return

	# Разговор с NPC
	elif current_target.is_in_group("NPC"):
		can_move = false
		if current_target.has_method("start_dialog"):
			current_target.call("start_dialog")
			check_quest_objectives(current_target.npc_id, "talk_to")
		return
	

## Сохраняет данные игрока
func data() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"direction": {"x": last_direction.x, "y": last_direction.y},
		"velocity": {"x": velocity.x, "y": velocity.y}
	}

## Восстанавливает данные игрока
func load_data(save_data: Dictionary) -> void:
	if save_data.has("position"):
		global_position.x = save_data.position.x
		global_position.y = save_data.position.y
	if save_data.has("direction"):
		last_direction.x = save_data.direction.x
		last_direction.y = save_data.direction.y
	if save_data.has("velocity"):
		velocity.x = save_data.velocity.x
		velocity.y = save_data.velocity.y
	update_animation_based_on_state()

## Проверяет, нужен ли предмет для активного квеста
func is_item_needed(item_id: String) -> bool:
	if selected_quest != null:
		for objective in selected_quest.objectives:
			if objective.target_id == item_id and objective.target_type == "collection" and not objective.is_completed:
				return true
	return false

## Обновляет прогресс целей квеста
func check_quest_objectives(target_id: String, target_type: String, quantity: int = 1):
	if selected_quest == null:
		return
	var objective_updated = false
	for objective in selected_quest.objectives:
		if objective.target_id == target_id and objective.target_type == target_type and not objective.is_completed:
			selected_quest.complete_objective(objective.id, quantity)
			objective_updated = true
			break
	if objective_updated:
		if selected_quest.is_completed():
			handle_quest_completion(selected_quest)
		update_quest_tracker(selected_quest)

## Выдаёт награды за выполненный квест
func handle_quest_completion(quest: Quest):
	for reward in quest.rewards:
		if reward.reward_type == Rewards.RewardType.COINS:
			coin_amount += reward.reward_amount
			update_coins()
		# Здесь можно добавить другие типы наград
	update_quest_tracker(quest)
	quest_manager.update_quest(quest.quest_id, "completed")

## Обновляет отображение монет в HUD
func update_coins() -> void:
	amount.text = str(coin_amount)

## Обновляет трекер квестов на экране
func update_quest_tracker(quest: Quest):
	if quest:
		quest_tracker.visible = true
		title.text = quest.quest_name
		for child in objectives.get_children():
			objectives.remove_child(child)
		for objective in quest.objectives:
			var label = Label.new()
			label.text = objective.description
			label.add_theme_color_override("font_color", Color(0, 1, 0) if objective.is_completed else Color(1, 0, 0))
			objectives.add_child(label)
	else:
		quest_tracker.visible = false

func _on_quest_updated(quest_id: String):
	var quest = quest_manager.get_quest(quest_id)
	if quest and quest == selected_quest:
		update_quest_tracker(quest)
	# selected_quest остаётся прежним, если квест ещё активен

func _on_objective_updated(quest_id: String, objective_id: String):
	if selected_quest and selected_quest.quest_id == quest_id:
		update_quest_tracker(selected_quest)
