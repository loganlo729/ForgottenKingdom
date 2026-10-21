extends Node2D
class_name UILayer

var keys: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	keys = [$CanvasLayer/Key1, $CanvasLayer/Key2]
	var player: Player = get_tree().get_first_node_in_group("Player") as Player


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for i in range(keys.size()):
		if Player.hasKeys[i]:
			keys[i].visible = true
		else:
			keys[i].visible = false

func add_key(keyNum):
	if keyNum >= 0 and keyNum < keys.size() and keys[keyNum] != null:
		keys[keyNum].visible = true
	
func remove_key(keyNum):
	if keyNum >= 0 and keyNum < keys.size() and keys[keyNum] != null:
		keys[keyNum].visible = false
