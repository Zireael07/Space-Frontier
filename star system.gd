extends Node2D

# class member variables go here, for example:
export var rotation_rate = 0.15
export var orbit_rate = 0.02

var rot = 0
var orbit_rot = 0

onready var sprite = $"Sprite"
onready var planets = $"planet_holder"

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
	
	# rotate the star sprite
	rot += rotation_rate * delta
	sprite.set_rotation(rot)
	
	orbit_rot += orbit_rate * delta
	planets.set_rotation(orbit_rot)
