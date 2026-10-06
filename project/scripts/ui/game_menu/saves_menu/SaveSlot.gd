extends Panel
## Плитка одного сохранения в списке: имя, дата, превью и действия.

@onready var parent: Node = get_parent().get_owner()

var is_pressed: bool = false
var is_mouse_over: bool = false

var image_save: Texture2D

# Инициализация
func _ready() -> void:
	$VBoxContainer/HBoxContainer/SaveName.text = self.name
	$Line2D.hide()

# Обработка событий мыши
func _on_mouse_entered() -> void:
	is_mouse_over = true
	if not is_pressed:
		$Line2D.show()

func _on_mouse_exited() -> void:
	is_mouse_over = false
	if not is_pressed:
		$Line2D.hide()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.double_click:
			pass
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			handle_mouse_click()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if is_pressed and not is_mouse_over:
			is_pressed = false
			parent.disable_buttons()
			parent.set_save_image(null)
			hide_line()

# Обработка клика мыши
func handle_mouse_click() -> void:
	is_pressed = true
	show_line()
	parent.emit_signal("update_current_node", self)
	parent.enable_buttons()
	parent.set_save_image(image_save)

# Управление линией
func hide_line() -> void:
	$Line2D.hide()

func show_line() -> void:
	$Line2D.show()

# Обновление времени
func update_time_ready() -> void:
	handle_date_time(Time.get_date_dict_from_system(), Time.get_time_dict_from_system())

func update_time_json() -> void:
	var time_data: Dictionary = FileUtil.file_read(
		PathManager.build_path(Main.SAVE_FOLDER_PATH + self.name, "/metadata", ".json"), 
		FileUtil.encrypt_mode.NO_DECRYPTION
	)
	
	# Проверяем структуру данных правильно
	if (time_data.is_empty() or 
		not time_data.has("last_modified_time") or 
		not time_data["last_modified_time"].has("date")):
		return  # Файл пустой или структура неверная
	
	handle_date_time(
		time_data["last_modified_time"]["date"], 
		time_data["last_modified_time"]["time"]
	)


# Форматирование даты и времени
func format_date_time(date: Dictionary, time: Dictionary) -> String:
	var formatted_date: String = "%02d.%02d.%d" % [date.day, date.month, date.year]
	var formatted_time: String = "%02d:%02d" % [time.hour, time.minute] 
	return "%s\n%s" % [formatted_date, formatted_time]

# Обработка даты и времени
func handle_date_time(date: Dictionary, time: Dictionary) -> void:
	var formatted_date_time: String = format_date_time(date, time)
	update_text(formatted_date_time)

# Обновление текста
func update_text(_text: String) -> void:
	$VBoxContainer/HBoxContainer/SaveDate.text = _text
