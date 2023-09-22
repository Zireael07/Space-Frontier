extends Area2D

var dmg = 15
var flash = preload("res://mine_flash_friendly.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_entered(area):
	if 'warping' in area and area.warping:
		return
	
	if area.get_groups().has("enemy"):
		queue_free()
		
		# this is mine-specific
		var fl = flash.instantiate()
		fl.get_node("AnimationPlayer").play("new_animation")
		fl.global_position = area.global_position
		area.get_parent().get_parent().add_child(fl)
		
		print(area.get_parent().get_name(), " triggered a mine!!!")
		
		var pos = area.get_global_position()
		
		# go through armor first
		if 'armor' in area and area.armor > 0:
			# armor absorbs some of the damage
			var ar = int(floor(dmg/2))
			#print(str(ar))
			area.armor -= ar 
			area.emit_signal("armor_changed", area.armor)
		else:
			area.shields -= dmg
			# emit signal
			area.emit_signal("shield_changed", [area.shields])
		
		var sb = area.is_in_group("starbase")
		if sb:
			area.emit_signal("distress_called", get_parent().get_parent())
		
			# explosion hint when starbase is hit
			if "explosion" in area:
				var expl = area.explosion.instantiate()
				#print(get_parent().get_parent().get_parent().get_name())
				get_parent().get_parent().get_parent().add_child(expl)
				# A->B = B-A
				var h_pos = pos+((get_global_position()-pos).limit_length(50))
				expl.set_global_position(h_pos) # our position, not base's
				expl.set_scale(Vector2(0.5,0.5))
				expl.play()
		
		# shields dropped
		if area.shields <= 0:
			# status light update
			if 'targeted_by' in get_parent().get_parent():
				print("Update status light on AI death")
				var find = get_parent().get_parent().targeted_by.find(area)
				if find != -1:
					get_parent().get_parent().targeted_by.remove(find)
				if get_parent().get_parent().targeted_by.size() < 1:
					area.emit_signal("target_lost_AI", area)			
			
			# mark is as no longer orbiting
			if 'orbiting' in area and area.orbiting != null:
				print("AI killed, no longer orbiting")
				area.orbiting.get_parent().remove_orbiter(area)
			
			# kill the AI
			area.get_parent().queue_free()
			# update census
			if area.has_signal("ship_killed"):
				area.emit_signal("ship_killed", area)

			# untarget it
			game.player.HUD.target = null
			# hide the target panel HUD
			game.player.HUD.hide_target_panel()
			# hide the direction indicator
			game.player.get_node("target_dir").hide()
			
	#pass # Replace with function body.
