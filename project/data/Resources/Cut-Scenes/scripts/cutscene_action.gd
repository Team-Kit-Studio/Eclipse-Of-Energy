extends Resource
class_name CutsceneAction

enum ActionType {
	WAIT,
	MOVE_ACTOR,
	CALL_METHOD,
	SHOW_TEXT_OVER_ACTOR,
	MOVE_ACTOR_BY_POINTS,
	SPAWN_ACTOR,
	REMOVE_ACTOR,
	ADD_ITEM,
	ADD_QUEST,
	COMPLETE_QUEST,
	GIVE_WEAPON
}

@export var type: ActionType = ActionType.WAIT

@export_category("Wait")
@export var duration: float = 1.0

@export_category("Move Actor")
@export var actor_path: String = ""
@export var path_node: String = ""
@export var move_speed: float = 100.0

@export_category("Call Method")
@export var target_path: String = ""
@export var method_name: String = ""
@export var args: Array = []
@export var wait_for_signal: bool = false

@export_category("Show Text Over Actor")
@export var text_actor_path: String = ""
@export_multiline var text_to_show: String = ""
@export var wait_for_completion: bool = true

@export_category("Move Actor By Points")
@export var points: Array = []
@export var points_speed: float = 100.0

@export_category("Spawn Actor")
@export var spawn_id: String = ""
@export var scene_path: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var parent_path: String = ""
@export var skin: String = ""
@export var hide_marker: bool = false

@export_category("Remove Actor")
@export var remove_target: String = ""

# ═══════════════ ADD ITEM ═══════════════
@export_category("Add Item")
## Путь к ресурсу ItemData (например "res://items/health_potion.tres")
@export var item_resource_path: String = ""
## Количество (если 0, берётся значение из ресурса)
@export var item_amount: int = 1

# ═══════════════ ADD QUEST ═══════════════
@export_category("Add Quest")
## Путь к ресурсу Quest (например "res://quests/find_key.tres"), который нужно добавить игроку.
@export var quest_resource_path: String = ""

# ═══════════════ COMPLETE QUEST ═══════════════
@export_category("Complete Quest")
## Идентификатор квеста (quest_id), который нужно завершить и выдать награду.
@export var complete_quest_id: String = ""

# ═══════════════ GIVE WEAPON ═══════════════
@export_category("Give Weapon")
## Путь к ресурсу WeaponStats (например "res://weapons/shotgun.tres")
@export var weapon_resource_path: String = ""
## В какой слот поместить (0=Primary, 1=Secondary, 2=Special)
@export var weapon_slot: int = 1
