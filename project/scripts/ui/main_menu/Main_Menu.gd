extends Node2D
## Главное меню: запуск игры, загрузка сохранения, настройки, выход.


@onready var menu: Control = $Main_Menu
@onready var options: Control = $Options
@onready var video: Control = $Video
@onready var audio: Control = $Audio
@onready var audiogame: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var controls: Control = $Controls
@onready var Anim: AnimationPlayer = $AnimationPlayer
@onready var cut_scene1: Node2D = preload("res://project/scenes/Cut-Scenes/kut_scene1.tscn").instantiate()

func _ready() -> void:
	intro()
	$DirectionalLight2D.enabled = true
	menu.visible = true
	options.visible = false
	video.visible = false
	audio.visible = false
	controls.visible = false
	Cursor.sprite.show()
	audiogame.play()


func intro() -> void: # функция появления меню
	Anim.play("intro")
	if audiogame.playing == false:
		audiogame.playing = true

func _on_exit_pressed() -> void: # при нажатии на кнопку выхода, закрваем игру
	get_tree().quit()

func _on_start_pressed() -> void:
	Global.to_cutscene = true
	get_tree().change_scene_to_node(cut_scene1)

# Дальше функции при выполнении которых меняются страницы меню

func _on_options_pressed() -> void:
	menu.visible = false
	options.visible = true

func _on_video_pressed() -> void:
	options.visible = false
	video.visible = true

func _on_audio_pressed() -> void:
	options.visible = false
	audio.visible = true

func _on_back_menu_pressed() -> void:
	options.visible = false
	menu.visible = true

func _on_back_settings_pressed() -> void:
	video.visible = false
	audio.visible = false
	controls.visible = false
	options.visible = true


func _on_controls_pressed() -> void:
	options.visible = false
	controls.visible = true
