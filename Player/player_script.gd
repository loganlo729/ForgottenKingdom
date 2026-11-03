
extends CharacterBody2D
class_name Player

signal health_changed(current_health: int, max_health: int)

# HEALTH
var max_health = 5
var player_health = 5
var is_hit = false
var hit_stun_time = 0.25

# MOVEMENT / DASH
const SPEED = 150.0
const RUN_SPEED = 250.0
const JUMP_VELOCITY = -380.0
const LAUNCH_SPEED = 500.0
const DASH_DURATION = 0.12
const DASH_COOLDOWN = 0.6
const DECELERATION = 1500.0

# WALL JUMP / WALL SLIDE
const WALL_SLIDE_SPEED = 65.0
const WALL_JUMP_VELOCITY = -380.0
const WALL_JUMP_PUSH_SPEED = 280.0
const WALL_JUMP_CONTROL_LOCK = 0.18

# COMBO
const ATTACK_DURATION = 0.25
const COMBO_WINDOW = 0.55
const FINISHER_LUNGE_SPEED = 350.0

# RANGED
const RANGED_ATTACK_DURATION = 0.10

# JUMP UPGRADES
const BASE_JUMPS = 1
const UPGRADED_JUMPS = 2

# SWORD UPGRADES
const NORMAL_SWORD_RANGE = 1.0
const LONG_SWORD_RANGE = 1.5

# GUARD
const GUARD_DURATION = 0.3
const GUARD_COOLDOWN = 0.5

# KEYS
var hasKeys = [false, false]

# NODES
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bullet_sprite: AnimatedSprite2D = $AnimatedSprite2D/Bullet
@onready var attack_box: Area2D = $BaseAttackBox
@onready var ranged_attack_box: Area2D = $RangedAttackBox

# DASH VARIABLES
var is_dashing = false
var dash_time_left = 0.0
var dash_cooldown_left = 0.0

# WALL JUMP VARIABLES
var wall_jump_lock_left = 0.0

# COMBO VARIABLES
var is_attacking = false
var attack_time_left = 0.0
var combo_count = 0
var combo_time_left = 0.0
var has_air_attacked = false

# RANGED VARIABLES
var is_ranged_attacking = false
var ranged_attack_time_left = 0.0

# JUMP VARIABLES
var jumps_left = 0

# GUARD VARIABLES
var is_guarding = false
var guard_time_left = 0.0
var guard_cooldown_left = 0.0


# --------------------------------
# INITIALIZATION
# --------------------------------

func _ready() -> void:
	jumps_left = get_max_jumps()

	if not Upgrades.upgrade_unlocked.is_connected(
		_on_upgrade_unlocked
	):
		Upgrades.upgrade_unlocked.connect(
			_on_upgrade_unlocked
		)

	update_sword_range()

	var ui: UILayer = (
		get_tree().get_first_node_in_group("ui") as UILayer
	)

	if ui:
		for i in range(hasKeys.size()):
			if hasKeys[i]:
				ui.add_key(i)

	health_changed.emit(player_health, max_health)

	if not attack_box.body_entered.is_connected(
		_on_attack_box_body_entered
	):
		attack_box.body_entered.connect(
			_on_attack_box_body_entered
		)

	attack_box.monitoring = false
	ranged_attack_box.monitoring = false


# --------------------------------
# UPGRADES
# --------------------------------

func get_max_jumps() -> int:
	if Upgrades.has_double_jump:
		return UPGRADED_JUMPS

	return BASE_JUMPS


func update_sword_range() -> void:
	var multiplier = NORMAL_SWORD_RANGE

	if Upgrades.has_long_sword:
		multiplier = LONG_SWORD_RANGE

	var facing = -1.0 if sprite.flip_h else 1.0

	attack_box.scale.x = multiplier * facing


func _on_upgrade_unlocked(upgrade_name: String) -> void:
	match upgrade_name:
		"double_jump":
			jumps_left = get_max_jumps()

		"long_sword":
			update_sword_range()

		"air_dash":
			pass

		"wall_jump":
			wall_jump_lock_left = 0.0


# --------------------------------
# MELEE DAMAGE
# --------------------------------

func _on_attack_box_body_entered(body: Node2D) -> void:
	if not is_attacking:
		return

	if body.is_in_group("Enemies") and body.has_method(
		"take_damage"
	):
		var knockback_direction = (
			Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		)

		var damage_to_deal = 1

		if combo_count == 3:
			damage_to_deal = 2

		body.take_damage(
			damage_to_deal,
			knockback_direction
		)


# --------------------------------
# PHYSICS
# --------------------------------

