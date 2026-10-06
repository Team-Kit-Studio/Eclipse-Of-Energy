extends Node
## Загрузка/сохранение пользовательских настроек (autoload SettingsLoader):
## видео, аудио и привязки управления через ConfigFile.

## Открытый конфиг настроек.
var config: ConfigFile

## При старте ищет файл настроек; если нет — создаёт с настройками по умолчанию.
func _ready() -> void:
	if not FileAccess.file_exists(Main.SETTINGS_CONFIG_PATH):
		new_config_settings()
	
	else:
		load_data()
	

## Сохраняет конфиг настроек на диск.
func save_data() -> void:
	config.save(Main.SETTINGS_CONFIG_PATH)
	


## Создаёт новый конфиг с настройками по умолчанию.
func new_config_settings() -> void:
	config = ConfigUtil.set_config_dict(PrivateDefaultSettingsData.new().SETTINGS)

## Загружает конфиг с диска и применяет настройки видео.
func load_data() -> void:
	config = ConfigUtil.load_config(Main.SETTINGS_CONFIG_PATH)
	load_video_settings()

## Сохраняет настройку управления (действие → событие ввода).
func save_control_settings(action: String, event: InputEvent) -> void:
	var event_str: String
	if event is InputEventKey:
		event_str = OS.get_keycode_string(event.physical_keycode)

	elif event is InputEventMouseButton:
		event_str = "mouse_" + str(event.button_index)

	config.set_value("Control", action, event_str)
	save_data()

## Загружает и преобразует сохранённые привязки управления в объекты InputEvent.
func get_key_binds() -> Dictionary[String, InputEvent]:
	var binds_settings: Dictionary[String, InputEvent] = {}
	for action: String  in config.get_section_keys("Control"): #запускаем цикл по всем ключам секции "Control"
		var input_event: InputEvent
		var value: String = config.get_value("Control", action) #получаем значение для текущего действия(action) из секции Control

		if value.contains("mouse_"):
			input_event = InputEventMouseButton.new()
			input_event.button_index = int(value.split("_")[1])
			
		else:
			input_event = InputEventKey.new()
			input_event.keycode = OS.find_keycode_from_string(value)
				
				
		binds_settings[action] = input_event
	
	return binds_settings

## Применяет сохранённые настройки видео (полный экран, безрамочный режим, vsync).
func load_video_settings() -> void:
	DisplayServer.window_set_mode(config.get_value("Video", "fullscreen"))

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, config.get_value("Video", "borderless"))

	DisplayServer.window_set_vsync_mode(config.get_value("Video", "vsync"))

## Сохраняет настройку аудио (ключ → значение).
func save_audio_settings(key: String, value: float)-> void:
	config.set_value("Audio", key, value)

## Загружает настройки аудио из секции «Аудио».
func load_audio_settings() -> Dictionary[String, float]:
	var audio_settings: Dictionary[String, float] = {}
	for key in config.get_section_keys("Аудио"):
		audio_settings[key] = config.get_value("Аудио", key)
	return audio_settings
