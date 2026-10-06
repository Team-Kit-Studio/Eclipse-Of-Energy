# Укажите правильный путь к вашему Entity.gd
extends "res://project/scenes/characters/entity.gd" 
class_name Player

## Скрипт ресурса тактического снаряда (preload — без зависимости от реестра классов).
const TacticalDataScript = preload("res://project/scripts/Weapons/Tactical/tactical_data.gd")

# Ссылки, специфичные только для игрока.
# UI теперь собран в одной сцене (Arena), инстансированной как $UI.
# Реальный путь до панелей: $UI/UI/PlayerUI/...
@onready var player_inventory: CanvasItem = $UI/UI/PlayerUI/PlayerInventory
@onready var external_inventory: CanvasItem = $UI/UI/PlayerUI/ExternalInventory
@onready var hotbar: Hotbar = $UI/UI/PlayerUI/Hotbar
@onready var quest_manager: Node = $QuestManager
@onready var interact_area: Area2D = $interact # Убедитесь, что этот узел есть в Player_new
## Контроллер единой сцены оружия (передаёт ресурс активного слота в Weapon).
@onready var weapon_controller: Node2D = $WeaponController

@onready var quest_tracker: ColorRect = $UI/UI/PlayerUI/QuestTracker
@onready var title_label: Label = $UI/UI/PlayerUI/QuestTracker/Details/Title
@onready var objectives_container: VBoxContainer = $UI/UI/PlayerUI/QuestTracker/Details/Objectives

var current_target: Node = null
var selected_quest: Quest = null
var coin_amount: int = 0

var tooltip_instance: ItemTooltip = null
# --- Система Здоровья (Базовая) ---
var current_hp: int = 100

# --- Расходники ---
## Активный тактический предмет (граната/мина) из выбранного слота хотбара.
var _active_tactical: ItemData = null
## Кулдаун между броском/установкой (сек).
var _throw_cooldown: float = 0.0
## Твин растянутого лечения.
var _heal_tween: Tween = null
var _heal_total: int = 0
var _heal_applied: float = 0.0

## Использование расходника (вызывается из хотбара/инвентаря)
func use_consumable(item: ItemData) -> void:
	if not item or not item.is_usable:
		return

	match item.weapon_type:
		ItemData.WeaponType.CONSUMABLE_MEDICAL:
			_apply_healing(item)
		ItemData.WeaponType.CONSUMABLE_TACTICAL:
			# Тактические предметы (гранаты/мины) не «используются» из меню —
			# они бросаются/ставятся по ЛКМ, когда их слот активен (см. _try_use_tactical).
			_use_tactical_item(item)
		_:
			print("Этот предмет нельзя использовать напрямую.")

## Применение лечения с учётом режима (мгновенно или растянуто по времени).
func _apply_healing(item: ItemData) -> void:
	if item.heal_amount <= 0:
		return
	if item.is_heal_over_time() and item.heal_duration > 0.0:
		_start_over_time_heal(item.heal_amount, item.heal_duration)
		print("Использовано: %s. +%d HP за %.1f с." % [item.name, item.heal_amount, item.heal_duration])
	else:
		health_component.heal(item.heal_amount)
		_sync_hp()
		print("Использовано: %s. Восстановлено %d HP." % [item.name, item.heal_amount])

## Растянутое лечение: heal_amount равномерно восстанавливается за duration секунд.
## Урон это лечение НЕ прерывает.
func _start_over_time_heal(total: int, duration: float) -> void:
	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()
	_heal_total = total
	_heal_applied = 0.0
	_heal_tween = create_tween()
	_heal_tween.tween_method(_on_heal_tick, 0.0, 1.0, duration)

func _on_heal_tick(progress: float) -> void:
	var target: float = float(_heal_total) * progress
	var delta_hp: float = target - _heal_applied
	if delta_hp > 0.0:
		_heal_applied = target
		health_component.heal(delta_hp)
		_sync_hp()

## Синхронизирует локальный current_hp с HealthComponent (источник истины).
func _sync_hp() -> void:
	current_hp = int(round(health_component.current_health))

## Заглушка прямого использования тактического предмета (основной способ — бросок по ЛКМ).
func _use_tactical_item(item: ItemData) -> void:
	print("Тактический предмет '%s' бросается/ставится по ЛКМ (активный слот)." % item.name)

