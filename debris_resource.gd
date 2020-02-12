extends Area2D

# class member variables go here, for example:
export(int) var resource = 1

enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN}

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
		
		var res_id = elements.keys()[resource]
		#print("Picked up 1 unit of " + str(res_id))
		
		if not area.cargo.has(elements.keys()[resource]):
			# we don't have Dictionary.append, so just create
			area.cargo[res_id] = 1
		else:
			area.cargo[res_id] += 1
		
		# listing (player-only)
		area.update_cargo_listing(area.cargo)
		
		get_parent().queue_free()
		
	if area.get_groups().has("friendly"):
		print("debris entered by " + area.get_parent().get_name())
		
		var res_id = elements.keys()[resource]
		print("1 unit of " + str(res_id))
		
		if not area.cargo.has(elements.keys()[resource]):
			# we don't have Dictionary.append, so just create
			area.cargo[res_id] = 1
		else:
			area.cargo[res_id] += 1
		
		
		# trigger AI routines
		area.resource_picked()
		get_parent().queue_free()
