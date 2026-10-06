class_name PrivateDefaultSettingsData
## Значения настроек по умолчанию (управление, видео, аудио) для SettingsLoader.

## Словарь настроек по умолчанию, сгруппированный по секциям.
const SETTINGS: Dictionary = {
	"Control": {
		"up": "W",
		"left": "A",
		"down": "S",
		"right": "D"
	},

	"Video": {
		"fullscreen": DisplayServer.WINDOW_MODE_WINDOWED,
		"borderless": false,
		"vsync": DisplayServer.VSYNC_DISABLED
	},

	"Audio": {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0
	}	
}
