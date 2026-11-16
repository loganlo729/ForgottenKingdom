extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	WINDUP,
	SLASH,
	CHARGE,
	RECOVER,
	STUNNED,
	DEAD
}

enum AttackType {
	SLASH,
	CHARGE,
	SLAM
}

# --------------------------------
# BOSS STATS
# --------------------------------

@export var max_health: int = 15
@export var move_speed: float = 85.0
@export var detection_range: float = 350.0
@export var attack_range: float = 60.0
@export var charge_start_range: float = 180.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.8
@export var parry_stun_duration: float = 1.5

# ATTACK SETTINGS
@export var slash_lunge_speed: float = 150.0
@export var charge_speed: float = 330.0
@export var slam_radius: float = 115.0
@export var attack_offset: float = 40.0

# NODES
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var body_collision: CollisionShape2D = $CollisionShape2D

# These optional nodes can be omitted from the scene.
@onready var slash_fx: AnimatedSprite2D = (
	get_node_or_null("SlashFX") as AnimatedSprite2D
)
@onready var slam_fx: AnimatedSprite2D = (
	get_node_or_null("SlamFX") as AnimatedSprite2D
)
@onready var health_bar: ProgressBar = (
	get_node_or_null("HealthBar") as ProgressBar
)

# VARIABLES
var health: int
var player: Player = null
var state: State = State.IDLE
var current_attack: AttackType = AttackType.SLASH
var state_time: float = 0.0
var cooldown_left: float = 0.0
var facing_dir: int = -1
var attack_count: int = 0
var active_damage: int = 1
var attack_active: bool = false
var is_dead: bool = false
var phase_two: bool = false
var hit_targets: Array[Node2D] = []

var base_sprite_position: Vector2
var base_sprite_scale: Vector2
var walk_bob_time: float = 0.0
var flash_tween: Tween


# --------------------------------
# INITIALIZATION
# --------------------------------

func _ready() -> void:
	health = max_health
	base_sprite_position = sprite.position
	base_sprite_scale = sprite.scale

	add_to_group("Enemies")
	player = get_tree().get_first_node_in_group("Player") as Player

	# Keep the boss's PHYSICAL collision layer/mask
	# configured in the Inspector, as in the working scene.
	# The attack Area2D must detect the Player (layers 1/2).
	attack_area.collision_layer = 0
	attack_area.collision_mask = 3
	attack_area.monitoring = true

	if not attack_area.body_entered.is_connected(
		_on_attack_area_body_entered
	):
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)

	update_facing(-1)

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.show_percentage = false

	if slash_fx:
		slash_fx.visible = false
		if not slash_fx.animation_finished.is_connected(
			_on_slash_fx_animation_finished
		):
			slash_fx.animation_finished.connect(
				_on_slash_fx_animation_finished
			)

	if slam_fx:
		slam_fx.visible = false
		if not slam_fx.animation_finished.is_connected(
			_on_slam_fx_animation_finished
		):
			slam_fx.animation_finished.connect(
				_on_slam_fx_animation_finished
			)

	play_animation("idle")


# --------------------------------
# PHYSICS
# --------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Same gravity and movement style as Player.
	if not is_on_floor():
		velocity += get_gravity() * delta

	cooldown_left = max(cooldown_left - delta, 0.0)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Player

	match state:
		State.IDLE:
			velocity.x = move_toward(
				velocity.x, 0.0, 1200.0 * delta
			)
			play_animation("idle")

			if is_instance_valid(player):
				var distance = global_position.distance_to(
					player.global_position
				)
				if distance <= detection_range:
					state = State.CHASE

		State.CHASE:
			chase_player(delta)

		State.WINDUP:
			velocity.x = move_toward(
				velocity.x, 0.0, 1200.0 * delta
			)
			state_time -= delta
			if state_time <= 0.0:
				execute_attack()

		State.SLASH:
			velocity.x = facing_dir * slash_lunge_speed
			state_time -= delta
			if state_time <= 0.0:
				enter_recovery(0.3)

		State.CHARGE:
			var speed_multiplier = 1.3 if phase_two else 1.0
			velocity.x = facing_dir * charge_speed * speed_multiplier
			state_time -= delta
			if state_time <= 0.0:
				enter_recovery(0.4)

		State.RECOVER:
			velocity.x = move_toward(
				velocity.x, 0.0, 1500.0 * delta
			)
			state_time -= delta
			if state_time <= 0.0:
				state = State.CHASE

		State.STUNNED:
			# Boss cannot move or attack while parried.
			velocity.x = move_toward(
				velocity.x, 0.0, 1800.0 * delta
			)
			state_time -= delta
			play_animation("stunned", "idle")
			if state_time <= 0.0:
				state = State.CHASE
				sprite.modulate = get_phase_color()

		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()

	if state == State.CHARGE and is_on_wall():
		enter_recovery(0.4)

	# Poll overlaps so the attack can hit a player who was
	# already inside the area when the attack began.
	if attack_active:
		for body in attack_area.get_overlapping_bodies():
			try_hit_player(body)

	update_sprite_bob(delta)


