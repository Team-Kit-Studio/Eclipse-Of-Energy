extends Node2D
## Интро-сцена: проигрывает анимацию и переходит в главное меню.

## Проигрыватель анимации интро.
@onready var anim: AnimationPlayer = $AnimationPlayer
## Заранее созданный экземпляр сцены главного меню.
@onready var main_menu: Node2D = preload("res://project/scenes/ui/main_menu/Main_Menu.tscn").instantiate()


## Запускает анимацию интро.
func _ready() -> void:
	anim.play("intro")



## Переходит в главное меню.
func to_main() -> void:
	get_tree().change_scene_to_node(main_menu)
