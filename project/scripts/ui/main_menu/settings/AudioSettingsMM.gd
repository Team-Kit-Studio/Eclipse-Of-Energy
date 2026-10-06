extends Control
## Настройки аудио в главном меню (громкости master/sfx/music).

@onready var music: HSlider = %Music
@onready var sfx_value: HSlider = %Sound_FX
@onready var audio_num_music_text: Label = $PanelContainer/VBoxContainer/HBoxContainer/VBoxContainer3/Audio_Num_LBL
@onready var audio_num_sfx_text: Label = $PanelContainer/VBoxContainer/HBoxContainer/VBoxContainer3/Audio_Num_LBL2

const MAX_BOOST: float = 2.0 # Коэффициент усиления (2.0 = +6dB, 3.0 = +9.5dB)

var bus_index_music: int = 2
var bus_index_sfx: int = 1

func _ready() -> void:
	get_bus_index()
	set_bus_index()

# настраивает громкость аудио-шинов (audio buses)
func set_bus_index() -> void:
	music.value = SettingsLoader.config.get_value("Audio", "music_volume", 0.5)
	# Умножаем на MAX_BOOST
	AudioServer.set_bus_volume_db(bus_index_music, linear_to_db(music.value * MAX_BOOST))
	
	sfx_value.value = SettingsLoader.config.get_value("Audio", "sfx_volume", 0.5)
	# Умножаем на MAX_BOOST
	AudioServer.set_bus_volume_db(bus_index_sfx, linear_to_db(sfx_value.value * MAX_BOOST))

# получение индекса басов
func get_bus_index() -> void:
	bus_index_music = AudioServer.get_bus_index(StringName("music"))
	bus_index_sfx = AudioServer.get_bus_index(StringName("sfx_volume"))

# синхронизируем гроскость музыки и ползунок
func set_audio_num_text() -> void:
	audio_num_music_text.text = str(music.value * 100)
	audio_num_sfx_text.text = str(sfx_value.value * 100)

# при изменении громкости, меняем саму громкость
func _on_music_value_changed(value: float) -> void:
	set_volume(bus_index_music, value)

# точно такая же функция 
func _on_sound_fx_value_changed(value: float) -> void:
	set_volume(bus_index_sfx, value)

# вводим новое значение громкости
func set_volume(idx: int, value: float) -> void:
	# Умножаем на MAX_BOOST
	AudioServer.set_bus_volume_db(idx, linear_to_db(value * MAX_BOOST))
	
	if idx == bus_index_music:
		SettingsLoader.config.set_value("Audio", "music_volume", value)
	elif idx == bus_index_sfx:
		SettingsLoader.config.set_value("Audio", "sfx_volume", value)
		
	set_audio_num_text()
	SettingsLoader.save_data()