func _physics_process(delta: float) -> void:

	var on_floor = is_on_floor()
	var on_wall = is_on_wall()

	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)

	# Reset jumps and air attacks on landing.
	if on_floor:
		jumps_left = get_max_jumps()
		has_air_attacked = false

	# --------------------------------
	# WALL JUMP CONTROL TIMER
	# --------------------------------

	if wall_jump_lock_left > 0.0:
		wall_jump_lock_left = max(
			wall_jump_lock_left - delta,
			0.0
		)

	# --------------------------------
	# GRAVITY
	# --------------------------------

	if not on_floor and not is_attacking:
		velocity += get_gravity() * delta

	# --------------------------------
	# WALL SLIDING (UPGRADE REQUIRED)
	# --------------------------------

	var wall_sliding = (
		Upgrades.has_wall_jump
		and not on_floor
		and on_wall
		and velocity.y > 0.0
		and not is_dashing
		and not is_attacking
		and wall_jump_lock_left <= 0.0
	)

	if wall_sliding:
		velocity.y = min(
			velocity.y,
			WALL_SLIDE_SPEED
		)

	# --------------------------------
	# DASH TIMER
	# --------------------------------

	if is_dashing:
		dash_time_left -= delta

		if dash_time_left <= 0.0:
			is_dashing = false
			velocity.x = 0.0

	# DASH COOLDOWN
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(
			dash_cooldown_left - delta,
			0.0
		)

	# ATTACK TIMER
	if is_attacking:
		attack_time_left -= delta

		if attack_time_left <= 0.0:
			is_attacking = false
			attack_box.monitoring = false
			combo_time_left = COMBO_WINDOW

	# RANGED TIMER
	if is_ranged_attacking:
		ranged_attack_time_left -= delta

		if ranged_attack_time_left <= 0.0:
			is_ranged_attacking = false
			ranged_attack_box.monitoring = false

	# COMBO RESET TIMER
	if not is_attacking and combo_count > 0:
		combo_time_left -= delta

		if combo_time_left <= 0.0:
			combo_count = 0

	# --------------------------------
	# FACING DIRECTION
	# --------------------------------

	if direction != 0 \
	and not is_attacking \
	and not is_dashing \
	and wall_jump_lock_left <= 0.0:

		sprite.flip_h = direction < 0

		bullet_sprite.flip_h = direction < 0

		if direction < 0:
			bullet_sprite.position.x = -62
		else:
			bullet_sprite.position.x = 62

		update_sword_range()

		ranged_attack_box.scale.x = (
			-1 if direction < 0 else 1
		)

	# --------------------------------
	# JUMP / DOUBLE JUMP / WALL JUMP
	# --------------------------------

	if Input.is_action_just_pressed("jump") \
	and not is_attacking:

		# REGULAR GROUND JUMP
		if on_floor:
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1

		# WALL JUMP (UPGRADE REQUIRED)
		elif Upgrades.has_wall_jump \
		and on_wall \
		and wall_jump_lock_left <= 0.0:

			var wall_normal = get_wall_normal()

			# Cancel active dash.
			if is_dashing:
				is_dashing = false
				dash_time_left = 0.0

			# Launch upward.
			velocity.y = WALL_JUMP_VELOCITY

			# Push away from the wall.
			velocity.x = (
				wall_normal.x * WALL_JUMP_PUSH_SPEED
			)

			# Lock movement briefly.
			wall_jump_lock_left = WALL_JUMP_CONTROL_LOCK

			# Preserve one air jump if double
			# jump is unlocked.
			jumps_left = max(
				get_max_jumps() - 1,
				0
			)

			wall_sliding = false

		# DOUBLE JUMP
		elif jumps_left > 0:
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1

			if is_dashing:
				is_dashing = false
				dash_time_left = 0.0
				velocity.x = 0.0

	# --------------------------------
	# GUARD
	# --------------------------------

	if is_guarding:
		guard_time_left -= delta

		if not Input.is_action_pressed("guard") \
		or guard_time_left <= 0.0:
			is_guarding = false
			guard_cooldown_left = GUARD_COOLDOWN

	else:
		if guard_cooldown_left > 0.0:
			guard_cooldown_left = max(
				guard_cooldown_left - delta,
				0.0
			)

	if Input.is_action_pressed("guard") \
	and not is_guarding \
	and guard_cooldown_left <= 0.0 \
	and not is_dashing \
	and not is_attacking \
	and not is_ranged_attacking:

		is_guarding = true
		guard_time_left = GUARD_DURATION

	# --------------------------------
	# COMBO ATTACK
	# --------------------------------

	if Input.is_action_just_pressed("attack") \
	and not is_dashing \
	and not is_attacking \
	and not is_ranged_attacking:

		var can_attack = not has_air_attacked

		if can_attack:
			is_attacking = true
			attack_time_left = ATTACK_DURATION

			velocity.x = 0.0

			if combo_count == 0:
				combo_count = 1

			elif combo_count == 1:
				combo_count = 2

			elif combo_count == 2 and on_floor:
				combo_count = 3

				var lunge_dir = (
					Vector2.LEFT if sprite.flip_h
					else Vector2.RIGHT
				)

				velocity.x = (
					lunge_dir.x * FINISHER_LUNGE_SPEED
				)

			else:
				combo_count = 1

			if not on_floor:
				has_air_attacked = true

			attack_box.monitoring = true

	# --------------------------------
	# DASH / AIR DASH
	# --------------------------------

	var can_dash = on_floor or Upgrades.has_air_dash

	if Input.is_action_just_pressed("dash") \
	and can_dash \
	and not is_dashing \
	and dash_cooldown_left <= 0.0 \
	and not is_attacking \
	and not is_guarding:

		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown_left = DASH_COOLDOWN

		var forward_dir = (
			Vector2.LEFT if sprite.flip_h
			else Vector2.RIGHT
		)

		if Input.is_action_pressed("move_down"):
			forward_dir *= -1

		velocity.x = forward_dir.x * LAUNCH_SPEED

	# --------------------------------
	# RANGED ATTACK
	# --------------------------------

	if Input.is_action_just_pressed("ranged_attack") \
	and not is_dashing \
	and not is_attacking \
	and not is_ranged_attacking:

		is_ranged_attacking = true
		ranged_attack_time_left = RANGED_ATTACK_DURATION
		ranged_attack_box.monitoring = true

	# --------------------------------
	# MOVEMENT
	# --------------------------------

	if is_dashing:
		pass

	elif wall_jump_lock_left > 0.0:
		# Keep wall-jump momentum.
		pass

	elif is_attacking:
		if not on_floor:
			velocity.x = 0.0
			velocity.y = 0.0

		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				DECELERATION * delta
			)

	else:
		if direction != 0:
			var movement_speed = SPEED

			if Input.is_action_pressed("run"):
				movement_speed = RUN_SPEED

			velocity.x = direction * movement_speed

		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				DECELERATION * delta
			)

	# --------------------------------
	# ANIMATIONS
	# --------------------------------

	if is_attacking:
		sprite.play("attack" + str(combo_count))

	elif is_dashing:
		sprite.play("run")

	elif wall_sliding:
		if sprite.sprite_frames.has_animation("wall_slide"):
			sprite.play("wall_slide")
		else:
			sprite.play("jump")

	elif not on_floor:
		sprite.play("jump")

	elif is_guarding:
		sprite.play("guard")

	elif direction != 0 and abs(velocity.x) >= 200:
		sprite.play("run")

	elif direction != 0:
		sprite.play("walk")

	else:
		sprite.play("idle")

	if is_ranged_attacking:
		bullet_sprite.play("bullet")

	move_and_slide()


