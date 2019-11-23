extends Area2D

# class member variables go here, for example:
export var module = 1

enum modules {shields, engine, power, cloak}

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass

var lookup_table = {"shields" : modules.shields, "engine" : modules.engine, "power" : modules.power}
func match_string(string):
	if lookup_table.has(string):
		return lookup_table[string]
	else:
		print("Error, no module matches string " + str(string))
		return null


func _on_debris_area_entered(area):
	if area.get_parent().get_groups().has("player"):
		print("debris entered by " + area.get_parent().get_name())
		
		# upgrade
		if module == modules.shields:
			print("Upgrading shields")
			area.shields = 150
			area.shield_level = 2
			area.emit_signal("module_level_changed", "shields", 2)
		elif module == modules.engine:
			print("Wants to upgrade engine")
			area.engine_level = 2
			area.emit_signal("module_level_changed", "engine", 2)
		elif module == modules.power:
			print("Wants to upgrade power")
			area.power_level = 2
			area.emit_signal("module_level_changed", "power", 2)
		elif module == modules.cloak:
			print("Added cloak module")
			area.has_cloak = true
		else:
			print("Not supported")
		
		
		queue_free()
		
	#pass # replace with function body
