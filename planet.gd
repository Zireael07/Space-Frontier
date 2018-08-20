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