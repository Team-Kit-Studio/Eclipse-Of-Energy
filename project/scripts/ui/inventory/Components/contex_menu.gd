extends CanvasLayer
class_name ItemContextMenu

## Сигнал выбора действия
signal action_selected(action: String)
## Сигнал закрытия меню (для уведомления хотбара/инвентаря)
signal menu_closed

## Ссылки на узлы
@onready var menu_panel: Panel = $MenuPanel
@onready var buttons_container: VBoxContainer = $MenuPanel/VBoxContainer
@onready var button_equip: Button = $MenuPanel/VBoxContainer/Button_Equip
@onready var button_use: Button = $MenuPanel/VBoxContainer/Button_Use
@onready var button_reload: Button = $MenuPanel/VBoxContainer/Button_Reload
@onready var button_description: Button = $MenuPanel/VBoxContainer/Button_Description
@onready var button_drop: Button = $MenuPanel/VBoxContainer/Button_Drop

## Текущий предмет и тип слота
var current_item: ItemData = null
var current_slot_type: int = 0
## True, если предмет в данный момент экипирован в хотбар (показываем "Снять")
var current_item_is_equipped: bool = false
## Разрешено ли экипировать этот предмет (только из инвентаря игрока)
var allow_equip: bool = true

var current_tween: Tween = null

const ANIMATION_DURATION: float = 0.15
const START_SCALE: float = 0.4
const END_SCALE: float = 1.0
const PANEL_PADDING_X: float = 16.0
const PANEL_PADDING_Y: float = 16.0

func _ready() -> void:
	menu_panel.visible = false
	menu_panel.scale = Vector2(START_SCALE, START_SCALE)
	
	if button_equip: button_equip.visible = false
	if button_use: button_use.visible = false
	if button_reload: button_reload.visible = false
	
	if button_equip: button_equip.pressed.connect(_on_equip_pressed)
	if button_use: button_use.pressed.connect(_on_use_pressed)
	if button_reload: button_reload.pressed.connect(_on_reload_pressed)
	if button_description: button_description.pressed.connect(_on_description_pressed)
	if button_drop: button_drop.pressed.connect(_on_drop_pressed)

## Настройка меню из инвентаря
## is_equipped: true, если предмет уже в хотбаре — тогда показываем "Снять"
func setup(item: ItemData, slot_type: int, position: Vector2, is_equipped: bool = false, p_allow_equip: bool = true) -> void:
	current_item = item
	current_slot_type = slot_type
	current_item_is_equipped = is_equipped
	allow_equip = p_allow_equip
	_configure_buttons()
	_position_menu(position)
	_show_with_animation()

## Настройка видимости кнопок
func _configure_buttons() -> void:
	if not current_item:
		return
	
	# 1. Кнопка ЭКИПИРОВАТЬ/СНЯТЬ
	if button_equip:
		if not allow_equip:
			# Предмет не в инвентаре игрока — экипировать нельзя
			button_equip.visible = false
		elif current_item_is_equipped:
			# Предмет уже экипирован в хотбар — предлагаем снять
			button_equip.text = "Снять"
			button_equip.visible = true
		else:
			# Иначе показываем "Экипировать" для подходящих предметов
			# (оружие, расходники, медикаменты и предметы 1x1 для свободных слотов)
			var can_equip = (current_item.is_weapon() or 
							current_item.is_tactical() or 
							current_item.is_medical() or
							current_item.is_installable or 
							current_item.is_equippable or
							current_item.get_size() == Vector2i(1, 1))
			if can_equip:
				button_equip.text = "Экипировать"
				button_equip.visible = true
			else:
				button_equip.visible = false

	# 2. Кнопка ИСПОЛЬЗОВАТЬ
	if button_use:
		var can_use = (current_item.is_medical() or 
					  (current_item.is_usable and not current_item.is_tactical()))
		if can_use:
			button_use.visible = true
		else:
			button_use.visible = false
	
	# 3. Кнопка перезарядки (только для оружия)
	if button_reload:
		if current_item.is_weapon():
			if current_item.is_ammo_empty():
				button_reload.text = "Зарядить"
			elif current_item.is_ammo_full():
				button_reload.text = "Разрядить"
			else:
				button_reload.text = "Зарядить/Разрядить"
			button_reload.visible = true
		else:
			button_reload.visible = false
	
	# 4. Кнопка описания (всегда видна)
	if button_description: button_description.visible = true
	
	# 5. Кнопка выбрасывания (если разрешено)
	if button_drop: button_drop.visible = current_item.is_droppable
	
	_update_panel_size()

## Пересчёт размера панели на основе видимых кнопок
func _update_panel_size() -> void:
	if not buttons_container or not menu_panel:
		return
	
	await get_tree().process_frame
	
	var content_size: Vector2 = buttons_container.get_combined_minimum_size()
	menu_panel.custom_minimum_size = content_size + Vector2(PANEL_PADDING_X, PANEL_PADDING_Y)
	menu_panel.size = menu_panel.custom_minimum_size

## Позиционирование меню
func _position_menu(position: Vector2) -> void:
	if not menu_panel: return
	menu_panel.global_position = position + Vector2(0, 32)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var menu_size = menu_panel.size
	
	if menu_panel.global_position.x + menu_size.x > viewport_size.x:
		menu_panel.global_position.x = viewport_size.x - menu_size.x - 10
	if menu_panel.global_position.y + menu_size.y > viewport_size.y:
		menu_panel.global_position.y = position.y - menu_size.y - 10

## Показать меню с анимацией масштабирования
func _show_with_animation() -> void:
	if current_tween: current_tween.kill()
	menu_panel.visible = true
	menu_panel.scale = Vector2(START_SCALE, START_SCALE)
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.tween_property(menu_panel, "scale", Vector2(END_SCALE, END_SCALE), ANIMATION_DURATION)
	current_tween.tween_callback(_on_show_animation_finished)

## Скрыть меню с анимацией
func _hide_with_animation() -> void:
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.tween_property(menu_panel, "scale", Vector2(START_SCALE, START_SCALE), ANIMATION_DURATION)
	current_tween.tween_callback(_on_hide_animation_finished)

func _on_show_animation_finished() -> void: current_tween = null

func _on_hide_animation_finished() -> void:
	current_tween = null
	menu_panel.visible = false
	menu_closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_hide_with_animation()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		if menu_panel and not menu_panel.get_global_rect().has_point(mouse_pos):
			_hide_with_animation()

func _on_equip_pressed() -> void:
	if current_item:
		if current_item_is_equipped:
			action_selected.emit("unequip")
		else:
			action_selected.emit("equip")
	_hide_with_animation()

func _on_use_pressed() -> void:
	if current_item: action_selected.emit("use")
	_hide_with_animation()

func _on_reload_pressed() -> void:
	if current_item:
		if current_item.is_ammo_empty(): action_selected.emit("reload")
		else: action_selected.emit("unload")
	_hide_with_animation()

func _on_description_pressed() -> void:
	action_selected.emit("description")
	# Меню не закрываем, чтобы можно было прочитать тултип

func _on_drop_pressed() -> void:
	action_selected.emit("drop")
	_hide_with_animation()

## Публичный метод для закрытия меню (вызывается из хотбара/инвентаря)
func close_menu() -> void:
	_hide_with_animation()
