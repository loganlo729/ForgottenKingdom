extends Control

@onready var player = $"../../Player"
@onready var health_label = $HealthLabel
@onready var health_bar = $HealthBar


func _ready() -> void:
	player.health_changed.connect(_on_player_health_changed)

	_on_player_health_changed(player.player_health, player.max_health)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "Health: %s" % str(current_health)
	health_bar.max_value = max_health
	health_bar.value = current_health
