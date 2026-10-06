extends Control
## Окно создания нового сохранения: ввод имени и выбор источника данных.

@onready var line_edit: LineEdit = $Panel/HBoxContainer/VBoxContainer/MarginContainer/LineEdit

# Функция вызывается при готовности узла
func _ready() -> void:
	line_edit.call_deferred("grab_focus")

# Функции для обработки нажатий кнопок
func _on_apply_pressed() -> void:
	var save_name: String = check_restrictions(line_edit.text)
	line_edit.clear()
	if save_name and not save_name.length() >= Main.SAVE_NAME_CHARACTERS_LIMIT:
		animate_and_hide()
		get_parent().emit_signal("create_new_save", save_name)
	
	else:
		show_invalid_name_message("Используйте только буквы и цифры, не более %s символов!" % Main.SAVE_NAME_CHARACTERS_LIMIT)


func _on_cancel_pressed() -> void:
	animate_and_hide()

# Функции для анимации и отображения
func animate_and_hide() -> void:
	line_edit.clear()
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.1)
	await tween.finished
	self.hide()

func animate_and_show() -> void:
	line_edit.clear()
	self.show()
	self.scale = Vector2(0.4, 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)

# Функция для отображения сообщения о неверном названии
func show_invalid_name_message(message: String) -> void:
	line_edit.placeholder_text = "Неверное название!"
	await get_tree().create_timer(2.2).timeout
	line_edit.placeholder_text = message
	await get_tree().create_timer(2.2).timeout
	line_edit.placeholder_text = "Введите название..."

# Функция для проверки ограничений на вводимый текст
func check_restrictions(input_text: String) -> String:
	for letter: String in input_text:
		if letter in Main.FORBIDDEN_CHARACTERS:
			return ""
	return input_text
