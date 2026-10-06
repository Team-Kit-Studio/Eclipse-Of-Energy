extends Node2D
## Проверка: скин Криптозавра в Level_1 имеет flip_facing = true.

func _ready() -> void:
	var packed: PackedScene = load("res://project/scenes/levels/Level_1/Level_1.tscn")
	var lvl: Node = packed.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var krip: Node = lvl.get_node_or_null("1_floor/Entity/Kriptozavr")
	if krip == null:
		print("LEVEL_KRIP_CHECK=false (no node)")
		return
	var skin = krip._active_skin()
	var has_flip: bool = skin != null and skin.get("flip_facing")
	print("LEVEL_KRIP_CHECK=", has_flip, " skin_id=", (skin.skin_id if skin else "-"))