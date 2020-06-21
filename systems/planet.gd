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
export(float) var ice = 0.0 # how much of the surface is covered by ice (eyeballed for most planets)
var albedo = 0.3 # test value Bond albedo, ranges from 0 to 1
var temp = 0 # in Kelvin
export(float) var atm = 0.0 # in Earth atmospheres
export(float) var greenhouse = 0.0 # greenhouse coefficient from 0 to 1, see: http://phl.upr.edu/library/notes/surfacetemperatureofplanets

var dist = 0

export(float) var population = 0.0 # in millions
	
var targetted = false
signal planet_targeted

signal planet_orbited
signal planet_deorbited
var orbiters = []
var orbiter
var orbit_rot = 0
var orbit_rate = 0.04
export(bool) var tidally_locked = false
var axis_rot = 0.0


signal planet_colonized

onready var module = preload("res://debris_enemy.tscn")

var labl_loc = Vector2()

# see asteroid.gd and debris_resource.gd
enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN}

#Methane = CH4, carborundum (silicon carbide) = SiC
# plastics are chains of (C2H4)n
enum processed { METHANE, CARBORUNDUM, PLASTICS } 
var storage = {}

# Called when the node is added to the scene for the first time.
# Initialization here
func _ready():
	#print("Planet init")
	set_z_index(game.PLANET_Z)
	connect("planet_orbited", self, "_on_planet_orbited")
	connect("planet_deorbited", self, "_on_planet_deorbited")
	
	labl_loc = $"Label".get_position()
	
	# if colonized, give some storage
	if has_colony():
		randomize_storage()
	
	# debug old positions
#	dist = get_position().length()
#	var ls = dist/game.LIGHT_SEC
#	print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	#setup()

func randomize_storage():
	randomize()
	for e in processed:
		storage[e] = int(rand_range(8.0, 20.0))


func setup(angle=0, dis=0, mas=0):
	print("Setup: " + str(angle) + ", " + str(dis) + ", m: " + str(mas))
	if angle != 0 or dis !=0:
		# place
		place(angle, dis)
	
	if mas != 0:
		mass = mas
	# calculate from density and radius
	else:
		if not is_in_group("moon"):
			# 1.38 is average density for C-type asteroid, e.g. Ceres
			# centaurs are said to be similar to Ceres
			# radius of 25 km in Earth radii (6371 km)
			mass = get_mass(1.38, 0.00392)
			#print("Calculated mass: " + str(mass))
			#mass = 2.679466e-07 # hand calculated
		else:
			# moons without mass defined default to Earth's moon's mass
			mass = game.MOON_MASS #in Earth masses
	
	dist = get_position().length()
	var ls = dist/game.LIGHT_SEC
	#print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	# moon fix
	if is_in_group("moon"):
		# can't be both a moon and a planet
		if is_in_group("planets"):
			remove_from_group("planets")
		#mass = game.MOON_MASS #in Earth masses
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
	
	if not is_habitable():
		hydro = 0.0
	
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
	# gravitational constant (in (N*m2)/kg2)
	var G = (6.67428e-11)
	
	var dist = self.dist
	if is_in_group("moon"):
		# fudge for Martian moons (for realistic distances, they'd totally overlap the Mars sprite)
		if get_parent().get_parent().get_node("Label").get_text() == "Mars":
			# 150 is the rough radius of the sprite
			dist = dist-150
		
		dist = dist/10 # eyeballed scale
	
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	#print("Axis: " + str(axis))
	#print("Check: " + str(axis*game.AU))
	
	# by default, the equation works on seconds, meters and kilograms 
	# because of the units the gravitational constant uses
	# updated numbers from https://astronomy.stackexchange.com/a/1202 (from Wolfram Alpha)
	var AU = 1.4959789e11 #meters
	var yr = 3.15581e7 #seconds (86400 for a day)
	var sun = 1.988435e30 #kg
	
	# if we're a moon, substitute planet mass
	if is_in_group("moon"):
		var Earth = 5.9722e24 # kg, one Earth mass https://en.wikipedia.org/wiki/Earth_mass
		#sun = Earth
		#var moon_mass = mass*sun
		#sun = sun + moon_mass # to be extra correct
		
		#if get_parent().get_parent().get_planet_class() == "gas giant":
			#print(get_node("Label").get_text() + " is a moon of a gas giant")
			#sun = Earth * 206 # average of Jupiter and Saturn masses in Earth masses
		sun = Earth * get_parent().get_parent().mass
	
	#print("sun:" + str(sun))
	
	# T = 2*PI*sqrt(a^3/GM) [ substitute (M1+M2) for M if we're talking binary system ]
	var root = pow((axis*AU), 3) / (G*sun)
	var t = 2*PI*sqrt(root) # in seconds
	
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
	if self.dist == 0 and not is_in_group("moon"):
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

# inverse of the above, needed for those small bodies that don't have mass data
func get_mass(density, radius):
	#var tst = PI*pow(radius,3)
	#var po = 6.4e-08 # 0.004^3
	var tst = 2.0096e-07 # hand calculated for above po and radius
	#print("radius: " + str(radius))
	var vol = (4/3)*tst #PI*pow(radius, 3.0)
	print("d: " + str(density) + " vol: " + str(vol) + " m: " + str((density*vol)))
	return density*vol

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
	#print("Place : a " + str(angle) + " d: " + str(dist))
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
	