## Бросок гранаты или установка мины по ЛКМ (когда активный слот — тактический).
func _try_use_tactical() -> void:
	if _active_tactical == null or _throw_cooldown > 0.0:
		return
	if _is_inventory_open() or is_being_controlled_by_cutscene or not can_move:
		return
	var item: ItemData = _active_tactical
	if item.tactical == null:
		push_error("Тактический предмет '%s' без TacticalData" % item.name)
		return
	var scene: PackedScene = load(item.tactical.projectile_scene_path)
	if scene == null:
		push_error("Не удалось загрузить сцену снаряда: " + item.tactical.projectile_scene_path)
		return

	# Направление на курсор.
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var dir: Vector2 = to_mouse.normalized() if to_mouse.length() > 0.001 else Vector2.RIGHT

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	var projectile: Node = scene.instantiate()
	root.add_child(projectile)
	if projectile is Node2D:
		var spawn_pos: Vector2 = global_position
		if item.tactical.tactical_type == TacticalDataScript.TacticalType.MINE:
			spawn_pos += dir * item.tactical.place_offset
		(projectile as Node2D).global_position = spawn_pos
	if projectile.has_method("setup"):
		projectile.setup(item.tactical, item.damage, self)
	if item.tactical.tactical_type == TacticalDataScript.TacticalType.GRENADE and projectile.has_method("throw"):
		projectile.throw(dir)

	_throw_cooldown = 0.5
	print("Использован тактический предмет: %s (в сторону %s)" % [item.name, dir])
	_consume_active_tactical()

## Расходует одну единицу тактического предмета из активного слота хотбара.
func _consume_active_tactical() -> void:
	if hotbar and hotbar.has_method("consume_active_item"):
		hotbar.consume_active_item()
	if hotbar == null or hotbar.get_slot_item(hotbar.active_slot_index) == null:
		_active_tactical = null

## Обработчик использования расходника из хотбара. Лечим только медицину:
## тактические предметы расходуются броском/установкой, а не через это событие.
func _on_hotbar_item_used(item: ItemData) -> void:
	if item and item.is_medical():
		use_consumable(item)

func _ready() -> void:
	super._ready() # Вызываем _ready из Entity.gd
	Global.player = self
	quest_tracker.visible = false
	
	# Инициализация тултипа
	var tooltip_scene = preload("res://project/scenes/ui/inventory/components/item_tooltip.tscn")
	tooltip_instance = tooltip_scene.instantiate()
	add_child(tooltip_instance)
	
	if quest_manager:
		quest_manager.quest_updated.connect(_on_quest_updated)
		quest_manager.objective_updated.connect(_on_objective_updated)
	
	# Оружие/курсор следуют за активным слотом хотбара
	if hotbar:
		hotbar.active_slot_changed.connect(_on_hotbar_slot_changed)
		hotbar.slot_changed.connect(_on_hotbar_slot_data_changed)
		hotbar.item_used.connect(_on_hotbar_item_used)
	_update_weapon_and_cursor(hotbar.active_slot_index if hotbar else 0)
	
	health_component.init_health(data.max_hp)

## Смена активного слота хотбара (клавиши 1-4, колесо мыши, клик)
func _on_hotbar_slot_changed(index: int) -> void:
	_update_weapon_and_cursor(index)

## Содержимое слота изменилось (снят / использован / экипирован предмет).
## Если это активный слот — пересчитываем оружие «в руках», иначе снятый из хотбара
## предмет оставался бы в руках.
func _on_hotbar_slot_data_changed(slot_index: int, _item: ItemData) -> void:
	if hotbar and slot_index == hotbar.active_slot_index:
		_update_weapon_and_cursor(hotbar.active_slot_index)

## Показывает/прячет оружие по активному слоту и обновляет режим курсора.
func _update_weapon_and_cursor(index: int) -> void:
	var item: ItemData = hotbar.get_slot_item(index) if hotbar else null
	var is_weapon: bool = item != null and item.is_weapon()
	# Запоминаем тактический предмет (граната/мина) — он бросается по ЛКМ.
	_active_tactical = item if (item != null and item.is_tactical()) else null
	if weapon_controller and weapon_controller.has_method("set_weapon"):
		weapon_controller.set_weapon(item if is_weapon else null)
	_update_cursor_mode(is_weapon)

## Режим курсора: при открытом инвентаре — обычный указатель,
## иначе — перекрестие оружия, если активный слот содержит оружие.
func _update_cursor_mode(is_weapon: bool) -> void:
	Cursor.set_weapon_mode(is_weapon and not _is_inventory_open())

## Пересчитывает режим курсора по текущему активному слоту
## (вызывается после открытия/закрытия инвентаря).
func _refresh_cursor() -> void:
	var index: int = hotbar.active_slot_index if hotbar else 0
	var item: ItemData = hotbar.get_slot_item(index) if hotbar else null
	_update_cursor_mode(item != null and item.is_weapon())

# Переопределяем виртуальный метод ввода из Entity.gd
func _handle_input() -> void:
	if can_move and not is_being_controlled_by_cutscene:
		input_direction = Input.get_vector("left", "right", "up", "down")

