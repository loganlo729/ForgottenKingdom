extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_player_health_changed(player_health):
	$HealthBar.value = player_health
	$HealthLabel.text = "Health: %s" % str(player_health)
