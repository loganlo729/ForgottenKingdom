extends Area2D

@export var damage: int = 1

func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D):
	if body.name != "Player":
		return

	# Damage player
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)

	# Teleport to fixed coordinates
	body.global_position = Vector2(507, 564)

	# Reset movement
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
