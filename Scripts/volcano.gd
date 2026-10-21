extends Node2D

func _ready() -> void:
	var marker = get_node_or_null(Global.spawn_name)
	if marker:
		$Player.global_position = marker.global_position
