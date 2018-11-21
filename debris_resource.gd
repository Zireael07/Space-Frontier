extends Area2D

# class member variables go here, for example:
export var resource = 1

enum elements {CARBON, IRON, MAGNESIUM, SILICON}

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


func _on_debris_area_entered(area):
	if area.get_parent().get_groups().has("player"):
		print("debris entered by " + area.get_parent().get_name())
		
		print("Picked up 1 unit of " + str(elements.keys()[resource]))
		
		
		queue_free()
		
	#pass # replace with function body
