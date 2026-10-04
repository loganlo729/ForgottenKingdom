extends CharacterBody2D

enum State { IDLE, WANDER, WINDUP, CHARGE, HIT }

const WALK_SPEED = 50.0
const CHARGE_SPEED = 300.0
const GRAVITY = 980.0

@onready var sprite = $AnimatedSprite2D
@onready var vision_ray = $VisionRay
@onready var state_timer = $StateTimer

var current_state = State.IDLE
var facing_direction = -1 
var wander_direction = -1

# HEALTH SYSTEM
var health: int = 3
var is_dead: bool = false

func _ready():
	pick_new_wander_state()
	# Connect the HurtBox signal to detect the player
	$HurtBox.body_entered.connect(_on_hurt_box_body_entered)

func _on_hurt_box_body_entered(body: Node2D):
	if body.name == "Player" and not is_dead and current_state == State.CHARGE:
		if body.has_method("take_damage"):
			# Deal 1 damage and pass the boar's position for knockback calculation
			body.take_damage(1, global_position)


func _physics_process(delta):
	# Don't do physics if dead
	if is_dead: return

	# Apply Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# State Machine Logic
	match current_state:
		State.IDLE:
			velocity.x = 0
			sprite.play("idle")
			check_for_player()
			if state_timer.time_left == 0:
				pick_new_wander_state()

		State.WANDER:
			velocity.x = wander_direction * WALK_SPEED
			sprite.play("walk")
			check_for_player()
			
			if is_on_wall():
				wander_direction *= -1
				update_facing(wander_direction)
				
			if state_timer.time_left == 0:
				pick_new_wander_state()

		State.WINDUP:
			velocity.x = 0
			sprite.play("windup")
			sprite.position.x = randf_range(-2, 2) 

		State.CHARGE:
			velocity.x = facing_direction * CHARGE_SPEED
			sprite.play("charge")
			
			if is_on_wall():
				sprite.position.x = 0 
				set_state(State.IDLE, 1.5) # Daze/Stunned 

		State.HIT:
			velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta)
			if state_timer.time_left == 0:
				sprite.modulate = Color(1, 1, 1) # Reset red flash color
				pick_new_wander_state()

	move_and_slide()

func set_state(new_state: State, duration: float = 0.0):
	current_state = new_state
	if duration > 0.0:
		state_timer.wait_time = duration
		state_timer.start()

func pick_new_wander_state():
	sprite.position.x = 0
	if randf() > 0.5:
		set_state(State.IDLE, randf_range(1.0, 2.5))
	else:
		wander_direction = -1 if randf() > 0.5 else 1
		update_facing(wander_direction)
		set_state(State.WANDER, randf_range(2.0, 4.0))

func update_facing(dir: int):
	facing_direction = dir
	sprite.flip_h = (dir == 1)
	vision_ray.target_position.x = abs(vision_ray.target_position.x) * dir

func check_for_player():
	if vision_ray.is_colliding():
		var collider = vision_ray.get_collider()
		if collider and collider.name == "Player":
			start_charge_sequence()

func start_charge_sequence():
	set_state(State.WINDUP, 0.6)
	if not state_timer.timeout.is_connected(_on_windup_finished):
		state_timer.timeout.connect(_on_windup_finished)

func _on_windup_finished():
	if current_state == State.WINDUP:
		state_timer.timeout.connect(_on_windup_finished)
		set_state(State.CHARGE)

# DAMAGE
func take_damage(amount: int, knockback_dir: Vector2):
	if is_dead: return
	
	health -= amount
	sprite.modulate = Color(1, 0.3, 0.3) # Turn red
	velocity = knockback_dir * 100.0 # Launch backwards
	
	if health <= 0:
		die()
	else:
		if current_state == State.CHARGE:
			sprite.position.x = 0 # Reset any shake offsets
			set_state(State.IDLE, 1.5) # Force into stunned IDLE state for 1.5 seconds
		else:
			# Normal hit stun response for when it's wandering or resting
			set_state(State.HIT, 0.2) 

func die():
	is_dead = true
	velocity = Vector2.ZERO
	sprite.play("idle") # Swap to death or fallback animation
	sprite.modulate = Color(0.2, 0.2, 0.2, 0.6) # Turn gray/transparent
	collision_layer = 0 # Stop collisions
	collision_mask = 0
