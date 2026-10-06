extends CanvasLayer
class_name ItemTooltip
## Всплывающая подсказка предмета: имя, описание и эффекты (урон/лечение и т.п.).

## Узлы панели подсказки.
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var name_label: Label = $TooltipPanel/VBoxContainer/NameLabel
@onready var description_label: Label = $TooltipPanel/VBoxContainer/DescriptionLabel

## Текущий твин анимации показа.
var current_tween: Tween = null
## Длительность анимации появления/скрытия.
const ANIMATION_DURATION: float = 0.15
## Начальный и конечный масштаб панели при появлении.
const START_SCALE: float = 0.8
const END_SCALE: float = 1.0
## Отступ подсказки от меню.
const OFFSET: float = 10.0

## При старте прячет подсказку.
func _ready() -> void:
	tooltip_panel.visible = false

## Показывает подсказку для предмета рядом с якорем (меню).
func show_tooltip(item: ItemData, anchor_position: Vector2, anchor_size: Vector2 = Vector2.ZERO) -> void:
	if not item:
		hide_tooltip()
		return
	
	name_label.text = item.get_display_name()
	description_label.text = item.description
	
	if item.is_weapon():
		description_label.text += "\n\n[Урон: %d] [Магазин: %d/%d]" % [item.damage, item.ammo_current, item.ammo_max]
	elif item.is_consumable() and item.heal_amount > 0:
		description_label.text += "\n\n[%s]" % item.get_heal_text()
	
	tooltip_panel.visible = true
	tooltip_panel.scale = Vector2(START_SCALE, START_SCALE)
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.tween_property(tooltip_panel, "scale", Vector2(END_SCALE, END_SCALE), ANIMATION_DURATION)
	current_tween.tween_callback(func(): current_tween = null)
	
	_position_tooltip(anchor_position, anchor_size)

## Прячет подсказку.
func hide_tooltip() -> void:
	tooltip_panel.visible = false
	if current_tween:
		current_tween.kill()
		current_tween = null

## Позиционирует тултип рядом с якорем (контекстным меню).
func _position_tooltip(anchor_position: Vector2, anchor_size: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = tooltip_panel.size
	
	# По умолчанию показываем справа от меню
	var target_pos: Vector2 = anchor_position + Vector2(anchor_size.x + OFFSET, 0)
	
	# Если не хватает места справа — показываем слева
	if target_pos.x + panel_size.x > viewport_size.x:
		target_pos.x = anchor_position.x - panel_size.x - OFFSET
	
	# Проверка нижней границы
	if target_pos.y + panel_size.y > viewport_size.y:
		target_pos.y = viewport_size.y - panel_size.y - OFFSET
	
	# Проверка верхней границы
	if target_pos.y < 0:
		target_pos.y = OFFSET
	
	tooltip_panel.global_position = target_pos
