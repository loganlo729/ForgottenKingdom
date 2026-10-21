extends Area2D

@export_file("*.tscn") var next_scene: String
@export var spawn_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Global.spawn_name = spawn_name
		SceneTransition.change_scene(next_scene)
