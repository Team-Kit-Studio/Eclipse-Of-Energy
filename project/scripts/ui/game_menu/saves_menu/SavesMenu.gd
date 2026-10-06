extends Control
## Меню сохранений: список слотов, создание/загрузка/удаление, обновление списка.

signal update_current_node(node: Node)
signal create_new_save(_name: String)

@onready var saveMenu: Control = $NewSave
@onready var confirmMenu: Control = $Confirm
@onready var loadButton: Button = $Panel/Load
@onready var deleteButton: Button = $Panel/Delete
@onready var saveButton: Button = $Panel/NewSaveButton
@onready var saveList: VBoxContainer = $Panel/VBoxContainer/MarginContainer/ScrollContainer/SaveListH/SavelistV
@onready var saveImage: TextureRect = $Panel/SaveInfo/SaveImage
@onready var gameMenu: Node = get_parent().get_owner()

var current_save: Node

func _ready() -> void:
	self.update_current_node.connect(func(node: Node) -> void: current_save = node)
	self.create_new_save.connect(create_new_save_handler)
	self.hidden.connect(hidden_handler)
	confirmMenu.confirm_apply.connect(confirm_apply_handler)
	
	save_create_ready()

func create_new_save_handler(save_name: String) -> void:
	if not saveList.get_children().size() >= Main.SAVES_LIMIT:
		var _name: String = get_unique_save_name(save_name)
		SavesManager.emit_signal("save", _name)
		_create_new_save(_name)

	else:
		return

func hidden_handler() -> void:
	if saveMenu.visible:
		saveMenu.hide()
	if confirmMenu.visible:
		confirmMenu.hide()

func confirm_apply_handler(_mode: String) -> void:
	match _mode:
		"Delete":
			delete()
			update_saves_config()
			current_save = null

		"Overwrite": 
			overwrite()
			update_saves_config()
			

		"Load": 
			_load()
			update_saves_config()
			current_save = null


# Save Menu
func _on_new_save_button_pressed() -> void:
	match saveButton.text:
		"Создать":
			save_menu_show()

		"Перезаписать":
			confirm_overwtite()


func confirm_overwtite() -> void:
	confirmMenu.set_text("Вы уверены, что хотите перезаписать \nсохранение? \nЭто действие нельзя отменить!")
	confirmMenu.confirm_show("Overwrite")
	saveMenu.hide()

func save_menu_show() -> void:
	if not saveMenu.visible:
		saveMenu.animate_and_show()
		confirmMenu.hide()
	else:
		saveMenu.animate_and_hide()

func _on_cancel_pressed() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.1), 0.15) 
	tween.tween_property(self, "position:x", -240, 0.2)
	await tween.finished
	self.hide()

# Save Slot 
func enable_buttons() -> void:
	if current_save:
		await get_tree().create_timer(0.13).timeout
		set_text_save_button("Перезаписать")
		deleteButton.disabled = false
		loadButton.disabled = false

func disable_buttons() -> void:
	if current_save:
		await get_tree().create_timer(0.13).timeout
		set_text_save_button("Создать")
		deleteButton.disabled = true
		loadButton.disabled = true

func set_text_save_button(_text: String) -> void:
	saveButton.text = _text

func create_save_from_directory(names: PackedStringArray) -> void:
	for save_name: String in names:
		if FileAccess.file_exists(PathManager.build_path(Main.SAVE_FOLDER_PATH + save_name, "/data", ".sav")):
			var inst_slot: Node = base_creator_save(save_name)
			var path: String = PathManager.build_path(Main.SAVE_FOLDER_PATH + save_name, "/image", ".jpg")
			inst_slot.update_time_json()
			if FileAccess.file_exists(path): inst_slot.image_save = ImageTexture.create_from_image(ScreenshotManager.load_image(path))
			update_saves_config()

func _create_new_save(_name: String) -> void:
	var inst_slot: Node = base_creator_save(_name)
	inst_slot.image_save = await screen_shot(_name)
	inst_slot.update_time_ready()
	update_saves_config()

func base_creator_save(_name: String) -> Node:
	var inst_slot: Node = load("res://project/scenes/ui/game_menu/saves_menu/save_slot.tscn").instantiate()
	inst_slot.name = _name
	inst_slot.custom_minimum_size = Vector2i(375, 70)
	saveList.add_child(inst_slot)
	
	return inst_slot

func update_saves_config() -> void:
	var data: Array[Dictionary] = []
	var config: ConfigFile = ConfigUtil.load_config(Main.SAVE_LIST_CONFIG_PATH)
	var children: Array[Node] = saveList.get_children()
	if not config:
		ConfigFile.new().save(Main.SAVE_LIST_CONFIG_PATH)
		update_saves_config()
	
	for child in children:
		data.append({
			"name": child.name,
		})

	SavesManager.save_list_saves_config(data)

func save_create_ready() -> void:
	var config: ConfigFile = ConfigUtil.load_config(Main.SAVE_LIST_CONFIG_PATH)
	var names: PackedStringArray = PackedStringArray()
	if not config:
		return
		
	if not config.get_sections().size() > 0:
		return
	for section_key: String in config.get_sections():
		names.append(config.get_value(section_key, config.get_section_keys(section_key)[0]))

	create_save_from_directory(names)


# Create unique save name
func get_unique_save_name(base_name: String) -> String:
	var _name: String = base_name
	var counter: int = 1
	while find_save(_name) != null:
		_name = base_name + "-(" + str(counter) + ")"
		counter += 1
	return _name

func find_save(_name: String) -> Node:
	for node: Node in saveList.get_children():
		if node.name == _name:
			return node
	return null

# Delete save visual
func _on_delete_pressed() -> void:
	confirmMenu.set_text("Вы уверены, что хотите удалить \nсохранение? \nЭто действие нельзя отменить!")
	confirmMenu.confirm_show("Delete")
	saveMenu.hide()

func delete_visual_save() -> void:
	if current_save:
		saveList.remove_child(current_save)
		current_save.call_deferred("queue_free")
		print(saveList.get_children())
	else:
		return

func delete() -> void:
	SavesManager.emit_signal("delete", current_save.name)
	delete_visual_save()

# Overwrite save
func overwrite() -> void:
	current_save.update_time_ready()
	screen_shot(current_save.name)
	SavesManager.emit_signal("save", current_save.name)
	current_save.image_save = await screen_shot(current_save.name)

# Load save
func _load() -> void:
	gameMenu.hide_canvas()
	SavesManager.emit_signal("load", current_save.name)
	saveList.move_child(current_save, 0)
	reset_scroll()
	
func _on_load_pressed() -> void:
	confirmMenu.set_text("Вы уверены, что хотите загрузить \nсохранение? \nВсе не сохраненные данные будут потеряны!")
	confirmMenu.confirm_show("Load")

func screen_shot(folder_name: String) -> Texture2D:
	gameMenu.hide_canvas()
	await RenderingServer.frame_post_draw
	var image: Image = ScreenshotManager.save_image(PathManager.build_path(Main.SAVE_FOLDER_PATH + folder_name, "/image", ".jpg"), get_viewport().get_texture().get_image())
	gameMenu.show_canvas()

	return ImageTexture.create_from_image(image)

func set_save_image(texture: Texture2D) -> void:
	saveImage.texture = texture

func reset_scroll() -> void:
	$Panel/VBoxContainer/MarginContainer/ScrollContainer.set_deferred("scroll_vertical", 0)
