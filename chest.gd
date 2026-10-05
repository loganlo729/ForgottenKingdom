extends Area2D

var player_near := false
var opened := false

@onready var sprite = $AnimatedSprite2D
@onready var label = $Label

func _ready():
	label.hide()
	body_entered.connect(func(b): if b is CharacterBody2D: player_near = true)
	body_exited.connect(func(b): if b is CharacterBody2D: player_near = false)

func _on_body_entered(body):
	if body is CharacterBody2D:
		player_near = true

func _on_body_exited(body):
	if body is CharacterBody2D:
		player_near = false

func _input(event):
	if player_near and event.is_action_pressed("Interact"):
		if GameState.has_key:
			queue_free()
		else:
			label.show()
			await get_tree().create_timer(2.0).timeout
			label.hide()