# --------------------------------
# DAMAGE / HEALTH
# --------------------------------

func take_damage(amount: int, source_position: Vector2) -> void:
	if is_hit or is_dashing:
		return

	# CHECK GUARD
	if is_guarding:
		var enemy_is_left = (
			source_position.x < global_position.x
		)

		if (sprite.flip_h and enemy_is_left) \
		or (not sprite.flip_h and not enemy_is_left):

			var block_knockback = (
				Vector2.RIGHT if enemy_is_left
				else Vector2.LEFT
			)

			velocity = block_knockback * 150.0
			return

	# APPLY DAMAGE
	player_health -= amount
	is_hit = true

	health_changed.emit(player_health, max_health)

	# KNOCKBACK
	var knockback_dir = (
		Vector2.RIGHT
		if source_position.x < global_position.x
		else Vector2.LEFT
	)

	velocity = knockback_dir * 300.0
	velocity.y = -150.0

	# DAMAGE FLASH
	sprite.modulate = Color(1, 0.3, 0.3)

	await get_tree().create_timer(hit_stun_time).timeout

	is_hit = false
	sprite.modulate = Color.WHITE

	if player_health <= 0:
		get_tree().reload_current_scene()


# --------------------------------
# KEYS
# --------------------------------

func add_key(keyNum: int) -> void:
	if keyNum >= 0 and keyNum < hasKeys.size():
		hasKeys[keyNum] = true


func remove_key(keyNum: int) -> void:
	if keyNum >= 0 and keyNum < hasKeys.size():
		hasKeys[keyNum] = false
