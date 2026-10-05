extends CharacterBody2D

@export var move_speed: float = 50.0
@export var wander_radius: float = 200.0
@export var wait_time: float = 2.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target_position: Vector2
var waiting := false
var wait_timer := 0.0


func _ready():
	randomize()
	pick_new_target()
	animated_sprite.play("walk")


func _physics_process(delta):
	if waiting:
		velocity = Vector2.ZERO
		wait_timer -= delta

		if wait_timer <= 0:
			waiting = false
			pick_new_target()

		return

	# Find direction to target
	var direction := global_position.direction_to(target_position)

	# Move toward target
	velocity = direction * move_speed
	move_and_slide()

	# Play walking animation
	animated_sprite.play("walk")

	# Face the direction of movement
	if direction.x != 0:
		animated_sprite.flip_h = direction.x > 0

	# Check if we reached the target
	if global_position.distance_to(target_position) < 5.0:
		velocity = Vector2.ZERO
		waiting = true
		wait_timer = wait_time


func pick_new_target():
	var random_offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)

	target_position = global_position + random_offset
