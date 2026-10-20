extends Area2D



@export_file("*.tscn") var next_scene: String = "res://Areas/forest.tscn"

var player_near := false


		
func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody2D:
		player_near = true

func _on_body_exited(body):
	if body is CharacterBody2D:
		player_near = false

func _input(event):
	if player_near and event.is_action_pressed("Interact"):
		Global.from_church = true
		SceneTransition.change_scene(next_scene)
		
