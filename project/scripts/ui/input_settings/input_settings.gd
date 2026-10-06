extends Control
## Настройка привязок управления: переназначение действий и сохранение в конфиг.

@onready var changable_list: VBoxContainer = $PanelContainer/MarginContainer/ScrollContainer/ChangableList
# наш список кнопок
const INPUT_ACTION: Dictionary[StringName, String] = {
	StringName("up"): "Вверх",
	StringName("left"): "Влево",
	StringName("down"): "Вниз",
	StringName("right"): "Вправо",
	StringName("Inventory"): "Инвентарь",
	StringName("Interaction"): "Взаимодействие"
}

var is_remapping: bool = false
var action_to_remap: StringName
var remaping_button: Button 

func _ready() -> void:
	load_control_from_settings()
	_create_action_list()


#создает список кнопок для переназначения управлений
func _create_action_list() -> void:
	for item: Node in changable_list.get_children():
		item.call_deferred("queue_free")

	for action: StringName in INPUT_ACTION.keys():
		var button: Button = load("res://project/scenes/ui/input_settings/button.tscn").instantiate()
		var action_label: Label = button.find_child("LabelAction")
		var input_label: Label = button.find_child("InputLabel")
		
		action_label.text = INPUT_ACTION[action]
		
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if events.size() > 0:
			input_label.text = events[0].as_text().trim_suffix(" (Physical)")

		else:
			input_label.text = ""
		changable_list.add_child(button)
		button.pressed.connect(Callable(self, "_on_button_pressed").bind(button, action))

# при нажатии на кнопку в управлении
func _on_button_pressed(button: Button, action: String)-> void:
	if not is_remapping:
		is_remapping = true
		action_to_remap = action
		remaping_button = button
		button.find_child("InputLabel").text = "Press Key To Bind"
		
#обрабатывает переназначение управлений
func _input(event: InputEvent) -> void:
	if not is_remapping:
		return

	if (event is InputEventKey || (event is InputEventMouseButton && event.pressed)):

		InputMap.action_erase_events(action_to_remap)
		InputMap.action_add_event(action_to_remap, event)
		SettingsLoader.save_control_settings(action_to_remap, event)
		_update_changable_list(remaping_button, event)
		
		
		is_remapping = false
		action_to_remap = ""
		remaping_button = null
			
#загружает пользовательские настройки управления из сохраненного файла
func load_control_from_settings() -> void:
	var keybinds: Dictionary[String, InputEvent] = SettingsLoader.get_key_binds()
	for action: String in keybinds.keys():
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, keybinds[action])

#обновляет текст на кнопке после переназначения управления
func _update_changable_list(button: Button, event: InputEvent) -> void:
	button.find_child("InputLabel").text = event.as_text().trim_suffix(" (Physical)")
