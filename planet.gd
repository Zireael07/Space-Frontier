tool
extends Node2D

# class member variables go here, for example:
export(float) var planet_rad_factor = 1.0

#export(int) var angle = 0 setget setAngle #, getAngle
#export(int) var dist = 100 setget setDist #, getDist

export(Vector2) var data setget setData

export(float) var mass = 1 # in Earth masses
var radius = 1.0 # in Earth radius
var gravity = 1.0 # in Earth gravity
export(float) var hydro = 0.3 # water/land ratio (surface, not volume = 30% for Earth)
var albedo = 0.3 # test value Bond albedo, ranges from 0 to 1
var temp = 0 # in Kelvin

var dist = 0

var population = 0
	
var targetted = false
signal planet_targeted

signal planet_orbited
var orbiters = []
var orbiter
var orbit_rot = 0
var orbit_rate = 0.04
export(bool) var tidally_locked = false

signal planet_colonized

onready var module = preload("res://debris_enemy.tscn")

# Called when the node is added to the scene for the first time.
# Initialization here
func _ready():
	set_z_index(game.PLANET_Z)
	
	connect("planet_orbited", self, "_on_planet_orbited")
	
	
	dist = get_position().length()
	
	var ls = dist/game.LIGHT_SEC
	
	print("Dist to parent star" + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	calculate_orbit_period()
	
	temp = calculate_temperature()
	
	# type is the parameter, skipped for now
	radius = calculate_radius()
	gravity = calculate_gravity(mass, radius)
	
	if has_colony():
		population = 100000

# Kepler's Third Law:
# The square of the period of any planet is proportional to the cube of the semi-major axis of its orbit.
# t^2 = au^3 if period is in years and axis is in AU
func calculate_orbit_period():
	# gravitational constant
	var G = (6.67428e-11)
	
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	
	# by default, the equation works on seconds, meters and kilograms
	var AU = 149597870691 #meters
	var yr = 3.15581e7 #seconds (86400 for a day)
	var sun = 5.027399e-31 #kg
	
	# T = 2*PI*sqrt(a^3/GM) [ substitute (M1+M2) for M if we're talking binary system ]
	var t = 2*PI*sqrt(pow(axis*AU, 3)/G*sun) # in seconds
	
	#print(str(t/86400) + " days, " + str(t/yr) + " year(s)")
	return t

func is_habitable():
	var star = get_parent().get_parent()
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	if axis >= star.hz_inner and axis <= star.hz_outer:
		return true
	else:
		return false

# Radiative equilibrium tempetature
func calculate_temperature():
	var star = get_parent().get_parent()
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	# https://spacemath.gsfc.nasa.gov/astrob/6Page61.pdf
	# T = 273*((L(1-a) / D2)^0.25)
	var t = star.luminosity*(1-albedo) / pow(axis,2)
	var T = 273 * pow(t, 0.25)
	return T

# https://arxiv.org/pdf/1603.08614v2.pdf (Jingjing, Kipping 2016)
func calculate_radius(type="rocky"):
	randomize()
	# <= 2 masses of Earth
	if type == "rocky":
		var radius = pow(mass, 0.28)
		# fudge
		var max_dev = radius*0.04 # 4% max spread
		radius = rand_range(radius-max_dev, radius+max_dev)
		return radius
	# others (not implemented yet)
	# Neptunian = <= 130 masses of Earth
	# radius = pow(mass, 0.59)
	# max spread 15%
	# Jovian = < 0.08 Sun masses
	# all the [Jovian] worlds have almost the same radius
	# radius = pow(mass, -0.04)
	# max spread 8%
	# anything above that is a star so needn't apply
	else:
		return 1 # dummy

# if we have mass and radius, we get gravity as a bonus
func calculate_gravity(mass, radius):
	# measured in multiplies of Earth's mass and radius and therefore gravity
	# g = m/r^2 
	return mass/pow(radius, 2)


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
	update()

	# straighten out labels
	if get_parent().is_class("Node2D"):
		#print("Parent is a Node2D")
		$"Label".set_rotation(-get_parent().get_rotation())
	
		if has_node("Sprite_shadow"):
			#var angle_to_star = atan2(self.get_position().x, self.get_position().y)
			# we have to use this because there are rotations to consider
			var angle_to_star = get_tree().get_nodes_in_group("star")[0].get_global_position().angle_to(get_global_position())
			#print("Angle to star: "+ str(angle_to_star))
			$"Sprite_shadow".set_rotation(angle_to_star)
	
	# planets handle orbiting now	
	if has_node("orbit_holder"):
		if orbiters.size() > 0:
			orbit_rot += orbit_rate * delta
			get_node("orbit_holder").set_rotation(orbit_rot)
	
	
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

		# test
		if orbiters.size() > 0:
			for o in orbiters:
				var tg = get_global_transform().xform_inv(o.get_global_position())
				draw_line(Vector2(0,0), tg, Color(1,0,0), 6.0, true)
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
	area.get_child(0).set_z_index(1)

func _on_Area2D_area_entered(area):
	if area.get_parent().is_in_group("colony"):
#		print("Colony entered planet space")
		# prevents looping (area collisions don't exclude children!)
		if not self == area.get_parent().get_parent():
#			print("Colony isn't parented to us")
			if area.get_parent().get_parent().get_parent().is_in_group("player"):
				print("Colony being hauled by player")
			else:
				# colony is free-floating (because the player just let go)
				if not 'brain' in area.get_parent().get_parent():
					# colonize
					AI_do_colonize(area)
				else:
					var brain = area.get_parent().get_parent().brain
					if brain != null:
						#print("Colony hauled by AI")
						if brain.get_state() == brain.STATE_COLONIZE:
							# is it the colonization target?
							var id = brain.get_state_obj().param
							print("Colonize id is: " + str(id))
							if get_tree().get_nodes_in_group("planets")[id] == self:
								print("We are the colonize target")
								AI_do_colonize(area)			

		else:
			print("Colony is already ours")

func AI_do_colonize(area):
#	print("Colony released")
	if not has_node("colony") and not has_colony():
		population = 50000
		emit_signal("planet_colonized", self)
		# it wants the top node, not the area itself
		area.emit_signal("colony_colonized", area.get_parent())
		print("Adding colony to planet")
		# add colony to planet
		# prevent crash
		call_deferred("reparent", area)
		# must happen after reparenting
		call_deferred("reposition", area)
	else:
		print("We already have a colony")
		# add to population
		population += 50000
		area.get_parent().queue_free()	



func _on_planet_orbited(ship):
	orbiter = ship
	orbiters.append(orbiter)
	print("Planet orbited " + str(get_name()) + " orbiter " + str(orbiter.get_parent().get_name()))

	var rel_pos = get_node("orbit_holder").get_global_transform().xform_inv(orbiter.get_global_position())
	
	
	orbiter.get_parent().set_position(Vector2(0,0))
	orbiter.set_position(Vector2(0,0))
	orbiter.pos = Vector2(0,0)

	print("Rel pos: " + str(rel_pos))
	orbiter.set_position(rel_pos)
	
	var a = atan2(rel_pos.x, rel_pos.y)
#	var a = atan2(200,0)

	print("Initial angle " + str(a))
	
	# redraw (debugging)
	update()

func remove_orbiter(ship):
	orbiters.remove(orbiters.find(ship))

func has_colony():
	var ret = false
	for c in get_children():
		if c.is_in_group("colony") or c.is_in_group("enemy_col"):
			ret = c.get_groups()[0]

	return ret

func _on_pop_timer_timeout():
	if has_colony():
		print("Pop increase")
		population += 1000
#	else:
#		print("No colony?")


func enough_modules():
	var enough = true
	var count = 0
	for c in get_parent().get_children():
		if c.is_in_group("debris"):
			count = count + 1
	
	if count < 2:
		enough = false
	else:
		enough = true
	
	print("Enough modules: " + str(enough))
	return enough

func _on_module_timer_timeout():
	if has_colony() and not enough_modules():
		print("Module timer")
		var pos = get_global_position()
		var mo = module.instance()
		mo.get_child(0).module = 3 # cloak
		get_parent().add_child(mo)
		# slight offset
		var offset = Vector2(10,10)
		mo.set_global_position(pos+offset)
		mo.set_z_index(2)
