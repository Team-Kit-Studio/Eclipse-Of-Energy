extends Node
## Глобальный скрипт (autoload Main): константы путей, версия и среда запуска игры.
## Здесь хранится информация об игре и вызываются функции, нужные при старте.

## Символы, запрещённые в именах сохранений/файлов.
const FORBIDDEN_CHARACTERS: Array[StringName] = [
	"\\", "/", ":", "*", "?", "\"", "<", ">", "|", "#", "%", "{", "}",
	"^", "~", "[", "]", ";", ",", ".", "(", ")", "@", "$", "&", "!", "+",
	" ", "№", "«", "»", "—", "–", "“", "”", "„", "‘", "’", "‚", "‹", "›",
	]

## Ключ шифрования данных сохранений.
const ENCRYPT_KEY: StringName = StringName("1670d1f781e5ebee67da304f4fda6b04303616c3850ff218baaff7aca251c569")

## Корневая папка пользовательских данных.
const USER_FOLDER_PATH: StringName = StringName("user://")
## Папка сохранений.
const SAVE_FOLDER_PATH: StringName = StringName("user://saves/")
## Файл-список сохранений.
const SAVE_LIST_CONFIG_PATH: StringName = StringName("user://saves/_saves_list.cfg")
## Файл пользовательских настроек.
const SETTINGS_CONFIG_PATH: StringName = StringName("user://user_config/settings.cfg")

## Максимальное количество слотов сохранений.
const SAVES_LIMIT: int = 13
## Лимит символов в имени сохранения.
const SAVE_NAME_CHARACTERS_LIMIT: int = 20

## При старте создаёт нужные папки и файл-список сохранений.
func _ready() -> void:
	DirUtil.create_folders(USER_FOLDER_PATH, ["saves", "user_config", "screenshot"])
	if not FileAccess.file_exists(SAVE_LIST_CONFIG_PATH): ConfigFile.new().save(SAVE_LIST_CONFIG_PATH)

## Отладочный вывод использования памяти (стек / занято / свободно).
func debag_memory() -> void:
	var memory_info: Dictionary = OS.get_memory_info()

	var total: float = memory_info["stack"] / (1024 * 1024)
	var used: float = OS.get_static_memory_usage() / (1024.0 * 1024.0)
	var free: float = memory_info["free"] / (1024 * 1024)

	print("Стек: %.1f МБ" % total, " Используемая память: %.2f МБ" % used, " Свободная память: %.1f МБ" % free)
