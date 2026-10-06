extends CharacterBody2D

@export var move_speed: float = 50.0
@export var wander_radius: float = 200.0
@export var wait_time: float = 2.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var target_position: Vector2
var player: Node2D = null

var waiting := false
var wait_timer := 0.0

var attacking := false
var attack_timer := 0.0


func _ready():
	randomize()

	pick_new_target()
	animated_sprite.play("idle")

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)


func _physics_process(delta):

	# Reduce attack cooldown
	if attack_timer > 0:
		attack_timer -= delta


	# =========================
	# PLAYER DETECTED
	# =========================

	if player != null and is_instance_valid(player):

		var distance = global_position.distance_to(player.global_position)

		# Player is close enough to attack
		if distance <= attack_range:

			velocity = Vector2.ZERO
			animated_sprite.play("idle")

			face_player()
			attack()

			return


		# Player is detected but too far away
		# Chase the player

		var direction = global_position.direction_to(player.global_position)

		velocity = direction * move_speed

		animated_sprite.play("walk")

		face_direction(direction)

		move_and_slide()

		return


	# =========================
	# WANDERING
	# =========================

	if waiting:

		velocity = Vector2.ZERO
		animated_sprite.play("idle")

		wait_timer -= delta

		if wait_timer <= 0:
			waiting = false
			pick_new_target()

		return


	# Move toward wandering target

	var direction = global_position.direction_to(target_position)

	velocity = direction * move_speed

	animated_sprite.play("walk")

	face_direction(direction)

	move_and_slide()


	# Reached wandering destination

	if global_position.distance_to(target_position) < 5.0:

		velocity = Vector2.ZERO

		waiting = true
		wait_timer = wait_time

		animated_sprite.play("idle")


# =========================
# FACE DIRECTION
# =========================

func face_direction(direction: Vector2):

	if direction.x != 0:
		# Change this if your sprite faces the opposite direction
		animated_sprite.flip_h = direction.x < 0


# =========================
# FACE PLAYER
# =========================

func face_player():

	if player == null:
		return

	var direction = global_position.direction_to(player.global_position)

	face_direction(direction)


# =========================
# ATTACK
# =========================

func attack():

	if attacking:
		return

	if attack_timer > 0:
		return

	attacking = true

	velocity = Vector2.ZERO

	animated_sprite.play("attack")

	await animated_sprite.animation_finished

	# Make sure the player is still close
	if player != null and is_instance_valid(player):

		var distance = global_position.distance_to(player.global_position)

		if distance <= attack_range:

			if player.has_method("take_damage"):
				player.take_damage(attack_damage)

	attack_timer = attack_cooldown

	attacking = false


# =========================
# PLAYER ENTERS DETECTION
# =========================

func _on_detection_area_body_entered(body):

	if body.is_in_group("player"):

		player = body

		waiting = false


# =========================
# PLAYER LEAVES DETECTION
# =========================

func _on_detection_area_body_exited(body):

	if body == player:

		player = null
		attacking = false

		# Start wandering again
		pick_new_target()


# =========================
# PICK WANDER TARGET
# =========================

func pick_new_target():

	var random_offset = Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)

	target_position = global_position + random_offset
