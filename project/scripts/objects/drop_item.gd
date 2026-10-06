@tool
extends Area2D
class_name DroppedItem
## Выпавший в мире предмет: показывает иконку и количество, подсвечивает подсказку F.

## Данные предмета (ItemData).
@export var data: ItemData

## Спрайт предмета, метка количества и подсказка взаимодействия.
@onready var sprite: Sprite2D = $Sprite2D
@onready var amount_label: Label = $Amount
@onready var hint_f: CanvasItem = $HintF

## Инициализирует визуал; в редакторе сразу показывает текстуру предмета.
func _ready() -> void:
	if not Engine.is_editor_hint():
		sprite.texture = data.texture
	input_pickable = true
	if hint_f:
		hint_f.visible = false
	update_visual()

## В редакторе обновляет текстуру предмета при её изменении.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		sprite.texture = data.texture

## Обновляет текстуру и метку количества.
func update_visual() -> void:
	if data and sprite:
		sprite.texture = data.texture
	if amount_label:
		if data and data.max_stack_size > 1 and data.amount > 1:
			amount_label.text = str(data.amount)
			amount_label.visible = true
		else:
			amount_label.visible = false

## Подсвечивает предмет при наведении (показывает подсказку F).
func set_highlight(active: bool) -> void:
	if hint_f:
		hint_f.visible = active
