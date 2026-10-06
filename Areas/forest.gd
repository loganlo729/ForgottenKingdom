extends Node2D

func _ready():
	if Global.from_church:
		Global.from_church = false
		var player = get_tree().get_first_node_in_group("Player")
		var spawn = get_node_or_null("ChurchExit")
		if player and spawn:
			player.global_position = spawn.global_position
