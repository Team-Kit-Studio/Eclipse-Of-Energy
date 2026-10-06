extends Control
## Панель выбора ответа в диалоге. Выезжает справа снизу, кнопки строятся по словарю опций.

## Сигнал: выбран вариант ответа (текст опции).
signal choice_selected(option: String)

## Панель и контейнер кнопок.
@onready var panel: Panel = $CanvasLayer/Panel
@onready var button_container: VBoxContainer = $CanvasLayer/Panel/ButtonContainer

## Максимальная ширина панели.
const MAX_WIDTH: int = 400
## Максимальная высота панели.
const MAX_HEIGHT: int = 400
## Внутренние отступы панели.
const PADDING: int = 20
## Отступ от правого края экрана.
const SIDE_MARGIN: int = 20
## Отступ от нижнего края экрана.
const BOTTOM_MARGIN: int = 20
## Сцена кнопки варианта.
const BUTTON_SCENE = preload("res://project/scenes/ui/Systems/Dialog/Text_Box/ChoiceButton.tscn")

## Строит кнопки по словарю опций и подгоняет размер панели; показывает её.
func set_options(options: Dictionary) -> void:
	for child in button_container.get_children():
		child.queue_free()
	
	panel.custom_minimum_size.x = MAX_WIDTH
	panel.size.x = MAX_WIDTH
	
	for option_text in options.keys():
		var btn = BUTTON_SCENE.instantiate()
		btn.text = option_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.pressed.connect(_on_button_pressed.bind(option_text))
		button_container.add_child(btn)
	
	# Ждём несколько кадров, чтобы контейнер точно пересчитал размеры
	await get_tree().process_frame
	await get_tree().process_frame
	
	var content_height = button_container.get_combined_minimum_size().y
	var panel_height = min(content_height + PADDING * 2, MAX_HEIGHT)  # ограничиваем высоту
	
	panel.custom_minimum_size.y = panel_height
	panel.size.y = panel_height
	button_container.position = Vector2(PADDING, PADDING)
	button_container.size = Vector2(MAX_WIDTH - PADDING * 2, panel_height - PADDING * 2)
	
	show_slide_in()

func show_slide_in() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_width = panel.size.x
	var panel_height = panel.size.y
	
	var target_x = viewport_size.x - panel_width - SIDE_MARGIN
	var target_y = viewport_size.y - panel_height - BOTTOM_MARGIN

	# Сразу задаём позицию за правым краем экрана
	panel.position = Vector2(viewport_size.x, target_y)
	panel.visible = true
	show()

	# Ждём один кадр, чтобы позиция точно применилась
	await get_tree().process_frame

	# Плавный выезд
	var tween = create_tween()
	tween.tween_property(panel, "position:x", target_x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	await tween.finished

## Анимирует уход панели за правый край и прячет её.
func hide_slide_out() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var tween = create_tween()
	tween.tween_property(panel, "position:x", viewport_size.x, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	await tween.finished
	hide()

## Обработчик нажатия кнопки: шлёт сигнал выбора и прячет панель.
func _on_button_pressed(option: String) -> void:
	choice_selected.emit(option)
	hide_slide_out()
