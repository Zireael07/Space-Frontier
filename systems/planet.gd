tool
extends Node2D

# class member variables go here, for example:
export(float) var planet_rad_factor = 1.0

#export(int) var orbit_angle setget setOrbitAngle #, getAngle
#export(int) var dist = 100 setget setDist #, getDist

export(Vector2) var data #setget setData

export(float) var mass = 1 # in Earth masses
var radius = 1.0 # in Earth radius
var gravity = 1.0 # in Earth gravity
export(float) var hydro = 0.3 # water/land ratio (surface, not volume = 30% for Earth)
var albedo = 0.3 # test value Bond albedo, ranges from 0 to 1
var temp = 0 # in Kelvin
export(float) var atm = 0.0 # in Earth atmospheres
export(float) var greenhouse = 0.0 # greenhouse coefficient from 0 to 1, see: http://phl.upr.edu/library/notes/surfacetemperatureofplanets

var dist = 0

export(float) var population = 0.0 # in millions
	
var targetted = false
signal planet_targeted

signal planet_orbited
var orbiters = []
var orbiter
var orbit_rot = 0
var orbit_rate = 0.04
export(bool) var tidally_locked = false
var axis_rot = 0.0


signal planet_colonized

onready var module = preload("res://debris_enemy.tscn")

var labl_loc = Vector2()

# Called when the node is added to the scene for the first time.
# Initialization here
func _ready():
	#print("Planet init")
	set_z_index(game.PLANET_Z)
	connect("planet_orbited", self, "_on_planet_orbited")
	
	labl_loc = $"Label".get_position()
	
	# debug old positions
#	dist = get_position().length()
#	var ls = dist/game.LIGHT_SEC
#	print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	#setup()

func setup(angle=0, dis=0):
	if angle != 0 or dis !=0:
		# place
		place(angle, dis)
	
	dist = get_position().length()
	var ls = dist/game.LIGHT_SEC
	print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	# moon fix
	if is_in_group("moon"):
		# can't be both a moon and a planet
		if is_in_group("planets"):
			remove_from_group("planets")
		mass = 0.0123 #Earth masses
	else:
		temp = calculate_temperature()
		calculate_orbit_period()
	
	# type is the parameter
	if mass > 300:
		radius = calculate_radius("jovian")
	else:
		# default. i.e. rocky
		radius = calculate_radius()
	gravity = calculate_gravity(mass, radius)
	
	# set population for planets that start colonized
	# if we set population from editor, don't change it
	if has_colony() and population == 0.0:
		if is_in_group("moon"):
			population = float(50/1000.0)
		else:
			population = float(100/1000.0)

	
	# recalculate temp for our moons last
	if has_moon():
		for m in get_moons():
			m.temp = m.calculate_temperature()
			m.calculate_orbit_period()

# Kepler's Third Law:
# The square of the period of any planet is proportional to the cube of the semi-major axis of its orbit.
# t^2 = au^3 if period is in years and axis is in AU
func calculate_orbit_period():
	# gravitational constant
	var G = (6.67428e-11)
	
	var dist = self.dist
	if is_in_group("moon"):
		dist = dist/10 # eyeballed scale
	
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	#print("Axis: " + str(axis))
	
	# by default, the equation works on seconds, meters and kilograms
	var AU = 149597870691 #meters
	var yr = 3.15581e7 #seconds (86400 for a day)
	var sun = 5.027399e-31 #kg
	
	# if we're a moon, substitute planet mass
	if is_in_group("moon"):
		sun = 1.6740324e-25 # kg, one Earth mass
		#var moon_mass = mass*sun
		#sun = sun + moon_mass # to be extra correct
	
	# T = 2*PI*sqrt(a^3/GM) [ substitute (M1+M2) for M if we're talking binary system ]
	var t = 2*PI*sqrt(pow(axis*AU, 3)/G*sun) # in seconds
	
	#print(str(t/86400) + " days, " + str(t/yr) + " year(s)")
	return t

