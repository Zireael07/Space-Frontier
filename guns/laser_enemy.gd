extends RayCast2D


# Declare member variables here. Examples:
var dmg = 10


# Called when the node enters the scene tree for the first time.
func _ready():
	set_collide_with_areas(true)
	#pass # Replace with function body.

func start_at(dir, pos):
	# bullet's pointing to the side by default while the ship's pointing up
	set_rotation(dir-PI/2)
	set_position(pos)
	# pointing up by default
	#vel = Vector2(0,-speed).rotated(dir)

func _on_lifetime_timeout():
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var area = get_collider()
	# paranoia
	if not area:
		return
	
	if area.get_parent().get_groups().has("player") or area.get_groups().has("friendly"):
		queue_free()
		#print(area.get_parent().get_name())

		var pos = area.get_global_position()

		# do nothing if we hit a drone
		if not 'shields' in area:
			# show a visual effect
			area.dodge_effect()
			return
			
		# if the target is hauling a colony, it'll issue a distress call
		# IIRC it wasn't the case in original Stellar Frontier, but colonies are VERY important to us
		if area.get_colony_in_dock() != null:
			var col = area.get_colony_in_dock()
			#print("We hit a ship hauling a colony ", col)
			col.get_child(0).emit_signal("distress_called", get_parent().get_parent())
		#else:
		#	print("No colony")

		# go through armor first
		if 'armor' in area and area.armor > 0:
			# armor absorbs some of the damage
			var ar = int(floor(10/2))
			#print(str(ar))
			area.armor -= ar 
			area.emit_signal("armor_changed", area.armor)
		else:
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
			elif area.get_parent().is_in_group("player"):
				# reenable when it doesn't destroy the game
				#area.get_parent().queue_free()
				
				if not area.god:
					# just hide instead
					area.hide()
					# block (effectively disconnect) player HUD signals
					area.set_block_signals(true)
					# remove player arrow from minimap
					game.player.HUD.get_node("Control2/Panel_rightHUD/minimap").player_killed()
					area.dead = true
					
				get_parent().get_parent().emit_signal("target_killed", area)
			
			# update census
			if area.has_signal("ship_killed"):
				area.emit_signal("ship_killed", area)
	
			# explosion
			if "explosion" in area:
				var expl = area.explosion.instantiate()
				get_parent().get_parent().get_parent().add_child(expl)
				expl.set_global_position(pos)
				expl.play()
			
			# bugfix
			#get_parent().get_parent().shoot_target = null
			return
	
	if area.get_parent().get_groups().has("asteroid"):
		queue_free()
		
		#print(area.get_parent().get_name())
		
		var pos = area.get_global_position()
		
		# debris
		var deb = area.get_parent().resource_debris.instantiate()
		# randomize the resource
		var res = area.get_parent().select_random()
		# paranoia
		if res != null:
			deb.get_child(0).resource = res 
		# prevent a debugger message Can't change state while flushing queries
		call_deferred("spawn_debris", deb, pos)
		
		# explosion
		if 'explosion' in get_parent().get_parent():
			var expl = get_parent().get_parent().explosion.instantiate()
			get_parent().get_parent().get_parent().add_child(expl)
			expl.set_global_position(pos)
			expl.set_scale(Vector2(0.5, 0.5))
			expl.play()
		
		return
		
	if area.get_parent().is_in_group("colony"):
		if area.is_floating():
			#print("Colony hit!")
			area.emit_signal("distress_called", get_parent().get_parent())
			
			
			queue_free()
			
			if 'armor' in area:
				if area.armor > 0:
					area.armor -= 10
					area.emit_signal("armor_changed", area.armor)
				else:
					# kill the colony
					area.get_parent().queue_free()
					
					get_parent().get_parent().emit_signal("target_killed", area)
			
					var pos = area.get_global_position()
					# explosion
					var expl = get_parent().get_parent().explosion.instantiate()
					get_parent().get_parent().get_parent().add_child(expl)
					expl.set_global_position(pos)
					expl.set_scale(Vector2(0.5, 0.5))
					expl.play()
			return
		
		
func spawn_debris(deb, pos):
	get_parent().get_parent().get_parent().add_child(deb)
	deb.set_global_position(pos)
