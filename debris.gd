extends Area2D

# class member variables go here, for example:
export var module = 1

enum modules {shields, engine, power}

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
		
		# upgrade
		if module == modules.shields:
			print("Upgrading shields")
			area.shields = 150
		elif module == modules.engine:
			print("Wants to upgrade engine")
		elif module == modules.power:
			print("Wants to upgrade power")
		else:
			print("Not supported")
		
		
		queue_free()
		
	#pass # replace with function body
