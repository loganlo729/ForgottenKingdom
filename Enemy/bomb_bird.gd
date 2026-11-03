
extends CharacterBody2D

enum State {
	IDLE,
	CHARGING,
	HIT,
	EXPLODING,
	DEAD
}

# HEALTH
@export var max_health: int = 3

# MOVEMENT
@export var fly_speed: float = 100.0
@export var acceleration: float = 250.0
@export var detection_radius: float = 200.0
@export var explosion_radius: float = 50.0
@export var explosion_damage: int = 1
@export var contact_distance: float = 24.0
@export var arrival_distance: float = 8.0
@export var reset_delay: float = 0.5

# DAMAGE / KNOCKBACK
const KNOCKBACK_SPEED = 150.0
const HIT_TIME = 0.25
const DEATH_DELAY = 0.4

# NODES
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var detection_area: Area2D = (
	get_node_or_null("DetectionArea") as Area2D
)

@onready var explosion_area: Area2D = (
	get_node_or_null("ExplosionArea") as Area2D
)

@onready var body_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)

# VARIABLES
var health: int = 3
var current_state: State = State.IDLE

var player: Player = null
var target_position: Vector2 = Vector2.ZERO

var target_locked: bool = false
var resetting: bool = false
var is_dead: bool = false

var hit_time_left: float = 0.0


# --------------------------------
# INITIALIZATION
# --------------------------------

func _ready() -> void:
	health = max_health

	# Required for the player's sword attacks.
	add_to_group("Enemies")

	# Find player.
	player = find_player(get_tree().current_scene)

	# Detection area.
	if is_instance_valid(detection_area):
		detection_area.body_entered.connect(
			_on_player_detected
		)

		set_area_radius(
			detection_area,
			detection_radius
		)

	# Explosion area.
	if is_instance_valid(explosion_area):
		set_area_radius(
			explosion_area,
			explosion_radius
		)

	# Warn about missing physical collision.
	if not is_instance_valid(body_collision):
		push_warning(
			"Flying enemy is missing its root CollisionShape2D!"
		)

	play_animation("idle")


# --------------------------------
# AREA SETUP
# --------------------------------

