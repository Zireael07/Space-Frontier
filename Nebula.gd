@tool
extends Sprite2D

# class member variables go here, for example:
@export var seede = 1234567 : set = set_seed

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	texture.set_size_override(Vector2i(1150, 768*2))
	
	randomize()
	#seede = randi()
	
	var s = randi()
	set_seed(s)
	
	seede = s
	print("Seed" + str(seede))
	
	#pass

func set_seed(value):
	rand_from_seed(value)
	
	var off =  [randf() * 100, randf() * 100]
	var scale_n = (randf() * 2 + 1) / get_texture().get_height()
	# shaders don't know the Godot color type
	var color = Vector3(randf(), randf(), randf())
	var color2 = Vector3(randf(), randf(), randf())
	var density = randf() * 0.2
	var falloff = randf() * 2.0 + 3.0
	
	print("Set up values: " + str(off) + " " + str(scale_n) + " " + str(color) + " " + str(density) + " " + str(falloff))
	
	var m = get_material()
	
	m.set_shader_parameter("offset", off)
	m.set_shader_parameter("scale", scale_n)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("color2", color2)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("falloff", falloff)
	
	print("Sent values to shader")
	
	
	#pass


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
