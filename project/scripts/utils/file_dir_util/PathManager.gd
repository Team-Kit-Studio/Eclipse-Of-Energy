class_name PathManager
## Утилита построения путей к файлам и директориям.

## Строит путь к файлу: base + name + расширение (точка добавляется при необходимости).
static func build_path(base_path: String, name: String, extension: String) -> String:
	if extension != "" and not extension.begins_with("."):
		extension = "." + extension
		
	return "%s%s%s" % [base_path, name, extension]

## Строит путь к директории: base + name + "/".
static func build_directory_path(base_path: String, directory_name: String) -> String:
	return "%s%s/" % [base_path, directory_name]
	
