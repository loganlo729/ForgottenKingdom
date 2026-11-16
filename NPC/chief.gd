extends Area2D

@export var idle_interval := 20.0

var intro: Array = [
	"Chief: Child... is that a living soul from the world above?",
	"Chief: Come closer, child. You look tired and far from home.",
	"Chief: Ask me what you wish."
]

var done_lines: Array = [
	"Chief: Our people are preparing to leave, child. Thank you."
]

# Each stage must be fully asked before the next one appears.
var stages: Array = [
	[
		{"ask": "Why are you all hiding down here?", "answer": [
			"You: Why are you all hiding down here?",
			"Chief: We are not hiding from the cold, child.",
			"Chief: A demon hunted us. It sought the death of every one of us.",
			"Chief: So we fled beneath the earth, where it could not find us."
		]}
	],
	[
		{"ask": "What are these giant walls around us?", "answer": [
			"You: What are these giant walls around us?",
			"Chief: Those walls are what keep us alive, child.",
			"Chief: They are magic, and they hide us from the demon.",
			"Chief: But magic like that has a price. Many of our people sacrificed themselves to build them.",
			"Chief: Every stone is a life we honor."
		]},
		{"ask": "How is there light down here?", "answer": [
			"You: How is there light down here?",
			"Chief: There was already a deep cave here, with light shining into it.",
			"Chief: When we raised the walls, we left an opening at the very top, just for the light.",
			"Chief: The magic hides that opening from the demon, so only the light passes through."
		]}
	],
	[
		{"ask": "I killed the demon.", "answer": [
			"You: Chief... the demon is dead.",
			"You: I found the key, opened the great door, and fought it at the gate. In the end, it fell.",
			"Chief: ...What did you say, child?",
			"Chief: Then the sacrifices were not in vain.",
			"Chief: You have freed us. The last of our people can finally leave the underground.",
			"Chief: We will see the sun again because of you."
		]}
	]
]

enum State { IDLE, TALKING, CHOOSING }
var state := State.IDLE
var stage := 0
var asked: Array = []
var current_lines: Array = []
var index := 0
var intro_done := false
var finished := false
var player: Node2D
var player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$Prompt.visible = false
	$DialogueBox.visible = false
	_idle_loop()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player = body
		player_inside = true
		$Prompt.visible = state == State.IDLE

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = false
		$Prompt.visible = false
		if state != State.IDLE:
			_end_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or not event.is_action_pressed("Interact"):
		return
	match state:
		State.IDLE:
			player.set_physics_process(false)
			if finished:
				_start_lines(done_lines)
			elif not intro_done:
				intro_done = true
				_start_lines(intro)
			else:
				_show_choices()
		State.TALKING:
			_next_line()
		State.CHOOSING:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()

func _start_lines(lines: Array) -> void:
	state = State.TALKING
	current_lines = lines
	index = 0
	$Prompt.visible = false
	$DialogueBox.visible = true
	$DialogueBox/Choices.visible = false
	$DialogueBox/Panel/Text.text = current_lines[0]

func _next_line() -> void:
	index += 1
	if index < current_lines.size():
		$DialogueBox/Panel/Text.text = current_lines[index]
	elif finished:
		_end_dialogue()
	else:
		_show_choices()

func _show_choices() -> void:
	state = State.CHOOSING
	$DialogueBox.visible = true
	$Prompt.visible = false
	$DialogueBox/Panel/Text.text = "Chief: ..."
	var choices := $DialogueBox/Choices
	for c in choices.get_children():
		choices.remove_child(c)
		c.queue_free()
	for option in stages[stage]:
		if option["ask"] in asked:
			continue
		var b := Button.new()
		b.text = option["ask"]
		b.pressed.connect(_pick.bind(option))
		choices.add_child(b)
	choices.visible = true
	choices.get_child(0).grab_focus()

func _pick(option: Dictionary) -> void:
	asked.append(option["ask"])
	if asked.size() >= stages[stage].size():
		stage += 1
		asked.clear()
		if stage >= stages.size():
			finished = true
	_start_lines(option["answer"])

func _end_dialogue() -> void:
	state = State.IDLE
	$DialogueBox.visible = false
	$Prompt.visible = player_inside
	if player:
		player.set_physics_process(true)
		
func _idle_loop() -> void:
	while true:
		$AnimatedSprite2D.play("idle")
		await $AnimatedSprite2D.animation_finished
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.frame = 0
		await get_tree().create_timer(idle_interval).timeout

func _process(_delta: float) -> void:
	if state == State.IDLE or player == null:
		return
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	var panel: Control = $DialogueBox/Panel
	var choices: Control = $DialogueBox/Choices
	panel.position = screen_pos + Vector2(-panel.size.x / 2.0, 40)
	choices.position = panel.position + Vector2(0, panel.size.y + 8)
