class_name TacticalData
extends Resource
## Ресурс тактического расходника (гранаты, мины) — по аналогии с BulletData.
## ItemData ссылается на него через поле `tactical`. Сам снаряд (сцена) читает этот
## ресурс, поэтому новые виды гранат/мин добавляются без изменения кода.

## Тип снаряда: граната (бросок) или мина (установка).
enum TacticalType {
	GRENADE,  # Бросается по ЛКМ, летит и физически катится.
	MINE      # Ставится рядом с игроком, подрывается по пересечению сущности.
}

@export var tactical_type: TacticalType = TacticalType.GRENADE
## Путь к сцене снаряда (grenade.tscn / mine.tscn). Строкой, как принято в проекте.
@export var projectile_scene_path: String = ""
## Путь к сцене взрыва (общий визуал + AoE-урон).
@export var explosion_scene_path: String = "res://project/scenes/Weapons/Tactical/explosion.tscn"

@export_group("Бросок / установка")
## Скорость полёта брошенного предмета (px/сек).
@export var throw_speed: float = 620.0
## Фиксированное расстояние полёта до «приземления» (px). Одинаково для всего тактического.
@export var throw_distance: float = 300.0
## Начальная скорость катания после приземления (px/сек).
@export var roll_speed: float = 260.0
## Замедление катания (px/сек²): чем больше, тем быстрее предмет остановится.
@export var roll_friction: float = 520.0
## Время до взрыва гранаты (сек).
@export var fuse_time: float = 2.5
## Задержка взведения мины перед тем, как она станет активной (сек).
@export var arm_time: float = 0.4
## На сколько пикселей от игрока ставится мина (в сторону курсора).
@export var place_offset: float = 26.0

@export_group("Взрыв")
## Радиус поражения взрыва (px).
@export var explosion_radius: float = 120.0
## Сила отбрасывания сущностей от эпицентра.
@export var knockback_force: float = 420.0
## Длительность отбрасывания (сек).
@export var knockback_duration: float = 0.25

@export_group("Ассеты (необязательно)")
## Текстура вспышки взрыва. Если пусто — используется процедурный плейсхолдер.
@export var explosion_texture: Texture2D
## Путь к звуку взрыва. Если пусто — взрыв проигрывается беззвучно.
@export var sfx_path: String = ""
