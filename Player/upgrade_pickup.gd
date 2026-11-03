@tool
extends Area2D

enum UpgradeType {
	AIR_DASH,
	DOUBLE_JUMP,
	LONG_SWORD,
	WALL_JUMP
}

@export var upgrade_type: UpgradeType = UpgradeType.DOUBLE_JUMP

@export var custom_text: String = "Default Text":
	set(value):
		custom_text = value
		update_label()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label


func update_label() -> void:
	var label_node = get_node_or_null("Label") as Label

	if label_node:
		label_node.text = custom_text


func _ready() -> void:
	update_label()

	# Don't execute gameplay logic in the editor.
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)

	# Hide pickups that have already been collected.
	if is_already_unlocked():
		queue_free()


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

	return false


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return

	match upgrade_type:
		UpgradeType.AIR_DASH:
			Upgrades.unlock("air_dash")

		UpgradeType.DOUBLE_JUMP:
			Upgrades.unlock("double_jump")

		UpgradeType.LONG_SWORD:
			Upgrades.unlock("long_sword")
			
		UpgradeType.WALL_JUMP:
			Upgrades.unlock("wall_jump")

	queue_free()
