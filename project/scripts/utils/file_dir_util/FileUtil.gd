class_name FileUtil
## Утилита работы с файлами: пути, сохранение/чтение JSON (в т.ч. с шифрованием), удаление.

## Режим работы с файлом при сохранении/чтении (шифрование опционально).
enum encrypt_mode {
	ENCRYPT,
	NO_ENCRYPT,
	DECRYPTION,
	NO_DECRYPTION
}

## Строит полный путь к файлу (обёртка над PathManager).
static func get_file_path(folder_path: String, file_name: String, extension: String) -> String:
	return PathManager.build_path(folder_path, file_name, extension)

## Сохраняет словарь как JSON-файл (опционально с шифрованием паролем).
static func save_to_file_as_format_json(data: Dictionary, folder_path: String, file_name: String, extension: String, save_mode: encrypt_mode = encrypt_mode.NO_DECRYPTION, encrypt_pass: StringName = "") -> void:
	var path: String = get_file_path(folder_path, file_name, extension)
	var json_string: String = JSON.stringify(data, '\t')
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	match save_mode:
		encrypt_mode.ENCRYPT:
			file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encrypt_pass)
			if FileAccess.get_open_error() == OK:
				file.store_string(json_string)
				file.close()

		encrypt_mode.NO_ENCRYPT:
			if file:
				file.store_string(json_string)
				file.close()

	file.close()


## Читает JSON-файл в словарь (опционально с расшифровкой паролем).
static func file_read(file_path: String, decryption_mode: encrypt_mode = encrypt_mode.NO_DECRYPTION, encrypt_pass: StringName = "") -> Dictionary:

	if not FileAccess.file_exists(file_path): return {}

	var file: FileAccess

	match decryption_mode:
		encrypt_mode.DECRYPTION:
			file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, encrypt_pass)
			if FileAccess.get_open_error() == OK: return JSON.parse_string(file.get_as_text())

		encrypt_mode.NO_DECRYPTION:
			file = FileAccess.open(file_path, FileAccess.READ)
			if FileAccess.get_open_error() == OK: return JSON.parse_string(file.get_as_text())

	return {}

## Удаляет указанный файл, если он существует.
static func delete_file(file_path: String) -> void:
	if FileAccess.file_exists(file_path): 
		DirAccess.remove_absolute(file_path)
