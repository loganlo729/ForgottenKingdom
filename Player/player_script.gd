extends CharacterBody2D


const SPEED = 150.0
const RUN_SPEED = 250.0
const JUMP_VELOCITY = -380.0

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if direction:
		velocity.x = direction * SPEED
		if Input.is_action_pressed("run"):
			velocity.x = direction * RUN_SPEED
		if direction < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if not is_on_floor():
		sprite.play("jump")
	elif direction != 0 && abs(velocity.x) >= 200:
		sprite.play("run")
	elif direction != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")

	move_and_slide()