func _physics_process(delta: float) -> void:
	if _throw_cooldown > 0.0:
		_throw_cooldown -= delta
	# Бросок гранаты / установка мины по ЛКМ. Читаем действие поллингом (как оружие),
	# чтобы клик срабатывал даже если UI перехватил событие через _unhandled_input.
	if Input.is_action_just_pressed("Atack"):
		_try_use_tactical()
	# Когда игрок стоит на месте и прицеливание корпусом включено, он разворачивается к курсору.
	if _should_face_aim():
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 0.0 and velocity.length() <= 10.0:
			last_direction = _get_clean_direction(to_mouse)
	super._physics_process(delta) # Выполняем базовую физику и анимацию
	if not is_being_controlled_by_cutscene and can_move:
		update_nearest_target()
	_update_walk_direction()

## Можно ли сейчас прицеливаться корпусом к курсору.
## Отключается, когда игрок под управлением катсцены (is_being_controlled_by_cutscene = true)
## или когда движение заблокировано (can_move = false).
func _should_face_aim() -> bool:
	return can_move and not is_being_controlled_by_cutscene

## Тело игрока смотрит в сторону прицела (курсора), даже когда движется в другую
## сторону — чтобы анимация ходьбы соответствовала направлению взгляда/оружия.
func _get_move_facing() -> Vector2:
	if _should_face_aim():
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 0.0:
			return to_mouse
	return super._get_move_facing()

## Когда персонаж идёт в противоположную от прицела сторону, проигрываем анимацию
## ходьбы задом наперёд (отступление назад), чтобы ноги «шагали» в сторону движения.
func _update_walk_direction() -> void:
	var is_moving: bool = velocity.length() > 10.0
	var reversed: bool = false
	if is_moving and _should_face_aim():
		var move_dir: Vector2i = _get_clean_direction(input_direction if input_direction != Vector2.ZERO else velocity.normalized())
		reversed = (move_dir == -last_direction)
	anim_player.speed_scale = -1.0 if reversed else 1.0
	shadow_sprite.speed_scale = -1.0 if reversed else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete"):
		get_tree().quit()
	if event.is_action_pressed("Inventory"):
		_toggle_inventory()
	# Стрельба обрабатывается в самой сцене оружия (weapon_range._process):
	# там есть cooldown и проверка, что оружие экипировано (data != null).
	if event.is_action_pressed("Interaction"):
		_handle_interaction()
	if event.is_action_pressed("ui_quest_menu"):
		if quest_manager:
			quest_manager.show_quest_log()
	# Переключение Бег/Шаг (например, на правый Shift или Ctrl)
	if event.is_action_pressed("Toggle_RunWalk"):
		# При открытом инвентаре НЕ переключаем бег/ходьбу:
		# иначе Shift+ЛКМ при экипировке оружия менял бы режим движения.
		if not _is_inventory_open():
			is_running = !is_running
	if event.is_action_pressed("ui_accept"):
		health_component.take_damage(30)

func _toggle_inventory() -> void:
	if _is_inventory_open():
		close_all_inventories()
	else:
		if InventoryManage and InventoryManage.has_held():
			var source_info = InventoryManage.get_source()
			if source_info.inventory == external_inventory:
				if external_inventory and external_inventory.has_method("open_container"):
					external_inventory.open_container(source_info.inventory.bound_container)
				return
		if player_inventory:
			player_inventory.visible = true
	_refresh_cursor()

func _handle_interaction() -> void:
	if current_target == null: return
	
	if current_target.is_in_group("item"):
		var item = current_target as DroppedItem
		if item and item.data:
			# Сначала пытаемся добавить в хотбар (только предметы 1x1)
			var added_to_hotbar = false
			if hotbar and hotbar.has_method("try_add_item"):
				if item.data.get_size() == Vector2i(1, 1):
					added_to_hotbar = hotbar.try_add_item(item.data)
			
			# Если не удалось добавить в хотбар, добавляем в инвентарь
			if not added_to_hotbar:
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
			
	elif current_target.is_in_group("interactable"):
		if external_inventory and external_inventory.visible and external_inventory.call("is_bound_to", current_target):
			close_all_inventories()
			return
		if InventoryManage and InventoryManage.has_held():
			var source_info = InventoryManage.get_source()
			if source_info.inventory != external_inventory:
				close_all_inventories()
		if player_inventory and not player_inventory.visible:
			player_inventory.visible = true
		if external_inventory and external_inventory.has_method("open_container"):
			external_inventory.call("open_container", current_target)
			
	elif current_target.is_in_group("NPC"):
		can_move = false
		if current_target.has_method("start_dialog"):
			current_target.call("start_dialog")
			check_quest_objectives(current_target.npc_id, "talk_to")

