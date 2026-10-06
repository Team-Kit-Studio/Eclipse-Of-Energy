extends Control
## Игровое меню (пауза): панели/вкладки и возврат в игру/главное меню.
@onready var canvas: CanvasLayer = $CanvasLayer
@onready var mainMenu: Control = $CanvasLayer/Main_Menu
@onready var settings: TabContainer = $CanvasLayer/GUI/Settings
@onready var pauseButton: Button = $CanvasLayer/Pause
@onready var saveLoadButton: Button = $"CanvasLayer/Main_Menu/PanelContainer/HBoxContainer/VBoxContainer/SaveLoad_Game"
@onready var optionsButton: Button = $CanvasLayer/Main_Menu/PanelContainer/HBoxContainer/VBoxContainer/Options
@onready var saveMenu: Control = $CanvasLayer/GUI/SaveMenu
@onready var Anim: AnimationPlayer = $AnimationPlayer
@onready var audio_menu: AudioStreamPlayer2D = $AudioMenu



func _ready() -> void:
	saveMenu.hidden.connect(func() -> void: if saveMenu.visible: return else: saveLoadButton.button_pressed = false)
	canvas.show()
	mainMenu.hide()
	settings.hide()	
	settings.modulate = Color(1,1,1,0.1)
	pauseButton.show()
	

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		toggle()

#режим отжимной кнопки
func toggle() -> void:
	#visible = !visible
	pauseButton.visible = !pauseButton.visible	
	mainMenu.visible = !mainMenu.visible
	saveMenu.hide()
	settings.hide()
	off_toggeled()
	
	if !pauseButton.visible:
		audio_menu.play()
	else:
		audio_menu.stop()
	
	get_tree().paused = !get_tree().paused  # Игровая пауза остаётся
	
# при нажатии на кнопку настроек
func _on_options_toggled(toggled_on: bool) -> void:
	saveMenu.hide()
	if toggled_on:
		saveLoadButton.button_pressed = false
		settings.show()
		Anim.play("settings")
		#tween.tween_property(settings, "position:x", 310, 1)
	else:
		Anim.play_backwards("settings")
		await Anim.animation_finished
		settings.hide()
		
	
		
		

func _on_continue_pressed() -> void:
	continues()

func _on_button_pressed() -> void:
	toggle()
	

func continues() -> void:
	audio_menu.stop() 
	pauseButton.show()
	mainMenu.hide()
	saveMenu.hide()
	off_toggeled()
	settings.hide()
	get_tree().paused = false

	if not settings.visible:
		optionsButton.button_pressed = false

	if not saveMenu.visible:
		saveLoadButton.button_pressed = false

func off_toggeled() -> void:
	optionsButton.button_pressed = false
	saveLoadButton.button_pressed = false

func _on_save_game_toggled(toggled_on: bool) -> void:
	settings.hide()
	if toggled_on:
		optionsButton.button_pressed = false
		saveMenu.show()
		Anim.play("SalveLoad")
	else:
		Anim.play_backwards("SalveLoad")
		await Anim.animation_finished
		saveMenu.hide()


func _on_exit_game_pressed() -> void:
	get_tree().quit()


func _on_exit_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://project/scenes/ui/main_menu/Main_Menu.tscn")

func hide_canvas() -> void:
	mainMenu.hide()
	canvas.hide()

func show_canvas() -> void:
	mainMenu.show()
	canvas.show()
