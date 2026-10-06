extends Control
## Диалог подтверждения действия над сохранением (перезапись/удаление/загрузка).

signal confirm_apply(_mode: String)

@onready var LabelText: Label = $Panel/HBoxContainer/VBoxContainer/Label
var mode: String

func set_text(text: String) -> void:
	LabelText.text = ""
	LabelText.text = text

func _on_apply_pressed() -> void:
	self.emit_signal("confirm_apply", mode)
	hided()



func _on_cancel_pressed() -> void:
	hided()

func confirm_show(_mode: String) -> void:
	mode = _mode
	self.show()
	self.scale = Vector2(0.3, 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.15)

func hided() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.15)
	await tween.finished
	self.hide()
