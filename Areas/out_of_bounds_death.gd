
extends Area2D

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or triggered:
		return

	triggered = true

	# Instantly kill the player.
	body.player_health = 0
	body.health_changed.emit(0, body.max_health)

	# Restart the current scene.
	get_tree().call_deferred("reload_current_scene")