# --------------------------------
# CHASE
# --------------------------------

func chase_player(delta: float) -> void:
	if not is_instance_valid(player):
		state = State.IDLE
		velocity.x = 0.0
		return

	var dx = player.global_position.x - global_position.x
	var distance_x = abs(dx)
	var distance_y = abs(
		player.global_position.y - global_position.y
	)

	if distance_x > detection_range * 1.5:
		state = State.IDLE
		velocity.x = 0.0
		return

	if abs(dx) > 5.0:
		update_facing(1 if dx > 0 else -1)

	if cooldown_left <= 0.0 \
	and distance_y <= 100.0 \
	and distance_x <= charge_start_range:
		if distance_x <= attack_range:
			if attack_count % 3 == 2:
				begin_windup(AttackType.SLAM)
			else:
				begin_windup(AttackType.SLASH)
		else:
			begin_windup(AttackType.CHARGE)
		return

	if distance_x > attack_range * 0.75:
		var speed_multiplier = 1.35 if phase_two else 1.0
		velocity.x = facing_dir * move_speed * speed_multiplier
		play_animation("walk")
	else:
		velocity.x = move_toward(
			velocity.x, 0.0, 1200.0 * delta
		)
		play_animation("idle")


# --------------------------------
# FACING DIRECTION
# --------------------------------

func update_facing(direction: int) -> void:
	if direction == 0:
		return

	facing_dir = direction

	# Original demon sprite faces LEFT.
	sprite.flip_h = facing_dir > 0

	# Move the Area2D, rather than scaling its collision shape.
	attack_area.position.x = facing_dir * attack_offset

	if slash_fx:
		slash_fx.position.x = facing_dir * attack_offset
		slash_fx.flip_h = facing_dir > 0


# --------------------------------
# ATTACK WARNING
# --------------------------------

func begin_windup(attack_type: AttackType) -> void:
	state = State.WINDUP
	current_attack = attack_type
	attack_count += 1
	velocity.x = 0.0
	attack_active = false

	sprite.scale = base_sprite_scale * Vector2(1.08, 0.94)

	match attack_type:
		AttackType.SLASH:
			state_time = 0.3
			sprite.modulate = Color(1.0, 0.65, 0.3)
		AttackType.CHARGE:
			state_time = 0.6
			sprite.modulate = Color(1.0, 0.35, 0.25)
		AttackType.SLAM:
			state_time = 0.8
			sprite.modulate = Color(0.8, 0.45, 1.0)

	play_animation("windup", "idle")


# --------------------------------
# EXECUTE ATTACK
# --------------------------------

func execute_attack() -> void:
	if is_dead or state != State.WINDUP:
		return

	sprite.scale = base_sprite_scale
	sprite.modulate = get_phase_color()
	hit_targets.clear()

	match current_attack:
		AttackType.SLASH:
			state = State.SLASH
			state_time = 0.25
			active_damage = attack_damage
			attack_active = true
			play_animation("attack")
			play_effect(slash_fx, "slash")

		AttackType.CHARGE:
			state = State.CHARGE
			state_time = 0.45
			active_damage = attack_damage
			if phase_two:
				active_damage += 1
			attack_active = true
			play_animation("attack2", "walk")

		AttackType.SLAM:
			attack_active = false
			play_animation("slam", "attack2")
			play_effect(slam_fx, "slam")
			apply_slam_damage()
			enter_recovery(0.6, true)


# --------------------------------
# DAMAGE TO PLAYER
# --------------------------------

func _on_attack_area_body_entered(body: Node2D) -> void:
	if attack_active:
		try_hit_player(body)


func try_hit_player(body: Node2D) -> void:
	if not attack_active or is_dead:
		return

	if not body is Player or body in hit_targets:
		return

	# Remember this target before calling take_damage,
	# since a parry can immediately change the boss's state.
	hit_targets.append(body)

	# Third argument tells the Player who can be parried.
	body.take_damage(active_damage, global_position, self)


# --------------------------------
# GROUND SLAM (JUMP TO AVOID)
# --------------------------------

func apply_slam_damage() -> void:
	if not is_instance_valid(player):
		return

	var distance_x = abs(
		player.global_position.x - global_position.x
	)

	# This attack cannot STUN the boss via parry.
	# The player can jump over it.
	if distance_x <= slam_radius and player.is_on_floor():
		player.take_damage(
			2 if phase_two else 1,
			global_position
		)


