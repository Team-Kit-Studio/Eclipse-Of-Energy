extends Node2D
## Менеджер диалогов НПС: показывает текстовые облачка и панель выбора, управляет
## камерой и кинематографическими полосами во время диалога.

## Сигнал: диалог завершён.
signal dialog_finished

## Сцены облачка текста и панели выбора; кинематографические полосы.
@onready var text_box_scene = preload("res://project/scenes/ui/Systems/Dialog/Text_Box/text_box.tscn")
@onready var choice_panel_scene = preload("res://project/scenes/ui/Systems/Dialog/ChoicePanel.tscn")
@onready var cinematic_bars: Control = $CinemticBars

## Текущий собеседник (НПС).
var npc: Node = null
## Текущее облачко текста.
var current_text_box: Node = null
## Текущая панель выбора.
var current_choice_panel: Node = null
## Ожидается ли выбор варианта.
var waiting_for_choice: bool = false

## Камера игрока и её исходные параметры (для возврата после диалога).
var player_camera: Camera2D = null
var original_camera_pos: Vector2 = Vector2.ZERO
var original_camera_zoom: Vector2 = Vector2.ONE
var original_smoothing_enabled: bool = false
var original_smoothing_speed: float = 5.0

## Запоминает камеру игрока и её исходные настройки.
func _ready() -> void:
	await get_tree().process_frame
	if Global.player:
		player_camera = Global.player.get_node("Camera2D")
		if player_camera:
			original_camera_zoom = player_camera.zoom
			original_smoothing_enabled = player_camera.position_smoothing_enabled
			original_smoothing_speed = player_camera.position_smoothing_speed

## Плавно наводит камеру игрока на НПС и приближает её.
func focus_on_npc(npc_pos: Vector2) -> void:
	if not player_camera:
		return
	original_camera_pos = player_camera.global_position
	player_camera.position_smoothing_enabled = false
	var target_zoom = Vector2(2.3, 2.3)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_camera, "global_position", npc_pos, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_camera, "zoom", target_zoom, 0.4).set_ease(Tween.EASE_OUT)
	await tween.finished

## Возвращает камеру в исходное положение и зум.
func restore_camera() -> void:
	if not player_camera:
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_camera, "global_position", original_camera_pos, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(player_camera, "zoom", original_camera_zoom, 0.4).set_ease(Tween.EASE_IN)
	await tween.finished
	player_camera.position_smoothing_enabled = original_smoothing_enabled
	player_camera.position_smoothing_speed = original_smoothing_speed

## Показывает полноценный диалог с НПС: наводит камеру, показывает полосы и текст с опциями.
func show_npc_dialog(_npc: Node) -> void:
	Global.player.can_move = false
	await focus_on_npc(_npc.global_position)
	await cinematic_bars.show_bars()
	npc = _npc
	var current_dialog = npc.get_current_dialog()
	if current_dialog == null:
		hide_dialog()
		return
	var text = current_dialog["text"]
	var options = current_dialog.get("options", {})
	_show_text_bubble(text, options)

# Филлерный текст над сущностью (ждёт пробел)
# В конец скрипта NPC, перед последней закрывающей скобкой

## Показывает текст над указанной сущностью (актёром).
func show_text_over_actor(actor_path: String, text: String, wait_for_input: bool = true) -> void:
	var actor = get_node_or_null(actor_path)
	if not actor:
		push_error("NPC.show_text_over_actor: actor not found: " + actor_path)
		return
	# Позиция над головой: можно кастомизировать отступ
	var origin = actor.global_position + Vector2(30, 0)
	show_text_at_position(text, origin, wait_for_input)
	
## То же, но возвращает сигнал завершения — чтобы катсцена могла дождаться конца.
func show_text_over_actor_and_wait(actor_path: String, text: String, wait_for_input: bool = true) -> Signal:
	show_text_over_actor(actor_path, text, wait_for_input)
	return dialog_finished

## Показывает текст в заданной позиции (при необходимости ждёт пробел).
func show_text_at_position(text: String, at_position: Vector2, wait_for_input: bool = true) -> void:
	if current_text_box:
		current_text_box.queue_free()
	current_text_box = text_box_scene.instantiate()
	current_text_box.z_index = 100
	get_tree().root.add_child(current_text_box)
	current_text_box.global_position = at_position
	current_text_box.display_text(text)
	await current_text_box.finished_displaying
	if wait_for_input:
		await _wait_for_input()
	_remove_text_box()
	dialog_finished.emit()

