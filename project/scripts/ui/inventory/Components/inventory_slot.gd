class_name InventorySlot
extends ColorRect
## Слот инвентаря/хотбара.
## В сетке инвентаря игнорирует мышь (события уходят предметам и сетке).
## В хотбаре (clickable = true) принимает клики и эмитит сигналы.

enum SlotState { DEFAULT, VALID, INVALID, SWAP, SELECTED }

const STATE_COLORS = {
	SlotState.DEFAULT:  Color(1.0, 1.0, 1.0, 1.0),
	SlotState.VALID:    Color(0.2, 0.6, 0.2, 1.0),
	SlotState.INVALID:  Color(0.6, 0.2, 0.2, 1.0),
	SlotState.SWAP:     Color(0.6, 0.6, 0.2, 1.0),
	SlotState.SELECTED: Color(1.0, 1.0, 1.0, 1.0)
}

## Клик ЛКМ по слоту (только для clickable-слотов хотбара)
signal slot_clicked
## Клик ПКМ по слоту (только для clickable-слотов хотбара)
signal slot_right_clicked

## Принимает ли слот клики мыши (true — для слотов хотбара)
var clickable: bool = false:
	set(value):
		clickable = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

@onready var background: ColorRect = $ColorRect
@onready var icon: TextureRect = $ColorRect/Icon
@onready var amount_label: Label = $AmountLabel
@onready var border: Panel = $Border

func _init() -> void:
	# Слоты ИГНОРИРУЮТ мышь, чтобы события проходили к предметам
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_state(SlotState.DEFAULT)
	clear_item()
	if border:
		border.visible = false
	# mouse_filter соответствует clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	# ВАЖНО: дочерние контролы (фон, иконка, рамка, количество) не должны
	# перехватывать клики — иначе _gui_input корневого слота не сработает.
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Обработка кликов по слоту (используется слотами хотбара)
func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit()

func set_state(state: SlotState) -> void:
	if state == SlotState.SELECTED:
		if border:
			border.visible = true
		if background:
			background.color = Color(0.5, 0.5, 0.5, 0.3)
	else:
		if border:
			border.visible = false
		if background and state in STATE_COLORS:
			background.color = STATE_COLORS[state]

func set_item_icon(tex: Texture2D) -> void:
	if icon:
		icon.texture = tex
		icon.visible = true

func set_amount(text: String) -> void:
	if amount_label:
		amount_label.text = text
		amount_label.visible = (text != "" and text != "1")

func clear_amount() -> void:
	if amount_label:
		amount_label.text = ""
		amount_label.visible = false

func clear_item() -> void:
	if icon:
		icon.texture = null
		icon.visible = false
	if amount_label:
		amount_label.text = ""
		amount_label.visible = false
