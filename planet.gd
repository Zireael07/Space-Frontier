tool
extends Node2D

# class member variables go here, for example:
export(float) var planet_rad_factor = 1.0

#export(int) var angle = 0 setget setAngle #, getAngle
#export(int) var dist = 100 setget setDist #, getDist

export(Vector2) var data setget setData

const LIGHT_SEC = 400	# must match LIGHT_SPEED for realism
const LS_TO_AU = 30 #500 realistic value
const AU = LS_TO_AU*LIGHT_SEC

var population = 100000
	
var targetted = false
signal planet_targeted

func _ready():
	var dist = get_position().length()
	
	var ls = dist/LIGHT_SEC
	
	print("Dist to parent star" + str(dist) + " " + str(ls) + " ls, " + str(ls/LS_TO_AU) + " AU")
	
	
	# Called when the node is added to the scene for the first time.
	# Initialization here
	#pass

func setData(val):
	if Engine.is_editor_hint() and val != null:
		print("Data: " + str(val))
		place(val[0], val[1])


func place(angle,dist):
	print("Place : a " + str(angle) + " d: " + str(dist))
	var pos = Vector2(0, dist).rotated(deg2rad(angle))
	print("vec: 0, " + str(dist) + " rot: " + str(deg2rad(angle)))
	print("Position is " + str(pos))
	#get_parent().get_global_position() + 
	
	set_position(pos)

#func setAngle(val):
#	print("Set angle to : " + str(val))
#	var pos = Vector2(0, dist).rotated(deg2rad(val))
#	print("vec: 0, " + str(dist) + " rot: " + str(deg2rad(val)))
#	print("Position is " + str(pos))
#
#	#place(val, getDist())
#
#func setDist(val):
#	print("Set dist to: " + str(val))
#	var pos = Vector2(0, val).rotated(deg2rad(angle))
#	print("vec: 0, " + str(val) + " rot: " + str(deg2rad(angle)))
#
#
#	print("Position is " + str(pos))
#
#	#place(getAngle(), val)
#
#func getAngle():
#	return angle
#
#func getDist():
#	return dist


func _process(delta):
	
	# redraw
	#update()

	# straighten out labels
	if get_parent().is_class("Node2D"):
		#print("Parent is a Node2D")
		$"Label".set_rotation(-get_parent().get_rotation())
	
		if has_node("Sprite_shadow"):
			$"Sprite_shadow".set_rotation(-get_parent().get_rotation())
	
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


func _draw():
	# debugging
	if Engine.is_editor_hint():
	#	draw_line(Vector2(0,0), Vector2(-get_position()), Color(1,0,0))
		pass	
	
	
	else:
		# draw a red rectangle around the target
		#if game.player.HUD.target == self:
		# because we're a tool script and tool scripts can't use autoloads
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
	if event is InputEventMouseButton and event.pressed:
		#if not targetted:
		#targetted = true
		emit_signal("planet_targeted", self)
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
