
extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

# BOSS STATS
@export var max_health: int = 15
@export var move_speed: float = 75.0
@export var detection_range: float = 250.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 2.0

# NODES
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var strong_hitbox: Area2D = $Hitbox2
@onready var body_collision: CollisionShape2D = $CollisionShape2D

# VARIABLES
var health: int = 15
var current_state: State = State.IDLE
var player: Player = null
var attack_timer: float = 0.0
var is_dead: bool = false

var active_hitbox: Area2D = null
var attack_active: bool = false
var attack_is_strong: bool = false
var hit_player_this_attack: bool = false


# --------------------------------
# INITIALIZATION
# --------------------------------

func _ready() -> void:
	health = max_health

	# Match Player collision settings.
	# Layer: 1 + 2
	# Mask: 1 + 2 + 3
	collision_layer = 3
	collision_mask = 7

	# Match Player movement physics.
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_snap_length = 1.0

	add_to_group("Enemies")

	player = get_tree().get_first_node_in_group(
		"Player"
	) as Player

	# Prevent Player and boss from acting
	# as physical platforms for each other.
	if is_instance_valid(player):
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)

	# Attack areas detect Player's layers.
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 3
	attack_hitbox.monitoring = true

	strong_hitbox.collision_layer = 0
	strong_hitbox.collision_mask = 3
	strong_hitbox.monitoring = true

	play_animation("idle")


# --------------------------------
# ANIMATIONS
# --------------------------------

func play_animation(animation_name: String) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


# --------------------------------
# PHYSICS
# --------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Same gravity approach as Player.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Attack cooldown.
	if attack_timer > 0.0:
		attack_timer = max(
			attack_timer - delta,
			0.0
		)

	# Find player again if necessary.
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(
			"Player"
		) as Player

		if is_instance_valid(player):
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)

	if not is_instance_valid(player):
		velocity.x = 0.0
		move_and_slide()
		return

	var distance = global_position.distance_to(
		player.global_position
	)

	match current_state:

		State.IDLE:
			velocity.x = 0.0
			play_animation("idle")

			if distance <= detection_range:
				current_state = State.CHASE

		State.CHASE:
			var direction = sign(
				player.global_position.x - global_position.x
			)

			velocity.x = direction * move_speed

			if direction != 0:
				# Demon faces LEFT in its original sprite.
				sprite.flip_h = direction > 0

				# Hitboxes start facing left.
				var hitbox_facing = (
					-1.0 if direction > 0 else 1.0
				)

				attack_hitbox.scale.x = hitbox_facing
				strong_hitbox.scale.x = hitbox_facing

			if distance <= attack_range \
			and attack_timer <= 0.0:
				start_attack()

			elif distance > detection_range * 1.5:
				current_state = State.IDLE

			else:
				play_animation("walk")

		State.ATTACK:
			velocity.x = 0.0

		State.DEAD:
			velocity = Vector2.ZERO

	# Same movement method as Player.
	move_and_slide()

	# Check attack overlaps after physics updates.
	if current_state == State.ATTACK and attack_active:
		check_attack_damage()


# --------------------------------
# ATTACK
# --------------------------------

func start_attack() -> void:
	if is_dead:
		return

	current_state = State.ATTACK
	velocity.x = 0.0
	attack_timer = attack_cooldown

	attack_is_strong = randf() < 0.3
	hit_player_this_attack = false
	attack_active = true

	if attack_is_strong:
		active_hitbox = strong_hitbox
		play_animation("attack2")
	else:
		active_hitbox = attack_hitbox
		play_animation("attack")

	# Active damage window.
	await get_tree().create_timer(0.4).timeout

	if is_dead or not is_inside_tree():
		return

	attack_active = false
	active_hitbox = null

	# Recovery.
	await get_tree().create_timer(0.3).timeout

	if not is_dead and is_inside_tree():
		current_state = State.CHASE


# --------------------------------
# DAMAGE TO PLAYER
# --------------------------------

func check_attack_damage() -> void:
	if hit_player_this_attack:
		return

	if not is_instance_valid(active_hitbox):
		return

	for body in active_hitbox.get_overlapping_bodies():
		if body is Player:
			var damage = attack_damage

			if attack_is_strong:
				damage *= 2

			body.take_damage(
				damage,
				global_position
			)

			hit_player_this_attack = true
			return


# --------------------------------
# TAKE DAMAGE
# --------------------------------

func take_damage(
	amount: int,
	_knockback_direction: Vector2
) -> void:
	if is_dead:
		return

	health -= amount

	print("Boss HP: ", health, "/", max_health)

	if health <= 0:
		die()
		return

	sprite.modulate = Color(1, 0.3, 0.3)

	await get_tree().create_timer(0.15).timeout

	if not is_dead:
		sprite.modulate = Color.WHITE


# --------------------------------
# DEATH
# --------------------------------

func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_state = State.DEAD

	velocity = Vector2.ZERO
	attack_active = false

	attack_hitbox.set_deferred("monitoring", false)
	strong_hitbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)

	sprite.modulate = Color(0.4, 0.4, 0.4)

	if sprite.sprite_frames.has_animation("death"):
		sprite.sprite_frames.set_animation_loop(
			"death",
			false
		)
		sprite.play("death")
		await sprite.animation_finished
	else:
		sprite.stop()
		await get_tree().create_timer(0.5).timeout

	queue_free()
