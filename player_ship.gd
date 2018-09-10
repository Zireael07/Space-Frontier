extends Area2D

# class member variables go here, for example:
const LIGHT_SPEED = 400 # original Stellar Frontier seems to have used 200 px/s

export var rot_speed = 2.6 #radians
export var thrust = 0.25 * LIGHT_SPEED
export var max_vel = 0.5 * LIGHT_SPEED
export var friction = 0.25

# motion
var rot = 0
var pos = Vector2()
var vel = Vector2()
var acc = Vector2()

var spd = 0

var orbit_rate = 0.04
var orbit_rot = 0
var orbiting = false

# shields
var shields = 100
signal shield_changed
var shield_level = 1
var engine_level = 1
var power_level = 1
signal module_level_changed


# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"
onready var explosion = preload("res://explosion.tscn")
onready var debris = preload("res://debris_enemy.tscn")

var target = null
var tractor = null
var heading = null
var warp_target = null

var HUD = null

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	pass


# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	spd = vel.length() / LIGHT_SPEED

	# shoot
	if Input.is_action_pressed("shoot"):
		if gun_timer.get_time_left() == 0:
			shoot()

	# tractor
	if tractor:
		var dist = get_global_position().distance_to(tractor.get_child(0).get_global_position())
		
		# too far away, deactivate
		if dist > 100:
			tractor.get_child(0).tractor = null
			tractor = null
			print("Deactivating tractor")
			
		else:
			#print("Tractor active on: " + str(tractor.get_name()) + " " + str(dist))
			tractor.get_child(0).tractor = self

	if orbiting:		
		#print("Orbiting... " + str(orbiting))
		orbit_rot += orbit_rate * delta
		orbiting.set_rotation(orbit_rot)
		#print("Gl pos " + str(get_global_position()) + "parent" + str(get_parent().get_global_position()))

	# rotations
	if Input.is_action_pressed("ui_left"):
		rot -= rot_speed*delta
	if Input.is_action_pressed("ui_right"):
		rot += rot_speed*delta
	# thrust
	if Input.is_action_pressed("ui_up"):
		# deorbit
		if orbiting:
			var rel_pos = get_global_transform().xform_inv(orbiting.get_parent().get_global_position())
			print("Deorbiting, relative to planet " + str(rel_pos) + " " + str(rel_pos.length()))
			orbiting = null
			
			print("Deorbiting, " + str(get_global_position()) + str(get_parent().get_global_position()))
			
			# reparent
			var root = get_node("/root/Control")
			var gl = get_global_position()
			
			get_parent().get_parent().remove_child(get_parent())
			root.add_child(get_parent())
			
			get_parent().set_global_position(gl)
			set_position(Vector2(0,0))
			pos = Vector2(0,0)
			
			set_global_rotation(get_global_rotation())
		else:
			if warp_target == null:
				acc = Vector2(0, -thrust).rotated(rot)
				$"engine_flare".set_emitting(true)
	else:
		acc = Vector2(0,0)
		$"engine_flare".set_emitting(false)
	
	if not orbiting:
		# movement happens!
		# modify acc by friction dependent on vel
		acc += vel * -friction
		vel += acc *delta
		# prevent exceeding max speed
		vel = vel.clamped(max_vel)
		pos += vel * delta
		set_position(pos)
		#print("Setting position" + str(pos))
	
	# warp drive!
	if not heading and warp_target != null:
		var desired = warp_target - get_global_position()
		var dist = desired.length()
		
		if dist > LIGHT_SPEED:
			vel = Vector2(0, -LIGHT_SPEED).rotated(rot)
			pos += vel* delta
			# prevent accumulating
			vel = vel.clamped(LIGHT_SPEED)
			set_position(pos)
		else:
			# we've arrived, return to normal space
			warp_target = null
		
	# rotation
	# handling the warp-drive heading
	if heading:
		var rel_pos = get_global_transform().xform_inv(warp_target)
		
		var a = atan2(rel_pos.x, rel_pos.y)
		
		# we've turned to face the target
		if abs(rad2deg(a)) > 179:
			heading = null
		
		if a < 0:
			rot -= rot_speed*delta
		else:
			rot += rot_speed*delta
			
			
		
	set_rotation(rot)
	
	# fix jitter due to camera updating one frame late
	get_node("Camera2D").align()
	

