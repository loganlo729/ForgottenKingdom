extends CharacterBody2D

# SPEED / DASH CONFIG
const SPEED = 150.0
const RUN_SPEED = 250.0
const JUMP_VELOCITY = -380.0
var LAUNCH_SPEED = 500.0
const DASH_DURATION = 0.12 
const DASH_COOLDOWN = .6 

# COMBO CONFIG
const ATTACK_DURATION = 0.25   
const COMBO_WINDOW = 0.55     
const FINISHER_LUNGE_SPEED = 350.0 

# JUMP CONFIG
const MAX_JUMPS = 2           

# GUARD CONFIGURATION
const GUARD_DURATION = .3
const GUARD_COOLDOWN = .5

@onready var sprite = $AnimatedSprite2D
@onready var attack_box = $BaseAttackBox 

var is_dashing = false
var dash_time_left = 0.0
var dash_cooldown_left = 0.0 

# COMBO VARIABLES
var is_attacking = false
var attack_time_left = 0.0
var combo_count = 0
var combo_time_left = 0.0
var has_air_attacked = false  # Tracks if an air attack combo was used this jump

# JUMP VARIABLES
var jumps_left = 0

# GUARD VARIABLES
var is_guarding = false
var guard_time_left = 0.0
var guard_cooldown_left = 0.0

func _physics_process(delta):
	# Reset jump charges and air attack limits after landing
	if is_on_floor():
		jumps_left = MAX_JUMPS
		has_air_attacked = false

	# GRAVITY LOGIC
	if not is_on_floor() and not is_attacking:
		velocity += get_gravity() * delta

	# Process active dash duration
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			is_dashing = false

	# Process active cooldown countdown
	if dash_cooldown_left > 0:
		dash_cooldown_left -= delta

	# Process active attack duration
	if is_attacking:
		attack_time_left -= delta
		if attack_time_left <= 0:
			is_attacking = false
			attack_box.monitoring = false 
			combo_time_left = COMBO_WINDOW

	# Process combo reset window 
	if not is_attacking and combo_count > 0:
		combo_time_left -= delta
		if combo_time_left <= 0:
			combo_count = 0 

	var direction = Input.get_axis("move_left", "move_right")

	# Flip the BaseAttackBox position to match where the player looks
	if direction != 0 and not is_attacking and not is_dashing:
		attack_box.scale.x = -1 if direction < 0 else 1

	# HANDLE JUMP & DOUBLE JUMP
	if Input.is_action_just_pressed("jump") and not is_attacking:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1
		elif jumps_left > 0:
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1
			is_dashing = false 
	
	# Trigger guard
	if is_guarding:
		guard_time_left -= delta
		# If the player releases the button OR runs out of guard time
		if not Input.is_action_pressed("guard") or guard_time_left <= 0:
			is_guarding = false
			guard_cooldown_left = GUARD_COOLDOWN # Trigger cooldown upon exit
	else:
		# Lessen guard cooldown when not guarding
		if guard_cooldown_left > 0:
			guard_cooldown_left -= delta
	
	# HANDLE GUARD
	if Input.is_action_pressed("guard") and not is_guarding and guard_cooldown_left <= 0 and not is_dashing and not is_attacking:
			is_guarding = true
			guard_time_left = GUARD_DURATION

		
	# Trigger the combo chain
	if Input.is_action_just_pressed("attack") and not is_dashing and not is_attacking:
		# Check if the player is allowed to execute an air attack
		var can_attack = true
		if not is_on_floor() and has_air_attacked and combo_count == 0:
			can_attack = false
			
		if can_attack:
			is_attacking = true
			attack_time_left = ATTACK_DURATION
			attack_box.monitoring = true 
			
			# AIR ATTACK FREEZE
			if not is_on_floor():
				velocity.y = 0
				has_air_attacked = true # Lock further air combinations for this jump cycle
			
			# Set baseline horizontal momentum for hits 1 and 2
			velocity.x = 0 
			
			# Advance combo state
			if combo_count == 0:
				combo_count = 1
			elif combo_count == 1:
				combo_count = 2
			elif combo_count == 2:
				combo_count = 3
				var lunge_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
				velocity.x = lunge_dir.x * FINISHER_LUNGE_SPEED
			else:
				combo_count = 1 

	# Trigger the dash 
	if Input.is_action_just_pressed("run") and not is_dashing and dash_cooldown_left <= 0 and not is_attacking:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown_left = DASH_COOLDOWN 
		
		var forward_dir = Vector2.LEFT if $AnimatedSprite2D.flip_h else Vector2.RIGHT
		
		if Input.is_action_pressed("move_down"):
			forward_dir *= -1
		
		velocity.x = forward_dir.x * LAUNCH_SPEED

	# MOVEMENT LOGIC
	if is_dashing:
		pass
	elif is_attacking:
		if not is_on_floor():
			velocity.x = 0
			velocity.y = 0
		elif combo_count == 3:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
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

	# ANIMATION LOGIC
	if is_attacking:
		sprite.play("attack" + str(combo_count)) 
	elif not is_on_floor():
		sprite.play("jump") 
	elif is_dashing:
		sprite.play("run")
	elif direction != 0 && abs(velocity.x) >= 200:
		sprite.play("run")
	elif direction != 0:
		sprite.play("walk")
	elif is_guarding == true:
		sprite.play("guard")
	else:
		sprite.play("idle")

	move_and_slide()
