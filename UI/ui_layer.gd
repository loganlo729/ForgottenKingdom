extends Node2D
class_name UILayer

var keys: Array = []
var player: Player

func _ready():
	keys = [$CanvasLayer/Key1, $CanvasLayer/Key2]
	player = get_tree().get_first_node_in_group("Player") as Player

func _process(delta):
	if player == null:
		return
	for i in range(keys.size()):
		keys[i].visible = player.hasKeys[i]

func add_key(keyNum):
	if keyNum >= 0 and keyNum < keys.size() and keys[keyNum] != null:
		keys[keyNum].visible = true
	
func remove_key(keyNum):
	if keyNum >= 0 and keyNum < keys.size() and keys[keyNum] != null:
		keys[keyNum].visible = false