func _input(event):
	if Input.is_action_pressed("closest_target"):
		get_closest_target()
	
	if Input.is_action_pressed("orbit"):
		#print("Try to orbit")
		var pl = get_closest_planet()
		# values are eyeballed for current planets
		if pl[0] > 300:
			print("Too far away to orbit")
		elif pl[0] < 200:
			print("Too close to orbit")
		else:
			print("Can orbit")
			if pl[1].has_node("orbit_holder"):
				
				pl[1].get_node("orbit_holder").set_rotation(0)
				orbit_rot = 0
				# nuke any velocity left
				vel = Vector2(0,0)
				acc = Vector2(0,0)
				
				var rel_pos = get_global_transform().xform_inv(pl[1].get_global_position())
				var dist = pl[1].get_global_position().distance_to(get_global_position())
				print("Dist: " + str(dist))
				print("Relative to planet: " + str(rel_pos) + " dist " + str(rel_pos.length()))
				
				if dist > pl[0] + 20: #fudge factor
					print("Mismatch in perceived distances!")
					return
				
				# reparent
				get_parent().get_parent().remove_child(get_parent())
				pl[1].get_node("orbit_holder").add_child(get_parent())
				print("Reparented")
			
				get_parent().set_position(Vector2(0,0))
				#set_position(Vector2(0,0))
				set_position(rel_pos)
				var a = atan2(rel_pos.x, rel_pos.y)
				#var a = fix_atan(rel_pos.x, rel_pos.y)
				print("Initial angle " + str(a))
				
				orbiting = pl[1].get_node("orbit_holder")
				orbiting.set_rotation(a)
				orbit_rot = a
	
	if Input.is_action_pressed("tractor"):
		# toggle
		if not tractor:
		#tractor = true
			# TODO: closest colony
			tractor = get_tree().get_nodes_in_group("colony")[0]
		else:
			tractor = null

	if Input.is_action_pressed("undock_tractor"):
		print("Undock pressed")
		
		tractor = null
		
		# we normally have 7 children nodes
		# TODO: is there a way to check if any child is in group and return the first?
		if get_child_count() > 7 and get_child(8).is_in_group("colony"):
			var col = get_child(8)
			print("We have a colony in dock")
			
			# undock
			remove_child(col)
			get_parent().get_parent().add_child(col)
			
			# restore original z
			col.set_z_index(0)
			
			col.set_global_position(get_node("dock").get_global_position() + Vector2(0, 20))
			
			print("Undocked")


func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())

func get_closest_planet():
	var planets = get_tree().get_nodes_in_group("planets")
	
	var dists = []
	var targs = [] # otherwise we have no way of knowing which planet the dist refers to
	
	for p in planets:
		var dist = p.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, p])
		
	dists.sort()
	
	for t in targs:
		if t[0] == dists[0]:
			print("Closest planet is: " + t[1].get_name() + " at " + str(t[0]))
			return t

func get_closest_target():
	var nodes = get_tree().get_nodes_in_group("enemy")
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			print("Target is : " + t[1].get_parent().get_name())
			t[1].targetted = true
			t[1].emit_signal("AI_targeted")
			# redraw 
			t[1].update()
			
			#return t[1]
			

# draw a red rectangle around the target
func _draw():
	if target == self:
		var rect = Rect2(Vector2(-35, -25),	Vector2(112*0.6, 75*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		target = self
		# redraw 
		update()

func _on_goto_pressed():
	print("Want to go to planet")
	warp_target = get_tree().get_nodes_in_group("planets")[1].get_global_position()
	heading = true
	



# atan2(0,-1) returns 180 degrees in 3.0, we want 0
# this counts in radians
func fix_atan(x,y):
	var ret = 0
	var at = atan2(x,y)

	if at > 0:
		ret = at - PI
	else:
		ret= at + PI
	
	return ret