extends StaticBody2D

@onready var ground_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Put the ground on layer 4.
	collision_layer = 8
	collision_mask = 0

	# Make sure the collision shape is enabled.
	ground_shape.disabled = false
	ground_shape.one_way_collision = false

	print("BossGround layer: ", collision_layer)
	print("BossGround shape: ", ground_shape.shape)
