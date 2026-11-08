extends Node2D

func _ready():
	if Global.spawn_name != "":
		var player = get_tree().get_first_node_in_group("Player")
		var spawn = get_node_or_null(Global.spawn_name)
		if player and spawn:
			player.global_position = spawn.global_position
		Global.spawn_name = ""
