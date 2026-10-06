class_name ConfigUtil
## Утилита работы с ConfigFile: загрузка и сборка из словаря/массива.

## Загружает ConfigFile по пути. Возвращает null, если файл не существует.
static func load_config(path: String) -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()

	if not FileAccess.file_exists(path):
		config = null
		return

	config.load(path)
	return config


## Создаёт ConfigFile из вложенного словаря вида {секция: {ключ: значение}}.
static func set_config_dict(data: Dictionary) -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	for section_key: String in data.keys():
		for key: String in data[section_key].keys():
			config.set_value(section_key, key, data[section_key][key])

	return config

## Создаёт ConfigFile из массива словарей (ключ "name" задаёт имя секции).
static func set_config_array(data: Array[Dictionary]) -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	for dict: Dictionary in data:
		for property: String in dict.keys():
			config.set_value(dict["name"], property, dict[property])

	return config
