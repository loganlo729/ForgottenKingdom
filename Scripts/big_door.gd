extends StaticBody2D

@export_file("*.tscn") var next_scene: String
@export var spawn_name: String = ""

@onready var sprite = $AnimatedSprite2D

var player_near := false
var opened := false

func _ready():
	$InteractArea.body_entered.connect(_on_enter)
	$InteractArea.body_exited.connect(_on_exit)

func _on_enter(body):
	if body.is_in_group("Player"):
		player_near = true

func _on_exit(body):
	if body.is_in_group("Player"):
		player_near = false

func _process(_delta):
	if player_near and not opened and Input.is_action_just_pressed("Interact"):
		if GameState.has_boss_key:
			open()
		else:
			print("Key needed")

func open():
	opened = true
	sprite.play("open")
	await sprite.animation_finished
	Global.spawn_name = spawn_name
	SceneTransition.change_scene(next_scene)
