extends Area2D

# class member variables go here, for example:
var vel = Vector2()
export var speed = 1000

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func _physics_process(delta):
	set_position(get_position() + vel * delta)

func start_at(dir, pos):
	# bullet's pointing to the side by default while the ship's pointing up
	set_rotation(dir-PI/2)
	set_position(pos)
	# pointing up by default
	vel = Vector2(0,-speed).rotated(dir)

func _on_lifetime_timeout():
	queue_free()