extends Area2D

@export_file("*.tscn") var next_scene: String
@export var spawn_name: String = ""

var player: Node2D
var player_inside := false
var opening := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$AnimatedSprite2D.animation = "DoorToVillage"
	$AnimatedSprite2D.frame = 0
	$AnimatedSprite2D.stop()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player = body
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and not opening and event.is_action_pressed("Interact"):
		opening = true
		player.set_physics_process(false)
		$AnimatedSprite2D.play("DoorToVillage")
		await $AnimatedSprite2D.animation_finished
		Global.spawn_name = spawn_name
		SceneTransition.change_scene(next_scene)
