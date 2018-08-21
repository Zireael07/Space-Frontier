extends Node2D

# class member variables go here, for example:
var targetted = false
signal planet_targeted

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

#func _process(delta):
	
	# redraw
	#update()
	
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass

# draw a red rectangle around the target
func _draw():
	if targetted:
		var tr = get_child(0)
		var rc_h = tr.get_texture().get_height() * tr.get_scale().x
		var rc_w = tr.get_texture().get_height() * tr.get_scale().y
		var rect = Rect2(Vector2(-rc_w/2, -rc_h/2), Vector2(rc_w, rc_h))
		
		#var rect = Rect2(Vector2(-26, -26),	Vector2(91*0.6, 91*0.6))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		#if not targetted:
		targetted = true
		emit_signal("planet_targeted")
		#else:
		#	targetted = false
			
		# redraw
		update()

func reparent(area):
	area.get_parent().get_parent().remove_child(area.get_parent())
	add_child(area.get_parent())

func reposition(area):
	area.get_parent().set_position(Vector2(0,0))

func _on_Area2D_area_entered(area):
	if area.get_parent().is_in_group("colony"):
		print("Colony entered planet space")
		# prevents looping (area collisions don't exclude children!)
		if not self == area.get_parent().get_parent():
			print("Colony isn't parented to us")
			if area.get_parent().get_parent().get_parent().is_in_group("player"):
				print("Colony being hauled by player")
			else:
				print("Colony released")
				if not has_node("colony"):
					print("Adding colony to planet")
					# add colony to planet
					# prevent crash
					call_deferred("reparent", area)
					# must happen after reparenting
					call_deferred("reposition", area)
				else:
					print("We already have a colony")
		else:
			print("Colony is already ours")
	
	pass # replace with function body
