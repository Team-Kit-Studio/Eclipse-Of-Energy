class_name ItemData
extends Resource

## Скрипт ресурса тактического снаряда. Подключаем через preload, а не по имени
## глобального класса — так ItemData не зависит от порядка регистрации классов.
const TacticalDataScript = preload("res://project/scripts/Weapons/Tactical/tactical_data.gd")

## Тип предмета, определяющий его категорию и поведение.
enum ItemType {
	MISC,           # Обычный предмет без специального назначения
	RESOURCE,       # Ресурс для крафта или улучшения
	CONSUMABLE,     # Расходуемый предмет (аптечки, гранаты и т.п.)
	WEAPON,         # Оружие
	QUEST,          # Предмет, связанный с квестами
	ARMOR           # Броня
}

## Подтип оружия или расходника. Используется для определения слота в хотбаре.
enum WeaponType {
	NONE,                    # Не оружие и не расходник
	PRIMARY,                 # Основное оружие (автоматы, винтовки, дробовики)
	SECONDARY,               # Вторичное оружие (пистолеты, рукопашное, гранатометы)
	CONSUMABLE_TACTICAL,     # Тактический расходник (гранаты, мины)
	CONSUMABLE_MEDICAL       # Медицинский расходник (аптечки, бинты)
}

## Режим восстановления здоровья медицинским расходником.
enum HealMode {
	INSTANT,    # Восстанавливает всё здоровье сразу при использовании
	OVER_TIME   # Восстанавливает здоровье постепенно за heal_duration секунд
}

## Режим атаки оружия.
enum AttackMode {
	RANGED,  # Стрельба снарядами (BulletData)
	MELEE    # Ближний бой: взмах и удар по площади в радиусе attack_range
}

# ═══════════════════ ОСНОВНОЕ ═══════════════════
@export_category("Основное")
## Уникальный идентификатор предмета (используется в скриптах, дверях, квестах).
@export var item_id: String = ""
## Отображаемое имя предмета.
@export var name: String = "Item"
## Иконка предмета для инвентаря, хотбара и мира.
@export var texture: Texture2D
## Краткое описание, показываемое в UI при осмотре.
@export_multiline var description: String = ""

# ═══════════════════ РАЗМЕРЫ ═══════════════════
@export_category("Размеры")
## Ширина в ячейках инвентаря (для тетрис-сетки).
@export var width: int = 1
## Высота в ячейках инвентаря.
@export var height: int = 1
## Повёрнут ли предмет на 90° в сетке (не сохраняется в файле, актуально только в рантайме).
@export var is_rotated: bool = false

# ═══════════════════ КОЛИЧЕСТВО ═══════════════════
@export_category("Количество")
## Текущее количество предметов в стаке.
@export var amount: int = 1
## Максимальный размер стака. Если >1, предмет можно стакать.
@export var max_stack_size: int = 1

# ═══════════════════ ТИП ПРЕДМЕТА ═══════════════════
@export_category("Тип предмета")
## Основная категория предмета.
@export var item_type: ItemType = ItemType.MISC
## Подтип, определяющий слот хотбара и способ использования.
@export var weapon_type: WeaponType = WeaponType.NONE

# ═══════════════════ ОРУЖИЕ (если weapon_type != NONE) ═══════════════════
@export_category("Оружие (если weapon_type != NONE)")
## Ресурс пули (BulletData) — единая сцена пули читает его. Оружие просто
## ссылается на нужный тип пули, не создавая свою сцену снаряда.
@export var bullet: BulletData
## Смещение спрайта оружия относительно Pivot (вправо = вперёд от руки).
@export var sprite_offset: Vector2 = Vector2(18, 0)
## Позиция точки вылета пуль (маркера) относительно Pivot — конец ствола/острия.
@export var muzzle_offset: Vector2 = Vector2.ZERO
## Масштаб спрайта оружия (крупнее/мельче текстуру).
@export var sprite_scale: Vector2 = Vector2.ONE
## Тип боеприпаса (для отображения и проверки наличия).
@export var ammo_type: String = ""
## Текущее количество патронов в магазине.
@export var ammo_current: int = 0
## Максимальная ёмкость магазина.
@export var ammo_max: int = 30
## Базовый урон за одно попадание/удар.
@export var damage: int = 10
## Скорострельность (выстрелов в секунду) – используется для расчёта кулдауна.
@export var fire_rate: float = 0.1
## Разброс оружия при стрельбе
@export var spread: float
## Сколько снарядов выпускается за один выстрел (для дробовика — много дробинок).
@export var projectiles: int = 1
## Скорость, урон и дальность пули теперь задаются в ресурсе BulletData
## (bullet.bullet_speed / bullet.damage / bullet.travel_range).
## Бесконечный боезапас (не требуется перезарядка).
@export var infinite_ammo: bool = false
## Режим атаки: стрельба снарядами или ближний бой.
@export var attack_mode: AttackMode = AttackMode.RANGED
## Дальность ближнего боя (px) — используется при attack_mode = MELEE.
@export var attack_range: float = 0.0