func is_habitable():
	var star = get_parent().get_parent()
	if not 'hz_inner' in star:
		return false # dummy
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	if axis >= star.hz_inner and axis <= star.hz_outer:
		return true
	else:
		return false

func greenhouse_diff():
	# return early if no greenhouse effect at all
	if greenhouse == 0.0:
		return 0.0
		
	var equilibrium_temp = calculate_temperature(false)
	var real_temp = calculate_temperature()
	
	return real_temp - equilibrium_temp

# Radiative equilibrium tempetature + greenhouse effect
func calculate_temperature(inc_greenhouse=true):
	if self.dist == 0:
		print("Bad distance! " + get_name())
		return 273 # dummy
	
	
	var dist_t = self.dist # to avoid overwriting
	var greenhouse = self.greenhouse # to be able to fake 0 effect if needed
	var star = get_parent().get_parent()
	# if we're a moon, look up the star and take distance of our parent
	if get_parent().get_parent().is_in_group("planets"):
		star = get_parent().get_parent().get_parent().get_parent()
		dist_t = self.dist + get_parent().get_parent().dist
		
	if not 'luminosity' in star:
		return 273 #dummy
		
	var axis = (dist_t/game.LIGHT_SEC)/game.LS_TO_AU
	
	# https://spacemath.gsfc.nasa.gov/astrob/6Page61.pdf
	# T = 273*((L(1-a) / D2)^0.25)
	# where L = star luminosity
	
	if inc_greenhouse == false:
		greenhouse = 0
	
	# http://phl.upr.edu/library/notes/surfacetemperatureofplanets
	# T = 273*((L(1-a)) / D2*(1-g))
	var t = star.luminosity*(1-albedo) / (pow(axis,2) * (1-greenhouse))
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
	if type == "jovian":
		# all the [Jovian] worlds have almost the same radius
		radius = pow(mass, -0.04)
		# fudge
		var max_dev = radius*0.08 # # max spread 8%
		radius = rand_range(radius-max_dev, radius+max_dev)
		return radius
	
	# anything above that is a star so needn't apply
	else:
		return 1 # dummy

# if we have mass and radius, we get gravity as a bonus
func calculate_gravity(mass, radius):
	# measured in multiplies of Earth's mass and radius and therefore gravity
	# g = m/r^2 
	return mass/pow(radius, 2)

# d = m/V; V = (4/3) π R3
func get_density(mass, radius):
	var vol = (4/3)*PI*pow(radius, 3)
	return mass/vol

# so many things from mass and radius!
# sqrt(G * M / r)
func get_cosmic_vel(mass, radius):
	var G = 0.0000000000667
	var vel = sqrt(G*mass/radius)
	return vel # value relative to the Earth's cosmic vel since mass & radius are expressed as relative
	

# for now, this is just the ESI (Earth Similarity Index)
# http://www.extrasolar.de/en/cosmopedia/planets.0011.esi
func calculate_habitability():
	var rad = (1.0 - abs((radius - 1.0) / (radius + 1.0)))
	var ESI_radius = pow(rad, 0.57)
	var Earth_density = get_density(1.0, 1.0)
	var density = get_density(mass, radius)
	var dens = (1.0 - abs((density - Earth_density) / (density + Earth_density)))
	var ESI_density = pow(dens, 1.07)
	var ESI_interior = sqrt(ESI_radius*ESI_density)
	var Earth_temp = 287 # in Kelvin (15 Celsius)
	var temp_fact = (1.0 - abs((temp - Earth_temp) / (temp + Earth_temp))) 
	var ESI_temp = pow(temp_fact, 5.58)
	var Earth_vel = get_cosmic_vel(1.0, 1.0)
	var vel = get_cosmic_vel(mass, radius)
	var vel_fact = (1.0 - abs((vel - Earth_vel) / (vel + Earth_vel))) 
	var ESI_vel = pow(vel_fact, 0.7)
	var ESI_exterior = sqrt(ESI_temp*ESI_vel)
	
	var ESI = sqrt(ESI_interior*ESI_exterior)
	if ESI < 0.0:
		ESI = 0.0
		
	return ESI

