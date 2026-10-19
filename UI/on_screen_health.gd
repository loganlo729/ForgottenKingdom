extends Control

var player

@onready var health_label = $HealthLabel
@onready var health_bar = $HealthBar

func _ready() -> void:
	# Safely find the player node using its group
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.health_changed.connect(_on_player_health_changed)
		# Initialize values manually on start
		_on_player_health_changed(player.current_health, player.max_health)
	else:
		push_error("Health UI: Player node not found in 'player' group!")

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "Health: " + str(current_health)
	health_bar.max_value = max_health
	health_bar.value = current_health
