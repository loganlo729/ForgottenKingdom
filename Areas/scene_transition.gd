extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var busy := false

func _ready() -> void:
	layer = 100
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	var t = create_tween()
	t.tween_property(rect, "color:a", 1.0, 0.4)
	await t.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 = create_tween()
	t2.tween_property(rect, "color:a", 0.0, 0.4)
	await t2.finished
	busy = false