func update_nearest_target() -> void:
	if not interact_area: return
	var areas = interact_area.get_overlapping_areas()
	var best_target: Node = null
	var best_dist = INF
	
	for area in areas:
		var parent = area.get_parent()
		var target_node = area if area.is_in_group("item") or area.is_in_group("interactable") or area.is_in_group("NPC") else parent
		
		if target_node and (target_node.is_in_group("item") or target_node.is_in_group("interactable") or target_node.is_in_group("NPC")):
			var dist = global_position.distance_to(target_node.global_position)
			if dist < best_dist and dist <= 50.0:
				best_dist = dist
				best_target = target_node

	if best_target != current_target:
		if current_target and current_target.has_method("set_highlight"):
			current_target.call("set_highlight", false)
		current_target = best_target
		if current_target and current_target.has_method("set_highlight"):
			current_target.call("set_highlight", true)

func close_all_inventories() -> void:
	if InventoryManage and InventoryManage.has_held():
		InventoryManage.return_item()
	if external_inventory and external_inventory.visible and external_inventory.has_method("close_container"):
		external_inventory.call("close_container")
	if player_inventory:
		player_inventory.visible = false
	_refresh_cursor()

func _is_inventory_open() -> bool:
	return (player_inventory != null and player_inventory.visible) or (external_inventory != null and external_inventory.visible)

## Публичное состояние инвентаря: пока открыт — оружие не должно прицеливаться
## и стрелять (используется weapon_controller и weapon_range).
func is_inventory_open() -> bool:
	return _is_inventory_open()

# --- Логика Квестов ---
func is_item_needed(item_id: String) -> bool:
	if selected_quest:
		for objective in selected_quest.objectives:
			if objective.target_id == item_id and objective.target_type == "collection" and not objective.is_completed:
				return true
	return false

func check_quest_objectives(target_id: String, target_type: String, quantity: int = 1):
	if not selected_quest: return
	var updated = false
	for objective in selected_quest.objectives:
		if objective.target_id == target_id and objective.target_type == target_type and not objective.is_completed:
			selected_quest.complete_objective(objective.id, quantity)
			updated = true
			break
	
	if updated:
		if selected_quest.is_completed():
			handle_quest_completion(selected_quest)
		update_quest_tracker(selected_quest)

func handle_quest_completion(quest: Quest):
	for reward in quest.rewards:
		if reward.reward_type == Rewards.RewardType.COINS:
			coin_amount += reward.reward_amount
	update_quest_tracker(quest)
	if quest_manager:
		quest_manager.update_quest(quest.quest_id, "completed")

func update_quest_tracker(quest: Quest):
	if quest:
		quest_tracker.visible = true
		title_label.text = quest.quest_name
		for child in objectives_container.get_children():
			objectives_container.remove_child(child)
		for objective in quest.objectives:
			var label = Label.new()
			label.text = objective.description
			label.add_theme_color_override("font_color", Color(0, 1, 0) if objective.is_completed else Color(1, 0, 0))
			objectives_container.add_child(label)
	else:
		quest_tracker.visible = false

func _on_quest_updated(quest_id: String):
	var quest = quest_manager.get_quest(quest_id)
	if quest and quest == selected_quest:
		update_quest_tracker(quest)

func _on_objective_updated(quest_id: String, _objective_id: String):
	if selected_quest and selected_quest.quest_id == quest_id:
		update_quest_tracker(selected_quest)

# --- Сохранение/Загрузка ---
func get_save_data() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"direction": {"x": last_direction.x, "y": last_direction.y},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"skin": current_skin,
		"coins": coin_amount
	}

func load_data(save_data: Dictionary) -> void:
	if save_data.has("position"):
		global_position = Vector2(save_data.position.x, save_data.position.y)
	if save_data.has("direction"):
		last_direction = Vector2i(save_data.direction.x, save_data.direction.y)
	if save_data.has("velocity"):
		velocity = Vector2(save_data.velocity.x, save_data.velocity.y)
	if save_data.has("skin"):
		set_skin(save_data.skin)
	if save_data.has("coins"):
		coin_amount = save_data.coins
	
	_update_animation() # Вызываем метод из Entity.gd

## Показать тултип предмета рядом с контекстным меню
func show_item_tooltip(item: ItemData, anchor_position: Vector2, anchor_size: Vector2 = Vector2.ZERO) -> void:
	if tooltip_instance:
		tooltip_instance.show_tooltip(item, anchor_position, anchor_size)

## Скрыть тултип
func hide_item_tooltip() -> void:
	if tooltip_instance:
		tooltip_instance.hide_tooltip()
		
