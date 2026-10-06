extends Node2D

@onready var audio_music: AudioStreamPlayer2D = $AudioMusic
@onready var audio_sfx: AudioStreamPlayer2D = $AudioSFX
@onready var player: CharacterBody2D = $"1_floor/Entity/Player"
@onready var animation_player: AnimationPlayer = $"Kut-Scene/AnimationPlayer"
@onready var cutscene_manager: Node = CutsceneManager

var cut_scene: bool = false

func _ready() -> void:
	SavesManager.load_from_data.connect(load_from_data)
	SavesManager.data_update.connect(self_objects_saves)
	Play_Music("res://project/assets/sounds/music/Trip Land.mp3")
	#animation_player.play("Kut-Scene")
	#start_cutscene()
	
func start_cutscene() -> void:
	# Пример запуска катсцены (можно вызвать из любого места)
	cutscene_manager.play_cutscene(preload("res://project/data/Resources/Cut-Scenes/Cutscene1.tres"))
	

#реализует систему сохранения состояния сцены
func self_objects_saves() -> void:
	var temp_data: Dictionary = {} 
	var temp_metadata: Dictionary = {}

	# Сохраняем путь сцены уровня
	temp_data["level_scene"] = self.scene_file_path
	
	# Сохраняем данные игрока (вызываем его метод data())
	if player:
		temp_data["player"] = player.get_save_data()
	
	temp_metadata["name"] = self.name
	temp_metadata["last_modified_time"] = {
		"date": Time.get_date_dict_from_system(),
		"time": Time.get_time_dict_from_system()
	}

	SavesManager.emit_signal("data_updated", temp_data, temp_metadata)

	#for enemy: Node in $Objects/Enemy.get_children():
	#	if enemy.data(): temp["data"]["enemy"].append(enemy.data())
	#	
	#for allies: Node in $Objects/Allies.get_children():
	#	if allies.data(): temp["data"]["allies"].append(allies.data())
	#	
	#for items: Node in $Items.get_children():
	#	if items.data(): temp["data"]["items"].append(items.data())
		




#загружает состояние сцены из сохраненных данных.
func load_from_data(data: Dictionary) -> void:
	# 1. Мы НЕ удаляем игрока. Мы обновляем того, кто уже стоит на уровне.
	
	if data.has("player"):
		# Проверяем, жив ли узел игрока
		if is_instance_valid(player):
			player.load_data(data["player"])
		else:
			push_error("Игрок не найден на сцене при загрузке!")
	
	# Если нужно загружать врагов или предметы, которые СПАВНЯТСЯ (которых не было в редакторе),
	# то их старые версии надо удалить, а новые создать.
	# Но Игрока трогать нельзя.


func delete_node() -> void:
#	for enemy: Node in $Objects/Enemy.get_children():
#		$Objects/Enemy.remove_child(enemy)
#		enemy.queue_free()
#
#	for allies: Node in $Objects/Allies.get_children():
#		$Objects/Allies.remove_child(allies)
#		allies.queue_free()
#
#
#	for items: Node in $Items.get_children():
#		$Items.remove_child(items)
#		items.queue_free()

	var player_node: CharacterBody2D = $Player
	player_node.remove_child(player_node)
	player_node.queue_free()

#загружает и восстанавливает состояние игрока из сохраненных данных
func load_player(player_data: Dictionary) -> void:
	var player_scene = load(player_data.file_name)
	if not player_scene:
		push_error("Не удалось загрузить сцену игрока: " + str(player_data.file_name))
		return
	
	var inst_player = player_scene.instantiate()
	
	# Добавляем в правильное место
	var entity_parent = get_node_or_null("1_floor/Entity")
	if entity_parent:
		entity_parent.add_child(inst_player)
	else:
		add_child(inst_player)
	
	inst_player.name = "Player"
	inst_player.call_deferred("load_data", player_data)


func Play_Music(path: String) -> void:
	var stream = load(path)
	if audio_music.playing:
		return
	
	if stream is AudioStream or audio_music.finished:
		audio_music.stream = stream
		audio_music.play()
		
	else:
		push_error("Ошибка загрузки музыки")
