extends Node
class_name ScreenshotManager
## Утилита сохранения и загрузки изображений (скриншотов).

## Сохраняет изображение в JPG по указанному пути и возвращает его же.
static func save_image(floder_path: String, image_viewport: Image) -> Image:
	image_viewport.save_jpg(floder_path)
	return image_viewport

## Загружает изображение из файла.
static func load_image(file_path: String) -> Image:
	var image: Image = Image.load_from_file(file_path)
	return image
