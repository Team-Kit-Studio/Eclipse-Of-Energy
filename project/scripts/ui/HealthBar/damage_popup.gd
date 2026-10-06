extends Node2D
## Всплывающее число урона над сущностью: поднимается вверх и затухает.
## Цвет — от белого (полное здоровье) к красному (близко к смерти).

## Метка с числом урона.
@onready var _label: Label = $Label

## Скорость подъёма числа (px/сек).
@export var rise_speed: float = 34.0
## Длительность показа (сек).
@export var lifetime: float = 0.7

## Настраивает и запускает число урона. Вызывать после add_child.
## amount   — величина урона (показывается целым);
## hp_ratio — остаток здоровья (0..1) для цвета: чем меньше, тем краснее.
func setup(amount: float, hp_ratio: float) -> void:
	if _label:
		_label.text = str(absi(int(round(amount))))
		_label.modulate = _color_for(hp_ratio)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(0, -rise_speed * lifetime), lifetime)
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.chain().tween_callback(queue_free)

## Цвет числа: белый при полном здоровье → красный при близком к нулю.
func _color_for(hp_ratio: float) -> Color:
	var danger: float = clampf(1.0 - hp_ratio, 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.15, 0.15), danger)
