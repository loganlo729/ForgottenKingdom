extends CharacterBody2D

@export var speed := 40.0
@export var walk_range := 300.0   # how far left and right of the start point
@export var pause_time := 2.0

var start_x: float
var direction := 1
var waiting := false

func _ready() -> void:
	start_x = global_position.x
	$AnimatedSprite2D.play("walk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if waiting:
		velocity.x = 0
	else:
		velocity.x = direction * speed
		$AnimatedSprite2D.flip_h = direction < 0

		if global_position.x > start_x + walk_range:
			_turn(-1)
		elif global_position.x < start_x - walk_range:
			_turn(1)
		elif is_on_wall():
			_turn(-direction)

	move_and_slide()

func _turn(new_dir: int) -> void:
	direction = new_dir
	waiting = true
	$AnimatedSprite2D.play("Idle" if $AnimatedSprite2D.sprite_frames.has_animation("Idle") else "walk")
	await get_tree().create_timer(pause_time).timeout
	waiting = false
	$AnimatedSprite2D.play("walk")
