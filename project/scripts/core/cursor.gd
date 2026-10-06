extends CanvasLayer
## Автозагрузка курсора с двумя режимами:
## - обычный указатель (mouse_cursor.png)
## - перекрестие оружия (mouse_weapon_sprite.png), когда активен слот с оружием.

## Спрайт обычного указателя (mouse_cursor.png).
@onready var sprite: Sprite2D = $Sprite
## Спрайт перекрестия оружия (mouse_weapon_sprite.png).
@onready var weapon_sprite: Sprite2D = $WeaponSprite

## true — активен режим оружия (перекрестие), false — обычный указатель.
var is_weapon_mode: bool = false

## Инициализация: скрываем системный курсор и показываем обычный указатель.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Курсор виден всегда. По умолчанию — обычный указатель.
	sprite.visible = true
	weapon_sprite.visible = false

## Каждый кадр позиционируем оба спрайта в координатах мыши.
func _process(_delta: float) -> void:
	var pos: Vector2 = get_viewport().get_mouse_position()
	sprite.position = pos
	weapon_sprite.position = pos

## Переключает режим курсора: weapon=true — перекрестие оружия, false — обычный указатель.
func set_weapon_mode(weapon: bool) -> void:
	is_weapon_mode = weapon
	sprite.visible = not weapon
	weapon_sprite.visible = weapon
	
