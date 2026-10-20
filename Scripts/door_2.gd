extends Area2D

@export_file("*.tscn") var next_scene: String = "res://Areas/caves.tscn"
@export var spawn_name: String = ""

@onready var label = $Label
var player_near := false
var showing := false

func _ready() -> void:
	label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_near = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_near = false

func _input(event) -> void:
	if player_near and event.is_action_pressed("Interact"):
		if GameState.has_key:
			Global.spawn_name = spawn_name
			SceneTransition.change_scene(next_scene)
		elif not showing:
			showing = true
			label.text = "Key needed"
			label.show()
			await get_tree().create_timer(2.0).timeout
			label.hide()
			showing = false
