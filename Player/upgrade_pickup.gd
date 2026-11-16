
@tool
extends Area2D

enum UpgradeType {
	AIR_DASH,
	DOUBLE_JUMP,
	LONG_SWORD,
	WALL_JUMP,
	TORCHY
}

@export var upgrade_type: UpgradeType = UpgradeType.DOUBLE_JUMP

@export var custom_text: String = "Default Text":
	set(value):
		custom_text = value
		update_label()

# Leave blank to use the default tutorial.
@export var tutorial_title: String = ""
@export_multiline var tutorial_text: String = ""

# Leave empty to use the upgrade's default action.
@export var tutorial_action: StringName = &""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label

var collected: bool = false
var closing_tutorial: bool = false

var tutorial_overlay: CanvasLayer
var dimmer: ColorRect
var tutorial_panel: PanelContainer


# --------------------------------
# INITIALIZATION
# --------------------------------

func _ready() -> void:
	update_label()

	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)

	if is_already_unlocked():
		queue_free()


func update_label() -> void:
	var label_node = get_node_or_null("Label") as Label

	if label_node:
		label_node.text = custom_text


# --------------------------------
# UPGRADE INFORMATION
# --------------------------------

func get_upgrade_title() -> String:
	if not tutorial_title.is_empty():
		return tutorial_title

	match upgrade_type:
		UpgradeType.AIR_DASH:
			return "AIR DASH UNLOCKED"

		UpgradeType.DOUBLE_JUMP:
			return "DOUBLE JUMP UNLOCKED"

		UpgradeType.LONG_SWORD:
			return "LONG SWORD UNLOCKED"

		UpgradeType.WALL_JUMP:
			return "WALL JUMP UNLOCKED"
			
		UpgradeType.TORCHY:
			return "TORCHY UNLOCKED"

	return "UPGRADE UNLOCKED"


func get_tutorial_text() -> String:
	if not tutorial_text.is_empty():
		return tutorial_text

	match upgrade_type:
		UpgradeType.AIR_DASH:
			return (
				"You can now dash while airborne!\n"
				+ "Use your dash to cross larger gaps."
			)

		UpgradeType.DOUBLE_JUMP:
			return (
				"You can now jump twice!\n"
				+ "Press Jump again while in the air."
			)

		UpgradeType.LONG_SWORD:
			return (
				"Your sword's reach has increased!\n"
				+ "Attack enemies from farther away."
			)

		UpgradeType.WALL_JUMP:
			return (
				"You can now slide down walls!\n"
				+ "Press Jump while touching a wall "
				+ "to leap away from it."
			)
		
		UpgradeType.TORCHY:
			return (
				"You can now summon Torchy!\n"
				+ "Press F to light up your surroundings!"
			)

	return "A new ability has been unlocked!"


func get_required_action() -> StringName:
	if tutorial_action != &"":
		return tutorial_action

	match upgrade_type:
		UpgradeType.AIR_DASH:
			return &"dash"

		UpgradeType.DOUBLE_JUMP:
			return &"jump"

		UpgradeType.LONG_SWORD:
			return &"attack"

		UpgradeType.WALL_JUMP:
			return &"jump"
			
		UpgradeType.WALL_JUMP:
			return &"flashlight"

	return &"jump"


func get_action_key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action)

	var events = InputMap.action_get_events(action)

	# Prefer keyboard keys.
	for event in events:
		if event is InputEventKey:
			return event.as_text() \
				.replace(" - Physical", "") \
				.replace("(Physical)", "") \
				.strip_edges()

	# Fallback for controller or mouse inputs.
	if events.size() > 0:
		return events[0].as_text() \
			.replace(" - Physical", "") \
			.replace("(Physical)", "") \
			.strip_edges()

	return String(action)


# --------------------------------
# UPGRADE STATUS
# --------------------------------

func is_already_unlocked() -> bool:
	match upgrade_type:
		UpgradeType.AIR_DASH:
			return Upgrades.has_air_dash

		UpgradeType.DOUBLE_JUMP:
			return Upgrades.has_double_jump

		UpgradeType.LONG_SWORD:
			return Upgrades.has_long_sword

		UpgradeType.WALL_JUMP:
			return Upgrades.has_wall_jump
			
		UpgradeType.TORCHY:
			return Upgrades.has_torchy

	return false


