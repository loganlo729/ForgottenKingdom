
extends CharacterBody2D

enum State {
	IDLE,
	CHARGING,
	EXPLODING
}

@export var fly_speed: float = 100.0
@export var acceleration: float = 250.0
@export var detection_radius: float = 200.0
@export var explosion_radius: float = 50.0
@export var explosion_damage: int = 1
@export var arrival_distance: float = 8.0
@export var reset_delay: float = 0.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var explosion_area: Area2D = $ExplosionArea
@onready var body_collision: CollisionShape2D = $CollisionShape2D

var current_state: State = State.IDLE
var target_position: Vector2 = Vector2.ZERO
var target_locked: bool = false
var resetting: bool = false


func _ready() -> void:
	detection_area.body_entered.connect(_on_player_detected)

	# Set detection radius.
	var detection_shape = detection_area.get_node(
		"CollisionShape2D"
	).shape as CircleShape2D

	if detection_shape:
		detection_shape = detection_shape.duplicate()
		detection_shape.radius = detection_radius
		detection_area.get_node("CollisionShape2D").shape = detection_shape

	# Set explosion radius.
	var explosion_shape = explosion_area.get_node(
		"CollisionShape2D"
	).shape as CircleShape2D

	if explosion_shape:
		explosion_shape = explosion_shape.duplicate()
		explosion_shape.radius = explosion_radius
		explosion_area.get_node("CollisionShape2D").shape = explosion_shape

	play_animation("idle")

	# Check for players already within range.
	call_deferred("check_initial_detection")


func _physics_process(delta: float) -> void:
	match current_state:

		State.IDLE:
			velocity = Vector2.ZERO
			play_animation("idle")

		State.CHARGING:
			move_toward_target(delta)

		State.EXPLODING:
			velocity = Vector2.ZERO


# --------------------------------
# ANIMATION
# --------------------------------

func play_animation(animation_name: String) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name:
			sprite.play(animation_name)


# --------------------------------
# PLAYER DETECTION
# --------------------------------

func _on_player_detected(body: Node2D) -> void:
	if current_state != State.IDLE or resetting:
		return

	if body.name != "Player":
		return

	lock_target(body)


func check_initial_detection() -> void:
	if current_state != State.IDLE or resetting:
		return

	for body in detection_area.get_overlapping_bodies():
		if body.name == "Player":
			lock_target(body)
			return


func lock_target(player: Node2D) -> void:
	if target_locked or resetting:
		return

	# Lock onto the player's CURRENT position.
	# The target does not update afterward.
	target_position = player.global_position
	target_locked = true

	current_state = State.CHARGING
	play_animation("fly")


# --------------------------------
# MOVEMENT
# --------------------------------

func move_toward_target(delta: float) -> void:
	var distance = global_position.distance_to(target_position)

	# Reached the saved location without hitting player.
	if distance <= arrival_distance:
		reset_enemy()
		return

	var direction = global_position.direction_to(target_position)
	var desired_velocity = direction * fly_speed

	velocity = velocity.move_toward(
		desired_velocity,
		acceleration * delta
	)

	# Prevent overshooting the saved position.
	if delta > 0.0 and velocity.length() * delta >= distance:
		velocity = direction * (distance / delta)

	move_and_slide()

	# Check all slide collisions.
	# Player collision takes priority over walls.
	var hit_wall: bool = false

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is Node2D and collider.name == "Player":
			explode()
			return

		if collider is PhysicsBody2D:
			hit_wall = true

	if hit_wall:
		reset_enemy()
		return

	# Missed the player and reached the target.
	if global_position.distance_to(target_position) <= arrival_distance:
		reset_enemy()


# --------------------------------
# RESET
# --------------------------------

func reset_enemy() -> void:
	if current_state != State.CHARGING or resetting:
		return

	resetting = true
	current_state = State.IDLE

	target_locked = false
	target_position = Vector2.ZERO
	velocity = Vector2.ZERO

	play_animation("idle")

	# Brief cooldown prevents immediate repeated attacks.
	await get_tree().create_timer(reset_delay).timeout

	if not is_inside_tree():
		return

	resetting = false

	# Detect player even if they're still inside the area.
	check_initial_detection()


# --------------------------------
# EXPLOSION
# --------------------------------

func explode() -> void:
	if current_state == State.EXPLODING:
		return

	current_state = State.EXPLODING
	resetting = false
	velocity = Vector2.ZERO

	# Disable physical collisions.
	collision_layer = 0
	collision_mask = 0

	body_collision.set_deferred("disabled", true)
	detection_area.set_deferred("monitoring", false)
	explosion_area.set_deferred("monitoring", false)

	# Damage nearby players.
	apply_explosion_damage()

	# Play explosion animation if available.
	if sprite.sprite_frames.has_animation("explode"):
		sprite.sprite_frames.set_animation_loop("explode", false)
		sprite.play("explode")
	else:
		sprite.visible = false

	# Always disappear after exploding.
	await get_tree().create_timer(0.5).timeout

	queue_free()


func apply_explosion_damage() -> void:
	var space_state = get_world_2d().direct_space_state

	var circle = CircleShape2D.new()
	circle.radius = explosion_radius

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = explosion_area.collision_mask
	query.exclude = [get_rid()]

	var results = space_state.intersect_shape(query, 32)
	var damaged_bodies: Array = []

	for result in results:
		var body = result.collider

		if body in damaged_bodies:
			continue

		if body is Node2D and body.name == "Player":
			if body.has_method("take_damage"):
				body.take_damage(explosion_damage, global_position)
				damaged_bodies.append(body)