func setData(val):
	if Engine.is_editor_hint() and val != null:
		#print("Data: " + str(val))
		place(val[0], val[1])


func place(angle,dist):
	print("Place : a " + str(angle) + " d: " + str(dist))
	var pos = Vector2(0, dist).rotated(deg2rad(angle))
	#print("vec: 0, " + str(dist) + " rot: " + str(deg2rad(angle)))
	print("Position is " + str(pos))
	#get_parent().get_global_position() + 
	
	set_position(pos)

#func setOrbitAngle(val):
#	print("Set angle to : " + str(val))
#	var pos = Vector2(0, dist).rotated(deg2rad(val))
#	print("vec: 0, " + str(dist) + " rot: " + str(deg2rad(val)))
#	print("Position is " + str(pos))
#
#	set_position(pos)
	#place(val, getDist())

#func setDist(val):
#	print("Set dist to: " + str(val))
#	var pos = Vector2(0, val).rotated(deg2rad(orbit_angle))
#	print("vec: 0, " + str(val) + " rot: " + str(deg2rad(orbit_angle)))
#
#
#	print("Position is " + str(pos))
#
#	set_position(pos)
#
#	#place(getAngle(), val)

#func getAngle():
#	return orbit_angle
#
#func getDist():
#	return dist

#	# Called every frame. Delta is time since last frame.
func _process(delta):
	# rotate around our axis
	axis_rot = axis_rot + 0.1*delta
	# don't exceed 2
	if axis_rot + 0.1*delta > 2:
		axis_rot = 2 - axis_rot + 0.1*delta
	# paranoia
	if get_node("Sprite").get_material() != null:
		get_node("Sprite").get_material().set_shader_param("time", axis_rot)
	
	# redraw
	update()

	
	if get_parent().is_class("Node2D"):
		#print("Parent is a Node2D")
		# straighten out labels
		if not Engine.is_editor_hint():
			$"Label".set_rotation(-get_parent().get_rotation())
			
			# get the label to stay in one place from player POV
			var angle = -get_parent().get_rotation() + deg2rad(45) # because the label is located at 45 deg angle...
			# effectively inverse of atan2()
			var angle_loc = Vector2(cos(angle), sin(angle))
			#Controls don't have transforms so we have to manually set position
			$"Label"._set_position(angle_loc*labl_loc.length())
	
		if has_node("Sprite_shadow"):
			#var angle_to_star = atan2(self.get_position().x, self.get_position().y)
			# we have to use this because there are rotations to consider
			#var angle_to_star = get_tree().get_nodes_in_group("star")[0].get_global_position().angle_to(get_global_position())
			var rel_loc = get_tree().get_nodes_in_group("star")[0].get_global_position() - get_global_position()
			var a = atan2(rel_loc.x, rel_loc.y)
			# add 180 deg to point at the star, not away
			var angle_to_star = (-a+3.141593)
			#var angle_to_star = fix_atan(rel_loc.x, rel_loc.y)
			#print("Angle to star: "+ str(angle_to_star))
			
			$"Sprite_shadow".set_global_rotation(angle_to_star)
	
	if not Engine.is_editor_hint():
		# planets handle orbiting now	
		if has_node("orbit_holder"):
			# if orbiters or moon
			if orbiters.size() > 0 or has_moon():
				orbit_rot += orbit_rate * delta
				get_node("orbit_holder").set_rotation(orbit_rot)
	
	

#	# Update game logic here.
#	pass

func has_moon():
	var ret = false
	for c in get_node("orbit_holder").get_children():
		if c.is_in_group("moon"):
			ret = true
	#print("Has moon: " + str(ret))
	return ret