## Ждёт нажатия действия ui_accept.
func _wait_for_input() -> void:
	await get_tree().create_timer(0.1).timeout
	while true:
		if Input.is_action_just_pressed("ui_accept"):
			break
		await get_tree().process_frame

## Убирает текущее облачко текста.
func _remove_text_box() -> void:
	if current_text_box:
		current_text_box.queue_free()
		current_text_box = null

## Создаёт облачко текста над НПС и подключает обработку окончания печати.
func _show_text_bubble(text: String, options: Dictionary = {}) -> void:
	if current_text_box:
		current_text_box.queue_free()
	var origin = npc.get_dialog_origin()
	origin.y += 30
	current_text_box = text_box_scene.instantiate()
	get_tree().root.add_child(current_text_box)
	current_text_box.global_position = origin
	current_text_box.display_text(text)
	if options.size() > 0:
		current_text_box.finished_displaying.connect(_on_text_finished_with_options.bind(options))
	else:
		current_text_box.finished_displaying.connect(_on_text_finished_no_options)

## Убирает облачко после «филлерного» текста.
func _on_filler_text_finished() -> void:
	if current_text_box:
		current_text_box.queue_free()
		current_text_box = null

## После печати текста: если есть опции — показать их, иначе закрыть диалог.
func _on_text_finished_with_options(options: Dictionary) -> void:
	if options.size() > 0:
		_show_choices(options)
	else:
		hide_dialog()

## После печати текста без опций — закрыть диалог.
func _on_text_finished_no_options() -> void:
	hide_dialog()

## Показывает панель выбора с вариантами ответа.
func _show_choices(options: Dictionary) -> void:
	if current_choice_panel:
		current_choice_panel.queue_free()
	current_choice_panel = choice_panel_scene.instantiate()
	get_tree().root.add_child(current_choice_panel)
	current_choice_panel.set_options(options)
	current_choice_panel.choice_selected.connect(_on_choice_selected)
	waiting_for_choice = true

## Обрабатывает выбранный вариант и переходит к следующему состоянию диалога.
func _on_choice_selected(option: String) -> void:
	waiting_for_choice = false
	if current_text_box:
		current_text_box.queue_free()
		current_text_box = null
	if current_choice_panel:
		await current_choice_panel.hide_slide_out()
		current_choice_panel.queue_free()
		current_choice_panel = null
	var current_dialog = npc.get_current_dialog()
	if current_dialog == null:
		hide_dialog()
		return
	var next_state = current_dialog["options"].get(option, "start")
	npc.set_dialog_state(next_state)
	match next_state:
		"end":
			if npc.current_branch_index < npc.dialog_resource.get_npc_dialog(npc.npc_id).size() - 1:
				npc.set_dialog_tree(npc.current_branch_index + 1)
			hide_dialog()
		"exit":
			npc.set_dialog_state("start")
			hide_dialog()
		"give_quests":
			if npc.dialog_resource.get_npc_dialog(npc.npc_id)[npc.current_branch_index]["branch_id"] == "npc_default":
				offer_remaining_quests()
			else:
				offer_quests(npc.dialog_resource.get_npc_dialog(npc.npc_id)[npc.current_branch_index]["branch_id"])
			show_npc_dialog(npc)
		_:
			show_npc_dialog(npc)

## Закрывает диалог: убирает UI, полосы, возвращает камеру и управление игроку.
func hide_dialog() -> void:
	if current_text_box:
		current_text_box.queue_free()
		current_text_box = null
	if current_choice_panel:
		current_choice_panel.queue_free()
		current_choice_panel = null
	waiting_for_choice = false
	await cinematic_bars.hide_bars()
	await restore_camera()
	Global.player.can_move = true
	dialog_finished.emit()

## Предлагает игроку квесты указанной ветки (branch_id).
func offer_quests(branch_id: String) -> void:
	for quest in npc.quests:
		if quest.unlock_id == branch_id and quest.state == "not_started":
			npc.offer_quest(quest.quest_id)

## Предлагает все ещё не начатые квесты НПС.
func offer_remaining_quests() -> void:
	for quest in npc.quests:
		if quest.state == "not_started":
			npc.offer_quest(quest.quest_id)
