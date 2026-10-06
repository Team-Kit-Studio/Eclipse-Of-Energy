extends Node
class_name QuestManager
## Менеджер квестов игрока: добавляет/обновляет/завершает квесты, шлёт сигналы UI.

## Квестовый журнал (нода QuestUI).
@onready var quest_ui = $QuestUI

## Сигнал: квест обновлён.
signal quest_updated(quest_id: String)
## Сигнал: цель квеста обновлена.
signal objective_updated(quest_id: String, objective_id: String)
## Сигнал: список квестов изменился.
signal quest_list_updated()
## Активные квесты {quest_id: Quest}.
var quests = {}

## Добавляет квест и делает его активным в трекере игрока.
func add_quest(quest: Quest):
	quests[quest.quest_id] = quest
	# Автоматически делаем этот квест активным в трекере
	if Global.player:
		Global.player.selected_quest = quest
		Global.player.update_quest_tracker(quest)
	quest_updated.emit(quest.quest_id)
	quest_list_updated.emit()

## Удаляет квест из журнала (и сбрасывает трекер, если он был выбран).
func _remove_quest(quest_id: String):
	quests.erase(quest_id)
	# Если удаляем выбранный квест, сбрасываем трекер
	if Global.player and Global.player.selected_quest and Global.player.selected_quest.quest_id == quest_id:
		Global.player.selected_quest = null
		Global.player.update_quest_tracker(null)
	quest_list_updated.emit()
	
## Возвращает квест по id (или null).
func get_quest(quest_id: String) -> Quest:
	return quests.get(quest_id, null)

## Обновляет состояние квеста (при "completed" — удаляет его).
func update_quest(quest_id: String, state: String):
	var quest = get_quest(quest_id)
	if quest:
		quest.state = state
		quest_updated.emit(quest_id)
		if state == "completed":
			_remove_quest(quest_id)
			
## Возвращает список активных (in_progress) квестов.
func get_active_quests() -> Array:
	var active_quests = []
	for quest in quests.values():
		if quest.state == "in_progress":
			active_quests.append(quest)
	return active_quests

## Отмечает цель квеста выполненной и шлёт сигнал.
func complete_objective(quest_id: String, objective_id: String):
	var quest = get_quest(quest_id)
	if quest:
		quest.complete_objective(objective_id)
		objective_updated.emit(quest_id, objective_id)
						
## Показывает/скрывает журнал квестов.
func show_quest_log():
	quest_ui.show_hide_log()

## Завершает квест: выдаёт награды и убирает из журнала.
func complete_quest_ex(quest_id: String) -> void:
	var quest = get_quest(quest_id)
	if not quest or quest.state != "in_progress":
		return

	for reward in quest.rewards:
		match reward.reward_type:
			Rewards.RewardType.COINS:
				Global.player.coin_amount += reward.reward_amount
				Global.player.update_coins()
			Rewards.RewardType.ITEM:
				pass  # выдача предмета при необходимости
			Rewards.RewardType.EXPERIENCE:
				pass

	_remove_quest(quest_id)
