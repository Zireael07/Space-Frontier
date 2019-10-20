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

func _on_bullet_area_entered( area ):
	if area.get_parent().get_groups().has("player") or area.get_groups().has("friendly"):
		queue_free()
		print(area.get_parent().get_name())

		var pos = area.get_global_position()

		# prevent negative shields
		if area.shields > 0:
			area.shields -= 10
			# emit signal
			area.emit_signal("shield_changed", [area.shields])
		
		if area.shields <= 0:
			if area.get_groups().has("friendly"):
				
				# mark is as no longer orbiting
				if area.orbiting != null:
					print("AI killed, no longer orbiting")
					area.orbiting.get_parent().remove_orbiter(area)
				
				# kill the AI
				area.get_parent().queue_free()
			
			# kill the player
			# reenable when it doesn't destroy the game
			#area.get_parent().queue_free()
	
			# explosion
			var expl = get_parent().get_parent().explosion.instance()
			get_parent().get_parent().add_child(expl)
			expl.set_global_position(pos)
			expl.play()
			
			# bugfix
			#get_parent().get_parent().shoot_target = null