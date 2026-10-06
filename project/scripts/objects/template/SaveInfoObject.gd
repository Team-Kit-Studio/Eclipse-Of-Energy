extends RefCounted
class_name SavesTemplate
## Шаблоны структур данных сохранения (данные уровня/игрока и метаданные).

## Шаблон «данные сохранения» (сцена уровня, игрок, враги, союзники, предметы).
class DataTemp: 
	var data: Dictionary = {
		"data": {
			"level_scene": "",
			"player": null,
			"enemy": [],
			"allies": [],
			"items": []
		}
	}

## Шаблон «метаданные сохранения» (имя, время изменения, текст миссий).
class MetaDataTemp:
	var data: Dictionary = { 
		"metadata": {
			"name": "",
			"last_modified_time": {"date": null, "time": null},
			"missions_text": ""
		},
	} 
