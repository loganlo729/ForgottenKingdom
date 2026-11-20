
extends Node

signal upgrade_unlocked(upgrade_name: String)


#var has_air_dash: bool = false
#var has_double_jump: bool = false
#var has_long_sword: bool = false
#var has_wall_jump: bool = false
#var has_torchy: bool = false

var has_air_dash: bool = true
var has_double_jump: bool = true
var has_long_sword: bool = true
var has_wall_jump: bool = true
var has_torchy: bool = true

func unlock(upgrade_name: String) -> void:
	match upgrade_name:
		"air_dash":
			has_air_dash = true
		"double_jump":
			has_double_jump = true
		"wall_jump":
			has_wall_jump = true
		"long_sword":
			has_long_sword = true
		"torchy":
			has_long_sword = true
		_:
			push_warning("Unknown upgrade: " + upgrade_name)
			return

	upgrade_unlocked.emit(upgrade_name)
