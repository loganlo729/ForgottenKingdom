extends Area2D

var player_near := false
var opened := false

@onready var sprite = $AnimatedSprite2D
@onready var key_sprite = $KeySprite

func _ready():
	key_sprite.hide()
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
	# Cast to UI
	# Get the first node in the "player" group and cast it to Player
	
	
	if event.is_action_pressed("Interact"):
		print("E pressed, near: ", player_near, " opened: ", opened)
	if player_near and not opened and event.is_action_pressed("Interact"):
		opened = true
		GameState.has_key = true
		print("key given")
		print("playing open")
		sprite.play("default")
		await sprite.animation_finished
		key_sprite.show()
		await get_tree().create_timer(2.0).timeout
		key_sprite.hide()
