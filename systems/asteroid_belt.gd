tool
extends Node2D

# Declare member variables here. Examples:
export var radius = 0.2 # AU
export var num = 20

var asteroid_s = preload("res://asteroid.tscn")


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	var angle = randf() 
	for i in range(0, num):
		# spawn asteroid
		var ast = asteroid_s.instance()
		add_child(ast)
		
		# place one on the left, one on the right
		if i % 2 == 0:
			place(angle+90, radius, ast)
		else:
			place(angle-90, radius, ast)
		
			# increase angle in degrees
			angle += 15
	
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func place(angle,dist,child):
	print("Place : a " + str(angle) + " dist: " + str(dist) + " AU")
	var d = dist*game.AU
	var pos = Vector2(0, d).rotated(deg2rad(angle))
	print("vec: 0, " + str(d) + " rot: " + str(deg2rad(angle)))
	print("Position is " + str(pos))
	#get_parent().get_global_position() + 
	
	child.set_position(pos)