func get_moons():
	var moons = []
	for c in get_node("orbit_holder").get_children():
		if c.is_in_group("moon"):
			moons.append(c)
			
	return moons

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
func _on_Area2D_input_event(_viewport, event, _shape_idx):
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
		#print("Colony entered planet space")
		# prevents looping (area collisions don't exclude children!)
		if not self == area.get_parent().get_parent():
			#print("Colony isn't parented to us")
			if area.get_parent().get_parent().get_parent().is_in_group("player"):
				print("Colony being hauled by player")
			else:
				# colony is free-floating (because the player just let go)
				if not 'brain' in area.get_parent().get_parent():
					# colonize
					do_colonize(area)
				else:
					var brain = area.get_parent().get_parent().brain
					if brain != null:
						#print("Colony hauled by AI")
						if brain.get_state() == brain.STATE_COLONIZE:
							# is it the colonization target?
							var id = brain.get_state_obj().planet_
							print("[Colonize] Colonize id is: " + str(id))
							# id is the real id+1 to avoid problems with state param being 0 (= null)
							if get_tree().get_nodes_in_group("planets")[id-1] == self:
								print("[Colonize] We are the colonize target, id " + str(id))
								do_colonize(area)			

		else:
			print("Colony is already ours")

func do_colonize(area):
#	print("Colony released")
	if not has_node("colony") and not has_colony():
		population = area.population # in millions
		#population = 50/1000.0 # in milions
		emit_signal("planet_colonized", self)
		# reward if there's someone to be rewarded
		if area.to_reward != null:
			# currently to_reward is player-only
			area.to_reward.credits = area.to_reward.credits + 50000
			print("[CREDITS] Cr: " + str(area.to_reward.credits))
			# points
			area.to_reward.points = area.to_reward.points + 10
			area.to_reward.emit_signal("points_gained", area.to_reward.points)
			# rank up!
			area.to_reward.rank = area.to_reward.rank + 1
			
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
		population += area.population
		#population += 50/1000.0 # in milions
		area.get_parent().queue_free()	

	# does it put us over the "can hand out colonists" threshold?
	# does it have enough pop for a colony?
	if population > 51/1000.0: # in milions
		update_HUD_colony_pop(self, true)


func _on_planet_orbited(ship):
	orbiter = ship
	orbiters.append(orbiter)
	print("Planet orbited " + str(get_node("Label").get_text()) + "; orbiter: " + str(orbiter.get_parent().get_name()))

	var rel_pos = get_node("orbit_holder").get_global_transform().xform_inv(orbiter.get_global_position())
	
	
	orbiter.get_parent().set_position(Vector2(0,0))
	orbiter.set_position(Vector2(0,0))
	orbiter.pos = Vector2(0,0)

	#print("Rel pos: " + str(rel_pos))
	orbiter.set_position(rel_pos)
	
	var a = atan2(rel_pos.x, rel_pos.y)
#	var a = atan2(200,0)

	#print("Initial angle " + str(a))
	
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

func update_HUD_colony_pop(planet, add):
	var node = null
	var hud = game.player.HUD
	# get label
	for l in hud.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").get_children():
		# because ordering in groups cannot be relied on 100%
		if l.get_text().find(planet.get_node("Label").get_text()) != -1:
			node = l.get_name()
	
	if node:
		var parent = hud.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo")
		if add:
			if parent.get_node(node).get_text().find("^") == -1:
				parent.get_node(node).set_text(parent.get_node(node).get_text() + " ^ ")
		else:
			# remove flag
			if parent.get_node(node).get_text().find("^") != -1:
				var text = parent.get_node(node).get_text()
				parent.get_node(node).set_text(text.rstrip(" ^ "))


func _on_pop_timer_timeout():
	if has_colony():
		print("Pop increase")
		population += 1/1000.0 # in milions
	
	# does it have enough pop for a colony?
	if population > 51/1000.0: # in milions
		update_HUD_colony_pop(self, true)

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