func set_area_radius(
	area: Area2D,
	radius: float
) -> void:

	var collision_shape = (
		area.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if not is_instance_valid(collision_shape):
		return

	if collision_shape.shape is CircleShape2D:
		var new_shape = (
			collision_shape.shape.duplicate()
			as CircleShape2D
		)

		new_shape.radius = radius
		collision_shape.shape = new_shape


# --------------------------------
# FIND PLAYER
# --------------------------------

func find_player(root: Node) -> Player:
	if root == null:
		return null

	if root is Player:
		return root as Player

	for child in root.get_children():
		var found = find_player(child)

		if found != null:
			return found

	return null


# --------------------------------
# PHYSICS
# --------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		player = find_player(get_tree().current_scene)

	match current_state:

		State.IDLE:
			velocity = Vector2.ZERO
			play_animation("idle")
			check_for_player()

		State.CHARGING:
			move_toward_target(delta)

		State.HIT:
			hit_time_left -= delta

			# Gradually reduce knockback.
			velocity = velocity.move_toward(
				Vector2.ZERO,
				600.0 * delta
			)

			move_and_slide()

			if hit_time_left <= 0.0:
				sprite.modulate = Color.WHITE
				resetting = false
				current_state = State.IDLE
				velocity = Vector2.ZERO

		State.EXPLODING:
			velocity = Vector2.ZERO

		State.DEAD:
			velocity = Vector2.ZERO


# --------------------------------
# ANIMATIONS
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

	if body is Player:
		player = body as Player
		lock_target(player)


func check_for_player() -> void:
	if resetting or target_locked:
		return

	if not is_instance_valid(player):
		return

	var distance = global_position.distance_to(
		player.global_position
	)

	if distance <= detection_radius:
		lock_target(player)


func lock_target(target: Player) -> void:
	if is_dead or resetting or target_locked:
		return

	# Lock the player's current position.
	target_position = target.global_position
	target_locked = true

	current_state = State.CHARGING
	play_animation("fly")


# --------------------------------
# CHARGING MOVEMENT
# --------------------------------

func move_toward_target(delta: float) -> void:
	# Check direct player contact.
	if is_instance_valid(player):
		var player_distance = global_position.distance_to(
			player.global_position
		)

		if player_distance <= contact_distance:
			explode(player)
			return

	var distance = global_position.distance_to(
		target_position
	)

	# Reached target without hitting player.
	if distance <= arrival_distance:
		reset_enemy()
		return

	var direction = global_position.direction_to(
		target_position
	)

	var desired_velocity = direction * fly_speed

	velocity = velocity.move_toward(
		desired_velocity,
		acceleration * delta
	)

	# Prevent overshooting.
	if delta > 0.0 and velocity.length() * delta >= distance:
		velocity = direction * (distance / delta)

	move_and_slide()

	# Check collisions after moving.
	var hit_wall: bool = false

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		# Collided with player.
		if collider is Player:
			player = collider as Player
			explode(player)
			return

		# Collided with environment.
		if collider is PhysicsBody2D:
			hit_wall = true

	# Check proximity again after movement.
	if is_instance_valid(player):
		if global_position.distance_to(
			player.global_position
		) <= contact_distance:
			explode(player)
			return

	if hit_wall:
		reset_enemy()
		return

	# Reached the target without contact.
	if global_position.distance_to(
		target_position
	) <= arrival_distance:
		reset_enemy()


# --------------------------------
# RESET
# --------------------------------

func reset_enemy() -> void:
	if current_state != State.CHARGING:
		return

	if resetting or is_dead:
		return

	resetting = true
	current_state = State.IDLE

	target_locked = false
	target_position = Vector2.ZERO
	velocity = Vector2.ZERO

	play_animation("idle")

	await get_tree().create_timer(reset_delay).timeout

	if not is_inside_tree() or is_dead:
		return

	if current_state == State.IDLE:
		resetting = false


# --------------------------------
# DEALING DAMAGE
# --------------------------------

func explode(hit_player: Player = null) -> void:
	if is_dead or current_state == State.EXPLODING:
		return

	current_state = State.EXPLODING
	velocity = Vector2.ZERO

	# Deal damage BEFORE disabling collisions.
	apply_explosion_damage(hit_player)

	disable_collisions()

	# Play explosion animation.
	if sprite.sprite_frames.has_animation("explode"):
		sprite.sprite_frames.set_animation_loop(
			"explode",
			false
		)
		sprite.play("explode")
	else:
		sprite.visible = false

	await get_tree().create_timer(0.5).timeout

	queue_free()


func apply_explosion_damage(
	hit_player: Player
) -> void:

	var damaged_players: Array[Player] = []

	# Direct contact always counts.
	if is_instance_valid(hit_player):
		damaged_players.append(hit_player)

	# Check the explosion hitbox.
	if is_instance_valid(explosion_area):
		for body in explosion_area.get_overlapping_bodies():
			if body is Player:
				if body not in damaged_players:
					damaged_players.append(body as Player)

	# Distance fallback in case area masks are wrong.
	if is_instance_valid(player):
		var distance = global_position.distance_to(
			player.global_position
		)

		if distance <= explosion_radius:
			if player not in damaged_players:
				damaged_players.append(player)

	# Damage each player once.
	for victim in damaged_players:
		if is_instance_valid(victim):
			victim.take_damage(
				explosion_damage,
				global_position
			)

			print("Flying enemy hit player!")


# --------------------------------
# TAKING DAMAGE
# --------------------------------

func take_damage(
	amount: int,
	knockback_direction: Vector2
) -> void:

	if is_dead or current_state == State.EXPLODING:
		return

	health -= amount

	print(
		"Flying enemy HP: ",
		health,
		"/",
		max_health
	)

	# Death.
	if health <= 0:
		die()
		return

	# Cancel current charge.
	target_locked = false
	target_position = Vector2.ZERO
	resetting = true

	# Flash red.
	sprite.modulate = Color(1.0, 0.3, 0.3)

	# Knockback.
	var direction = knockback_direction.normalized()

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	velocity = Vector2(
		direction.x * KNOCKBACK_SPEED,
		-60.0
	)

	# Enter hit state.
	current_state = State.HIT
	hit_time_left = HIT_TIME

	if sprite.sprite_frames.has_animation("hit"):
		play_animation("hit")
	else:
		play_animation("idle")


# --------------------------------
# DISABLE COLLISIONS
# --------------------------------

func disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0

	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)

	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", false)

	if is_instance_valid(explosion_area):
		explosion_area.set_deferred("monitoring", false)


# --------------------------------
# DEATH
# --------------------------------

func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_state = State.DEAD

	velocity = Vector2.ZERO

	disable_collisions()

	# Visual death feedback.
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.7)

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.play("idle")

	await get_tree().create_timer(DEATH_DELAY).timeout

	queue_free()
