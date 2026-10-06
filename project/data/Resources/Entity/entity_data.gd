extends Resource
class_name EntityData

@export_group("Основные характеристики")
@export var entity_id: String = "player"
@export var max_hp: int = 100
@export var walk_speed: float = 60.0
@export var run_speed: float = 120.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

@export_group("Аудио")
@export var footstep_sound: AudioStream

@export_group("Внешний вид и Анимации")
@export var default_skin: String = "suit"
@export var skins: Array[SkinData]

# Вспомогательный метод для получения данных скина
func get_skin_data(skin_name: String) -> SkinData:
	for s in skins:
		if s and s.skin_name == skin_name:
			return s
	# Fallback на первый скин, если запрошенный не найден
	if skins.size() > 0 and skins[0]:
		return skins[0]
	return null