# --------------------------------
# PICKUP
# --------------------------------

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return

	if collected:
		return

	collected = true

	# This pickup must keep processing input
	# while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Prevent collecting the pickup again.
	set_deferred("monitoring", false)

	match upgrade_type:
		UpgradeType.AIR_DASH:
			Upgrades.unlock("air_dash")

		UpgradeType.DOUBLE_JUMP:
			Upgrades.unlock("double_jump")

		UpgradeType.LONG_SWORD:
			Upgrades.unlock("long_sword")

		UpgradeType.WALL_JUMP:
			Upgrades.unlock("wall_jump")
		
		UpgradeType.TORCHY:
			Upgrades.unlock("torchy")

	# Hide the physical pickup.
	hide()

	# Display the tutorial.
	show_upgrade_tutorial()

	# Freeze the game.
	get_tree().paused = true


# --------------------------------
# TUTORIAL OVERLAY
# --------------------------------

func show_upgrade_tutorial() -> void:

	# CanvasLayer renders above gameplay.
	tutorial_overlay = CanvasLayer.new()
	tutorial_overlay.layer = 100

	# Keep the tutorial active during pause.
	tutorial_overlay.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	get_tree().root.add_child(tutorial_overlay)

	# --------------------------------
	# DARK SCREEN OVERLAY
	# --------------------------------

	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0)

	tutorial_overlay.add_child(dimmer)

	dimmer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	dimmer.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	# --------------------------------
	# CENTERED CONTAINER
	# --------------------------------

	var center = CenterContainer.new()

	tutorial_overlay.add_child(center)

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	center.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	# --------------------------------
	# TUTORIAL PANEL
	# --------------------------------

	tutorial_panel = PanelContainer.new()

	tutorial_panel.custom_minimum_size = (
		Vector2(550, 200)
	)

	center.add_child(tutorial_panel)

	# Panel styling.
	var panel_style = StyleBoxFlat.new()

	panel_style.bg_color = Color(
		0.07, 0.08, 0.12, 0.95
	)

	panel_style.border_color = Color(
		0.8, 0.75, 0.45
	)

	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)

	tutorial_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	# --------------------------------
	# MARGINS
	# --------------------------------

	var margin = MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left", 28
	)
	margin.add_theme_constant_override(
		"margin_right", 28
	)
	margin.add_theme_constant_override(
		"margin_top", 24
	)
	margin.add_theme_constant_override(
		"margin_bottom", 24
	)

	tutorial_panel.add_child(margin)

	# --------------------------------
	# VERTICAL LAYOUT
	# --------------------------------

	var column = VBoxContainer.new()

	column.add_theme_constant_override(
		"separation", 16
	)

	margin.add_child(column)

	# --------------------------------
	# TITLE
	# --------------------------------

	var title_label = Label.new()

	title_label.text = get_upgrade_title()

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size", 26
	)

	title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.4)
	)

	column.add_child(title_label)

	# --------------------------------
	# DESCRIPTION
	# --------------------------------

	var description_label = Label.new()

	description_label.text = get_tutorial_text()

	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	description_label.add_theme_font_size_override(
		"font_size", 17
	)

	column.add_child(description_label)

	# --------------------------------
	# INPUT PROMPT
	# --------------------------------

	var action = get_required_action()
	var key_name = get_action_key_name(action)

	var prompt_label = Label.new()

	prompt_label.text = (
		"Press [" + key_name + "] to continue"
	)

	prompt_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	prompt_label.add_theme_font_size_override(
		"font_size", 16
	)

	prompt_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.85, 1.0)
	)

	column.add_child(prompt_label)

	# --------------------------------
	# FADE IN
	# --------------------------------

	tutorial_panel.modulate.a = 0.0

	var tween = create_tween()

	# Tween must run while gameplay is paused.
	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tween.tween_property(
		dimmer,
		"color:a",
		0.6,
		0.25
	)

	tween.parallel().tween_property(
		tutorial_panel,
		"modulate:a",
		1.0,
		0.25
	)


# --------------------------------
# WAIT FOR INPUT
# --------------------------------

func _input(event: InputEvent) -> void:
	if not collected or closing_tutorial:
		return

	if event is InputEventKey and event.echo:
		return

	var required_action = get_required_action()

	if event.is_action_pressed(required_action):
		get_viewport().set_input_as_handled()
		close_upgrade_tutorial()


# --------------------------------
# CLOSE TUTORIAL
# --------------------------------

func close_upgrade_tutorial() -> void:
	if closing_tutorial:
		return

	closing_tutorial = true

	var tween = create_tween()

	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	# Fade the background back out.
	tween.tween_property(
		dimmer,
		"color:a",
		0.0,
		0.2
	)

	tween.parallel().tween_property(
		tutorial_panel,
		"modulate:a",
		0.0,
		0.2
	)

	await tween.finished

	# Resume gameplay.
	get_tree().paused = false

	# Remove the overlay.
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.queue_free()

	# Remove the collected pickup.
	queue_free()
