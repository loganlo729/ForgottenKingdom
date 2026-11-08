extends Area2D

func _ready():
	$AnimatedSprite2D.play("torch")
	
func _process(_delta):
	$PointLight2D.energy = randf_range(0.8, 1.2)