# ----------------------------------------
func get_planet_class():
	if is_in_group("moon"):
		if mass > 0.00001 * game.MOON_MASS:
			return "moon"
		else:
			return "moonlet" # made up name for captured asteroids like Deimos and Phobos
	if is_in_group("aster_named"):
		return "asteroid"
	
	if hydro > 0.25:
		return "terrestrial"
	if mass < 5:
		return "rocky"
	else:
		return "gas giant"

# 'interesting' planets have significant ice or water content
func is_interesting():
	var ret = false
	if hydro > 0.2:
		ret = true
	if ice >= 0.05:
		ret = true
		
	return ret

func has_solid_surface():
	# above ~5 masses of Earth, it's either Neptunian or Jovian
	# neither have solid surfaces
	if mass > 5:
		return false
	else:
		return true

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

# --------------------
# colonies
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
				if not has_solid_surface():
					oops_gg(area)
					return
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
							#print("[Colonize] Colonize id is: " + str(id))
							# id is the real id+1 to avoid problems with state param being 0 (= null)
							if get_tree().get_nodes_in_group("planets")[id-1] == self:
								print("[Colonize] We are the colonize target, id " + str(id))
								do_colonize(area)			

		else:
			print("Colony is already ours")

# 'gg' stands for gas giant, but also for 'good game' (ironically)
func oops_gg(area):
	print("Adding sinking colony to planet")
	# add colony to planet
	# prevent crash
	call_deferred("reparent", area)
	# must happen after reparenting
	call_deferred("reposition", area)
	# set timer and sink (disappear) the colony after a couple seconds
	var sink_time = Timer.new()
	sink_time.autostart = true
	area.add_child(sink_time)
	sink_time.set_wait_time(2.0)
	sink_time.start(2.0)
	sink_time.connect("timeout", self, "_on_sink_timer", [area])
	
func _on_sink_timer(area):
	print("Sink timed out")
	area.get_parent().queue_free()

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

func _on_planet_deorbited(ship):
	remove_orbiter(ship)
	# redraw (debugging)
	update()
	print("Ship " + ship.get_parent().get_name() + " deorbited: " + get_node("Label").get_text())
	# give (enemy) ship a dummy target so that it doesn't idle towards the planet
	if 'kind_id' in ship and ship.kind_id == ship.kind.enemy:
		var offset = Vector2(400,400)
		var tg = get_global_position() + offset
		ship.brain.target = tg
	
func get_hostile_orbiter():
	var ret = null
	for o in orbiters:
		#print(o.get_parent().get_name())
		if o.is_in_group("enemy"):
			ret = o
			print("Found hostile orbiter: " + str(o.get_parent().get_name()))
			break
	
	return ret

func has_colony():
	var ret = false
	for c in get_children():
		if c.is_in_group("colony") or c.is_in_group("enemy_col"):
			ret = c.get_groups()[0]

	return ret

func update_HUD_colony_pop(planet, add):
	var node = null
	var hud = game.player.HUD
	var txt = planet.get_node("Label").get_text()
	var aster = planet.is_in_group("aster_named")
	# get label
	for l in hud.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control").get_children():
		if l is Label:
			# because ordering in groups cannot be relied on 100%
			if l.get_text().find(txt) != -1:
				node = l.get_name()
	
	if node:
		var parent = hud.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control")
		if add:
			if parent.get_node(node).get_text().find("^") == -1:
				var text = txt + " ^ "
				if not planet.is_in_group("moon"):
					text = txt + " ^ " + " planet "
				if aster:
					text = txt + " ^ " + " asteroid "
				parent.get_node(node).set_text(text)
				#parent.get_node(node).set_text(parent.get_node(node).get_text() + " ^ ")
		else:
			# remove flag
			if parent.get_node(node).get_text().find("^") != -1:
				#print("Should be removing mark for " + str(parent.get_node(node).get_text()))
				var text = parent.get_node(node).get_text()
				var spl = text.split("^")
				#print(spl)
				parent.get_node(node).set_text(spl[0] + " " + spl[1])


func _on_pop_timer_timeout():
	if has_colony():
		#print("Pop increase")
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
	
	#print("Enough modules: " + str(enough))
	return enough
	
func enough_materials():
	var enough = false
	
	if storage.keys().size() < 1:
		enough = false
	else:
		if storage["CARBORUNDUM"] >= 2 and storage["PLASTICS"] >= 2:
			enough = true
		
	return enough

func _on_module_timer_timeout():
	if has_colony() and enough_materials() and not enough_modules():
		# remove materials
		storage["CARBORUNDUM"] -= 2
		storage["PLASTICS"] -= 2
		
		#print("Module timer")
		var pos = get_global_position()
		var mo = module.instance()
		mo.get_child(0).module = 3 # cloak
		get_parent().add_child(mo)
		# slight offset
		var offset = Vector2(10,10)
		mo.set_global_position(pos+offset)
		mo.set_z_index(2)
