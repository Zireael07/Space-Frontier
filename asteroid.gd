extends Node2D

# class member variables go here, for example:
var elements = { CARBON = 0, IRON = 1, MAGNESIUM = 2, SILICON = 3 }
var contains = []
var resource_debris = preload("res://debris_resource.tscn")

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	contains.append(elements.CARBON)
	contains.append(elements.IRON)
	contains.append(elements.SILICON)
	
	
	#pass

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
