extends Control
## Журнал квестов (UI): список активных квестов и детали выбранного.

## Узлы панели: список квестов и блок деталей.
@onready var panel = $CanvasLayer/Panel
@onready var quest_list = $CanvasLayer/Panel/Contents/Details/QuestList
@onready var quest_title = $CanvasLayer/Panel/Contents/Details/QuestDetails/QuestTitle
@onready var quest_description = $CanvasLayer/Panel/Contents/Details/QuestDetails/QuestDescription
@onready var quest_objectives = $CanvasLayer/Panel/Contents/Details/QuestDetails/QuestObjectives
@onready var quest_rewards = $CanvasLayer/Panel/Contents/Details/QuestDetails/QuestRewards
@onready var canvas_layer: CanvasLayer = $CanvasLayer

## Квест, выбранный в журнале.
var selected_quest: Quest = null
## Ссылка на менеджер квестов (родитель).
var quest_manager

## При старте прячет панель и подписывается на сигналы менеджера квестов.
func _ready():
	canvas_layer.show()
	panel.visible = false
	clear_quest_details()
	
	quest_manager = get_parent()
	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.objective_updated.connect(_on_objectives_updated)

## Показывает/скрывает журнал и обновляет его содержимое.
func show_hide_log():
	panel.visible = !panel.visible
	update_quest_list()
	if selected_quest:
		_on_quest_selected(selected_quest)

## Перестраивает список активных квестов.
func update_quest_list():
	for child in quest_list.get_children():
		quest_list.remove_child(child)
		
	var active_quests = quest_manager.get_active_quests()
	if active_quests.size() == 0:
		clear_quest_details()
	else:
		for quest in active_quests:
			var button = Button.new()
			button.add_theme_font_size_override("font_size", 20)
			button.text = quest.quest_name
			button.pressed.connect(_on_quest_selected.bind(quest))
			quest_list.add_child(button)
	# Больше не трогаем трекер игрока!

## Выбирает квест, обновляет трекер игрока и заполняет детали (цели/награды).
func _on_quest_selected(quest: Quest):
	selected_quest = quest
	# Устанавливаем глобальный выбранный квест и обновляем трекер
	Global.player.selected_quest = quest
	Global.player.update_quest_tracker(quest)
	# Заполняем детали
	quest_title.text = quest.quest_name
	quest_description.text = quest.quest_description
	
	for child in quest_objectives.get_children():
		quest_objectives.remove_child(child)
	for objective in quest.objectives:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		if objective.target_type == "collection":
			label.text = objective.description + " (" + str(objective.collected_quantity) + "/" + str(objective.required_quantity) + ")"
		else:
			label.text = objective.description
		label.add_theme_color_override("font_color", Color(0, 1, 0) if objective.is_completed else Color(1, 0, 0))
		quest_objectives.add_child(label)
	
	for child in quest_rewards.get_children():
		quest_rewards.remove_child(child)
	for reward in quest.rewards:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0, 0.84, 0))
		var reward_name = Rewards.RewardType.keys()[reward.reward_type].capitalize()
		label.text = "Reward: " + reward_name + ": " + str(reward.reward_amount)
		quest_rewards.add_child(label)

## Очищает блок деталей квеста.
func clear_quest_details():
	quest_title.text = ""
	quest_description.text = ""
	for child in quest_objectives.get_children():
		quest_objectives.remove_child(child)
	for child in quest_rewards.get_children():
		quest_rewards.remove_child(child)

## Обновляет список при изменении квеста и перевыделяет выбранный.
func _on_quest_updated(quest_id: String):
	# Просто обновляем список, не трогая selected_quest игрока
	update_quest_list()
	# Если в UI был выбран этот квест, перевыделим его
	if selected_quest and selected_quest.quest_id == quest_id:
		_on_quest_selected(selected_quest)
	else:
		selected_quest = null  # сбрасываем локальное выделение, если квест удалён/изменён

## Обновляет детали при изменении цели квеста.
func _on_objectives_updated(quest_id: String, _objective_id: String):
	if selected_quest and selected_quest.quest_id == quest_id:
		_on_quest_selected(selected_quest)
	else:
		update_quest_list()

## Обработчик кнопки закрытия журнала.
func _on_close_button_pressed():
	show_hide_log()
