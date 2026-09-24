extends Area2D

@export_file("*.tscn") var next_scene: String = "res://Areas/forest.tscn"

func _ready() -> void:
	print("ForestDrop ready")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("touched by: ", body.name, " groups: ", body.get_groups())
	if body.is_in_group("Player"):
		get_tree().change_scene_to_file.call_deferred("res://Areas/forest.tscn")
