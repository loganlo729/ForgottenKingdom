extends Area2D

var player_near := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("entered: ", body.name)
	if body is CharacterBody2D:
		player_near = true

func _on_body_exited(body):
	if body is CharacterBody2D:
		player_near = false

func _input(event):
	if event.is_action_pressed("Interact"):
		print("E pressed, near: ", player_near)
	if player_near and event.is_action_pressed("Interact"):
		get_tree().change_scene_to_file("res://Areas/forest.tscn")
