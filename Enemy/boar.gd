
extends CharacterBody2D

enum State {
	IDLE,
	WANDER,
	WINDUP,
	CHARGE,
	HIT,
	STUNNED
}

const WALK_SPEED = 50.0
const CHARGE_SPEED = 300.0
const GRAVITY = 980.0
const KNOCKBACK_SPEED = 150.0

const WINDUP_TIME = 0.6
const STUN_TIME = 1.5
const HIT_TIME = 0.25
const DEATH_DELAY = 0.4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var ground_ray: RayCast2D = $GroundRay
@onready var state_timer: Timer = $StateTimer
@onready var hurt_box: Area2D = $HurtBox
@onready var body_collision: CollisionShape2D = $CollisionShape2D

var current_state: State = State.IDLE
var facing_direction: int = -1
var wander_direction: int = -1

var health: int = 3
var is_dead: bool = false

var knockback_velocity: float = 0.0
var damaged_players: Array[Node2D] = []


func _ready() -> void:
	state_timer.one_shot = true
	state_timer.timeout.connect(_on_state_timer_timeout)

	# Make sure the ground ray starts facing left.
	update_facing(facing_direction)

	pick_new_wander_state()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# State machine
	match current_state:

		State.IDLE:
			velocity.x = 0
			sprite.play("idle")
			check_for_player()

		State.WANDER:
			velocity.x = wander_direction * WALK_SPEED
			sprite.play("walk")
			check_for_player()

			if current_state == State.WANDER:
				check_for_ledge()

		State.WINDUP:
			velocity.x = 0
			sprite.play("windup")

		State.CHARGE:
			velocity.x = facing_direction * CHARGE_SPEED
			sprite.play("charge")

			check_charge_ledge()

		State.HIT:
			velocity.x = knockback_velocity
			knockback_velocity = move_toward(
				knockback_velocity,
				0.0,
				500.0 * delta
			)

		State.STUNNED:
			velocity.x = 0
			sprite.play("idle")

	# Apply movement.
	move_and_slide()

	# Handle walls AFTER moving.
	if is_on_wall():
		handle_wall_collision()

	# Check player overlap during charge.
	if current_state == State.CHARGE:
		check_charge_damage()


# --------------------------------
# STATE MANAGEMENT
# --------------------------------

func set_state(new_state: State, duration: float = 0.0) -> void:
	current_state = new_state

	state_timer.stop()

	if new_state == State.CHARGE:
		damaged_players.clear()

	if duration > 0.0:
		state_timer.start(duration)


func _on_state_timer_timeout() -> void:
	if is_dead:
		return

	match current_state:

		State.IDLE, State.WANDER:
			pick_new_wander_state()

		State.WINDUP:
			set_state(State.CHARGE)

		State.HIT, State.STUNNED:
			sprite.modulate = Color.WHITE
			pick_new_wander_state()


func pick_new_wander_state() -> void:
	if is_dead:
		return

	sprite.position.x = 0

	if randf() > 0.5:
		set_state(State.IDLE, randf_range(1.0, 2.5))
	else:
		wander_direction = [-1, 1].pick_random()
		update_facing(wander_direction)
		set_state(State.WANDER, randf_range(2.0, 4.0))


# --------------------------------
# FACING DIRECTION
# --------------------------------

func update_facing(dir: int) -> void:
	facing_direction = dir

	sprite.flip_h = (dir == 1)

	# Flip vision ray
	vision_ray.target_position.x = abs(vision_ray.target_position.x) * dir

	# Flip ground detection ray
	ground_ray.position.x = abs(ground_ray.position.x) * dir

	# Flip hurtbox position
	hurt_box.position.x = abs(hurt_box.position.x) * dir


# --------------------------------
# PLAYER DETECTION
# --------------------------------

func check_for_player() -> void:
	vision_ray.force_raycast_update()

	if not vision_ray.is_colliding():
		return

	var collider = vision_ray.get_collider()

	if collider != null and collider.name == "Player":
		if current_state == State.IDLE or current_state == State.WANDER:
			start_charge_sequence()


func start_charge_sequence() -> void:
	set_state(State.WINDUP, WINDUP_TIME)


# --------------------------------
# LEDGE DETECTION
# --------------------------------

func has_ground_ahead() -> bool:
	ground_ray.force_raycast_update()
	return ground_ray.is_colliding()


func check_for_ledge() -> void:
	if not is_on_floor():
		return

	if not has_ground_ahead():
		# Turn around before walking off.
		wander_direction *= -1
		update_facing(wander_direction)
		velocity.x = 0


func check_charge_ledge() -> void:
	if not is_on_floor():
		return

	if not has_ground_ahead():
		# Stop charging at a ledge.
		set_state(State.STUNNED, STUN_TIME)
		velocity.x = 0


# --------------------------------
# WALL COLLISIONS
# --------------------------------

func handle_wall_collision() -> void:
	match current_state:

		State.WANDER:
			wander_direction *= -1
			update_facing(wander_direction)
			velocity.x = 0

		State.CHARGE:
			set_state(State.STUNNED, STUN_TIME)
			velocity.x = 0


# --------------------------------
# CHARGE DAMAGE
# --------------------------------

func check_charge_damage() -> void:
	for body in hurt_box.get_overlapping_bodies():

		if body.name != "Player":
			continue

		if body in damaged_players:
			continue

		if body.has_method("take_damage"):
			body.take_damage(1, global_position)
			damaged_players.append(body)


# --------------------------------
# DAMAGE / KNOCKBACK
# --------------------------------

func take_damage(amount: int, attacker_position: Vector2) -> void:
	if is_dead:
		return

	health -= amount

	if health <= 0:
		die()
		return

	# Flash red.
	sprite.modulate = Color(1, 0.3, 0.3)

	# Knock away from the attacker.
	var direction = sign(
		global_position.x - attacker_position.x
	)

	if direction == 0:
		direction = -facing_direction

	knockback_velocity = direction * KNOCKBACK_SPEED

	velocity.y = -80.0

	set_state(State.HIT, HIT_TIME)


# --------------------------------
# DEATH
# --------------------------------

func die() -> void:
	if is_dead:
		return

	is_dead = true

	state_timer.stop()
	velocity = Vector2.ZERO

	# Stop all collisions.
	collision_layer = 0
	collision_mask = 0

	body_collision.set_deferred("disabled", true)

	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

	# Visual death feedback.
	sprite.position.x = 0
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.7)
	sprite.play("idle")

	await get_tree().create_timer(DEATH_DELAY).timeout

	queue_free()
