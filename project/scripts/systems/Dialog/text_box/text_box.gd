extends MarginContainer
## Всплывающее текстовое облачко диалога. Печатает текст по буквам с паузами
## на пробелах и знаках препинания.

## Метка с текстом и таймер посимвольной печати.
@onready var label: Label = $MarginContainer/Label
@onready var timer: Timer = $LetterDisplayTimer

## Максимальная ширина облачка.
const MAX_WIGTH: int = 256

## Текст для отображения.
var text: String = ""
## Индекс текущей печатаемой буквы.
var letter_index: int = 0

## Задержка между обычными буквами (сек).
var leter_time = 0.03
## Задержка на пробеле (сек).
var space_time: float = 0.06
## Задержка на знаках препинания (сек).
var punctuation_time: float = 0.2


## Сигнал: текст полностью напечатан.
signal finished_displaying()

## Начинает посимвольный показ текста и позиционирует облачко над говорящим.
func display_text(text_to_display: String) -> void:
	text = text_to_display
	label.text = text_to_display
	
	await resized
	custom_minimum_size.x = min(size.x, MAX_WIGTH)
	
	if size.x > MAX_WIGTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		await resized # x resize
		await resized # y resize
		custom_minimum_size.y = size.y
		
	global_position.x -= size.x / 2
	global_position.y -= size.y + 24
	
	label.text = ""
	_display_letter()

## Печатает очередную букву и планирует следующую задержку.
func _display_letter() -> void:
	label.text += text[letter_index]
	
	letter_index += 1
	if letter_index >= text.length():
		finished_displaying.emit()
		return
		
	match text[letter_index]:
		"!", ".", ",", "?":
			timer.start(punctuation_time)
		" ":
			timer.start(space_time)
		_:
			timer.start(leter_time)


## По таймеру печатает следующую букву.
func _on_letter_display_timer_timeout() -> void:
	_display_letter()