# --------------------------------
# RECOVERY
# --------------------------------

func enter_recovery(
	duration: float,
	keep_attack_animation: bool = false
) -> void:
	if is_dead or state == State.STUNNED:
		return

	attack_active = false
	state = State.RECOVER
	state_time = duration
	sprite.scale = base_sprite_scale
	sprite.modulate = get_phase_color()
	if not keep_attack_animation:
		play_animation("idle")

	cooldown_left = attack_cooldown
	if phase_two:
		cooldown_left *= 0.65


# --------------------------------
# PARRY / STUN
# --------------------------------

func on_parried() -> void:
	if is_dead or state == State.STUNNED:
		return

	# Only the sword slash and rush can be parried.
	if state != State.SLASH and state != State.CHARGE:
		return

	print("BOSS PARRIED!")

	# Immediately cancel the attack and its damage.
	attack_active = false
	hit_targets.clear()
	velocity.x = 0.0

	state = State.STUNNED
	state_time = parry_stun_duration
	cooldown_left = 0.0

	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	sprite.scale = base_sprite_scale
	sprite.modulate = Color(0.4, 0.8, 1.0)
	play_animation("stunned", "idle")


# --------------------------------
# PHASE TWO
# --------------------------------

func activate_phase_two() -> void:
	if phase_two or is_dead:
		return

	phase_two = true
	print("DEMON BOSS ENRAGED!")
	sprite.modulate = get_rest_color()
	cooldown_left = max(cooldown_left, 0.5)


func get_phase_color() -> Color:
	if phase_two:
		return Color(1.0, 0.6, 0.65)
	return Color.WHITE


func get_rest_color() -> Color:
	# Preserve the blue parry color while stunned,
	# including after taking sword damage.
	if state == State.STUNNED:
		return Color(0.4, 0.8, 1.0)
	return get_phase_color()


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

	if health_bar:
		health_bar.value = max(health, 0)

	if health <= 0:
		die()
		return

	if health <= max_health / 2.0:
		activate_phase_two()

	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	sprite.modulate = Color(1.0, 0.2, 0.2)
	flash_tween = create_tween()
	flash_tween.tween_property(
		sprite, "modulate", get_rest_color(), 0.15
	)


# --------------------------------
# SPRITE ANIMATIONS
# --------------------------------

func play_animation(
	animation_name: String,
	fallback: String = "idle"
) -> void:
	if sprite.sprite_frames == null:
		return

	var selected = animation_name
	if not sprite.sprite_frames.has_animation(selected):
		selected = fallback

	if not sprite.sprite_frames.has_animation(selected):
		return

	if sprite.animation != selected or not sprite.is_playing():
		sprite.play(selected)


func play_effect(
	effect: AnimatedSprite2D,
	animation_name: String
) -> void:
	if not is_instance_valid(effect):
		return
	if effect.sprite_frames == null:
		return
	if not effect.sprite_frames.has_animation(animation_name):
		return

	effect.sprite_frames.set_animation_loop(animation_name, false)
	effect.visible = true
	effect.play(animation_name)


func _on_slash_fx_animation_finished() -> void:
	if slash_fx:
		slash_fx.visible = false


func _on_slam_fx_animation_finished() -> void:
	if slam_fx:
		slam_fx.visible = false


# --------------------------------
# WALKING ANIMATION BOUNCE
# --------------------------------

func update_sprite_bob(delta: float) -> void:
	if state == State.CHASE \
	and abs(velocity.x) > 10.0 \
	and is_on_floor():
		walk_bob_time += delta * 15.0
		sprite.position.y = (
			base_sprite_position.y
			+ sin(walk_bob_time) * 1.5
		)
	else:
		sprite.position.y = move_toward(
			sprite.position.y,
			base_sprite_position.y,
			30.0 * delta
		)


# --------------------------------
# DEATH
# --------------------------------

func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = State.DEAD
	attack_active = false
	velocity = Vector2.ZERO

	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	collision_layer = 0
	collision_mask = 0

	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)

	attack_area.set_deferred("monitoring", false)
	sprite.scale = base_sprite_scale
	sprite.position = base_sprite_position
	sprite.modulate = Color.WHITE

	if sprite.sprite_frames.has_animation("death"):
		sprite.sprite_frames.set_animation_loop("death", false)
		sprite.play("death")
		await sprite.animation_finished
	else:
		sprite.modulate = Color(0.4, 0.4, 0.4, 0.7)
		await get_tree().create_timer(0.5).timeout

	queue_free()
