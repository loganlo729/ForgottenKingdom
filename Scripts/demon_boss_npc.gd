
extends Node2D

@export_file("*.tscn") var final_boss_level: String

@onready var teleport_box: Area2D = $TeleportBox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	teleport_box.body_entered.connect(
		_on_teleport_box_body_entered
	)

	if sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


func _on_teleport_box_body_entered(body: Node2D) -> void:
	if not body is Player:
		return

	if final_boss_level.is_empty():
		push_warning("Final boss level not assigned!")
		return

	SceneTransition.change_scene(final_boss_level)
