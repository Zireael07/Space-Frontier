extends Area2D

# class member variables go here, for example:
@export var module = 1

enum modules {shields, engine, power, cloak}

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass

var lookup_table = {"shields" : modules.shields, "engine" : modules.engine, "power" : modules.power, "cloak" : modules.cloak}
func match_string(string):
	if lookup_table.has(string):
		return lookup_table[string]
	else:
		print("Error, no module matches string " + str(string))
		return null


func _on_debris_area_entered(area):
	if area.get_parent().is_in_group("player") and not area.warping:
		print("player entered debris")
		
		# upgrade
		if module == modules.shields:
			if area.shield_level == 2:
				if area.get_parent().is_in_group("player"):
					area.emit_signal("officer_message", "Shields 2 cannot be upgraded to shields 2")
				return
			
			print("Upgrading shields")
			area.shields = 150
			area.shield_level = 2
			area.emit_signal("module_level_changed", "shields", 2)
		elif module == modules.engine:
			print("Wants to upgrade engine")
			area.engine_level = 2
			area.thrust = 0.3 * area.LIGHT_SPEED
			area.max_vel = 0.6 * area.LIGHT_SPEED
			area.emit_signal("module_level_changed", "engine", 2)
		elif module == modules.power:
			print("Wants to upgrade power")
			area.power_level = 2
			area.power = 150
			area.emit_signal("module_level_changed", "power", 2)
		elif module == modules.cloak:
			if area.has_cloak:
				if area.get_parent().is_in_group("player"):
					area.emit_signal("officer_message", "Cloak module cannot be upgraded to cloak")
			else:
				print("Added cloak module")
				area.has_cloak = true
				if area.get_parent().is_in_group("player"):
					area.emit_signal("officer_message", "A new cloak module was installed")
		else:
			print("Not supported")
		
		
		get_parent().queue_free()
		
	if area.is_in_group("friendly") and not area.is_in_group("drone") and not area.landed:
		print("Debris entered by " + area.get_name())
		
		#TODO: upgrade NPC ship
		
		get_parent().queue_free()
	#pass # replace with function body