# ═══════════════════ РАСХОДНИКИ (если CONSUMABLE) ═══════════════════
@export_category("Расходники (если CONSUMABLE)")
## Количество здоровья, восстанавливаемое при использовании.
@export var heal_amount: int = 0
## Время применения предмета (в секундах).
@export var use_time: float = 1.0
## Как восстанавливается здоровье: мгновенно или растянуто по времени.
@export var heal_mode: HealMode = HealMode.INSTANT
## За сколько секунд восстанавливается heal_amount при heal_mode = OVER_TIME.
@export var heal_duration: float = 3.0
## Идентификатор эффекта, который запускается при использовании (например, "explosion", "heal").
@export var effect_id: String = ""

# ═══════════════════ ТАКТИЧЕСКИЙ ПРЕДМЕТ (гранаты, мины) ═══════════════════
@export_category("Тактический предмет (если CONSUMABLE_TACTICAL)")
## Ресурс тактического снаряда (TacticalData): сцена, физика броска, параметры взрыва.
## Задаётся для гранат и мин. Бросок/установка — по ЛКМ, когда слот активен.
@export var tactical: TacticalDataScript

# ═══════════════════ ФЛАГИ ═══════════════════
@export_category("Флаги")
## Можно ли экипировать этот предмет (оружие, броня).
@export var is_equippable: bool = false
## Можно ли использовать предмет (расходники, медикаменты).
@export var is_usable: bool = false
## Можно ли выбросить предмет из инвентаря.
@export var is_droppable: bool = true
## Можно ли установить предмет в слот брони/импланта (если есть такая механика).
@export var is_installable: bool = false

## Показывает, экипирован ли предмет в настоящий момент в хотбаре.
## Используется для визуального отображения (серый оверлей в инвентаре).
var is_equipped: bool = false

## Удобное свойство: true, если max_stack_size > 1.
var stackable: bool:
	get: return max_stack_size > 1

## Возвращает размер предмета в ячейках с учётом поворота.
func get_size() -> Vector2i:
	if is_rotated:
		return Vector2i(height, width)
	return Vector2i(width, height)

## Пытается объединить стак с другим предметом (должны совпадать имена и быть стакуемыми).
## Возвращает true, если хотя бы одна единица была перенесена.
func try_merge(other: ItemData) -> bool:
	if not stackable or not other.stackable:
		return false
	if name != other.name:
		return false
	var space = max_stack_size - amount
	if space <= 0:
		return false
	var transfer = mini(space, other.amount)
	amount += transfer
	other.amount -= transfer
	return true

## Проверяет, является ли предмет оружием.
func is_weapon() -> bool:
	return weapon_type != WeaponType.NONE

## Проверяет, является ли оружие ближнего боя (ножи, мечи).
func is_melee() -> bool:
	return is_weapon() and attack_mode == AttackMode.MELEE

## Проверяет, является ли предмет расходником (любого типа).
func is_consumable() -> bool:
	return item_type == ItemType.CONSUMABLE

## Проверяет, является ли расходник тактическим (гранаты, мины).
func is_tactical() -> bool:
	return weapon_type == WeaponType.CONSUMABLE_TACTICAL

## Проверяет, является ли расходник медицинским (аптечки, бинты).
func is_medical() -> bool:
	return weapon_type == WeaponType.CONSUMABLE_MEDICAL

## Проверяет, восстанавливает ли предмет здоровье постепенно во времени.
func is_heal_over_time() -> bool:
	return heal_mode == HealMode.OVER_TIME

## Возвращает читаемую строку с эффектом лечения (для тултипа/логов).
func get_heal_text() -> String:
	if heal_amount <= 0:
		return ""
	if is_heal_over_time():
		return "Восстанавливает %d HP за %.0f с" % [heal_amount, heal_duration]
	return "Восстанавливает %d HP" % heal_amount

## Возвращает true, если оружие разряжено.
func is_ammo_empty() -> bool:
	return is_weapon() and ammo_current <= 0

## Возвращает true, если магазин оружия полон.
func is_ammo_full() -> bool:
	return is_weapon() and ammo_current >= ammo_max

## Перезаряжает оружие (магазин заполняется до максимума).
func reload() -> void:
	if is_weapon():
		ammo_current = ammo_max

## Формирует отображаемое имя с дополнительной информацией (патроны, количество стака).
func get_display_name() -> String:
	var display = name
	if is_weapon() and ammo_type != "":
		display += " [%d/%d]" % [ammo_current, ammo_max]
	if stackable and amount > 1:
		display += " x%d" % amount
	return display
