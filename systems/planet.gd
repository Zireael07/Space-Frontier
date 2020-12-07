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

onready var module = preload("res://debris_friendly.tscn")

var scanned = false
var atm_gases

var labl_loc = Vector2()

# see asteroid.gd and debris_resource.gd
enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN}

#Methane = CH4, carborundum (silicon carbide) = SiC
# plastics are chains of (C2H4)n
enum processed { METHANE, CARBORUNDUM, PLASTICS } 
var storage = {}

var deb_chances = []

# Called when the node is added to the scene for the first time.
# Initialization here
func _ready():
	#print("Planet init")
	set_z_index(game.PLANET_Z)
	var _conn
	_conn = connect("planet_orbited", self, "_on_planet_orbited")
	_conn = connect("planet_deorbited", self, "_on_planet_deorbited")
	
	labl_loc = $"Label".get_position()
	
	# if colonized, give some storage and a module table
	if has_colony():
		# tint label cyan
		# TODO: ideally just the text would be cyan, but that works too, and is easier
		get_node("Label").set_self_modulate(Color(0, 1, 1))
		set_debris_table()
		randomize_storage()
		# don't show hub shadow for very small planets
		if planet_rad_factor > 0.2 and not is_in_group("aster_named"):
			get_colony().get_child(0).show_shadow()
		
		# tint us gray to represent pollution
		if atm > 0.01:
			# thresholds are completely arbitrary
			if population > 8000.0:
				get_node("Sprite").set_modulate(Color(0.75, 0.75, 0.75, 1.0))
			if population > 3000.0:
				get_node("Sprite").set_modulate(Color(0.65, 0.65, 0.65, 1.0))
			if population > 500.0: # 0.5B or 500M
				get_node("Sprite").set_modulate(Color(0.5, 0.5, 0.5, 1.0)) # tint light gray
	
	# debug old positions
#	dist = get_position().length()
#	var ls = dist/game.LIGHT_SEC
#	print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	#setup()

func randomize_storage():
	randomize()
	for e in processed:
		storage[e] = int(rand_range(8.0, 20.0))


func setup(angle=0, dis=0, mas=0, rad=0, gen_atm=false):
	print("Setup: " + str(angle) + ", " + str(dis) + ", m: " + str(mas) + ", R:" +str(rad))
	if angle != 0 or dis !=0:
		# place
		place(angle, dis)
	
	if mas != 0:
		mass = mas
	# calculate from density and radius
	else:
		if not is_in_group("moon") and is_in_group("aster_named"):
			# 1.38 is average density for C-type asteroid, e.g. Ceres
			# centaurs are said to be similar to Ceres
			# radius of 25 km in Earth radii (6371 km)
			mass = get_mass(1.38, 0.00392)
			#print("Calculated mass: " + str(mass))
			#mass = 2.679466e-07 # hand calculated
		elif is_in_group("moon"):
			# moons without mass defined default to Earth's moon's mass
			mass = game.MOON_MASS #in Earth masses
	
	dist = get_position().length()
	var _ls = dist/game.LIGHT_SEC
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
	elif rad == 0:
		# default. i.e. rocky
		radius = calculate_radius()
	else:
		# load from data
		radius = rad
		
	gravity = calculate_gravity(mass, radius)
	
	if gen_atm:
		#print("Gen_atm:", gen_atm)
		var mol = molecule_limit()
		print("Smallest molecule planet ", get_node("Label").get_text(), " holds: ", mol)
		
		# more stuff
		# if it can hold to at least CO2
		if mol <= 44.0:
			atm = rand_range(0.01, 1.5)
			#greenhouse = rand_range(0.2, 0.7)
			if mol > 18.0:
				hydro = rand_range(0.1, 0.45)
	
			atm_gases = atmosphere_gases()
			if atm_gases[0].has("CO2"):
				print("Planet ", get_node("Label").get_text(), " has ", atm_gases[0]["CO2"], " atm CO2")
				# match atm of CO2 to greenhouse effect
				# 91 atm of CO2 is 0.975 greenhouse effect (data for Venus)
				# hence 93,3 atm is 1.0 effect
				greenhouse = lerp(0.0, 1.0, atm_gases[0]["CO2"]/93.3)
				print("Greenhouse from ", atm_gases[0]["CO2"], " atm CO2 is ", greenhouse)
	
	# water freezes
	if temp < game.ZEROC_IN_K-1:
		print("Water freezes on ", get_node("Label").get_text())
		ice = hydro
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

	# debug
#	if atm > 0.01:
#		var mol = molecule_limit()
#		print("Smallest molecule planet holds: ", mol)
#		var exo_tmp = get_exospheric_temp()
		
#		var gases = ["H2", "He", "CH4", "NH3", "H2O", "Ne", "CO", "O2", "H2S", "CO2", "O3", "SO2"]
#		for g in gases:
#			print("Gas retention for ", g, " : ", has_gas_retention(g, exo_tmp))

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
	var green = self.greenhouse # to be able to fake 0 effect if needed
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
		green = 0
	
	# http://phl.upr.edu/library/notes/surfacetemperatureofplanets
	# T = 273*((L(1-a)) / D2*(1-g))
	var t = star.luminosity*(1-albedo) / (pow(axis,2) * (1-green))
	var T = 273 * pow(t, 0.25)
	return T

# https://arxiv.org/pdf/1603.08614v2.pdf (Jingjing, Kipping 2016)
func calculate_radius(type="rocky"):
	randomize()
	# <= 2 masses of Earth
	if type == "rocky":
		radius = pow(mass, 0.28)
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
func calculate_gravity(mass, rad):
	# measured in multiplies of Earth's mass and radius and therefore gravity
	# g = m/r^2 
	return mass/pow(rad, 2)

# d = m/V; V = (4/3) π R3
func get_density(mass, rad):
	var vol = (4/3)*PI*pow(rad, 3)
	return mass/vol

# inverse of the above, needed for those small bodies that don't have mass data
func get_mass(density, _radius):
	#var tst = PI*pow(radius,3)
	#var po = 6.4e-08 # 0.004^3
	var tst = 2.0096e-07 # hand calculated for above po and radius
	#print("radius: " + str(radius))
	var vol = (4/3)*tst #PI*pow(radius, 3.0)
	print("d: " + str(density) + " vol: " + str(vol) + " m: " + str((density*vol)))
	return density*vol

# so many things from mass and radius!
# sqrt(G * M / r)
# this is the first cosmic velocity, the one to orbit
func get_cosmic_vel(mass, rad):
	var G = 0.0000000000667
	var vel = sqrt((G*mass)/rad)
	#print("Cosmic vel: ", vel)
	return vel # value relative to the Earth's cosmic vel since mass & radius are expressed as relative
	
# escape velocity aka 2nd cosmic velocity
# At a given height, the escape velocity is sqrt(2) times the speed in a circular orbit... - wikipedia
# relative to Earth escape vel
func get_escape_vel(mass, rad):
	var G = 0.0000000000667
	var vel = sqrt((2*G*mass)/rad)
	var fudge = 1/0.000012 # for some reason, we're getting values this much smaller than IRL
	return vel*fudge # relative to Earth's escape vel
	#return sqrt(2)*get_cosmic_vel(mass, radius)

# --------------------------
# atmosphere - mostly calculations from Accrete/Starform
func get_exospheric_temp():
	var dist_t = self.dist
	var star = get_parent().get_parent()
	# if we're a moon, look up the star and take distance of our parent
	if get_parent().get_parent().is_in_group("planets"):
		dist_t = self.dist + get_parent().get_parent().dist
		star = get_parent().get_parent().get_parent().get_parent()
	
	# calculation from Starform/Accrete, the C versions, wants orbital radius in AU
	var axis = (dist_t/game.LIGHT_SEC)/game.LS_TO_AU
	# Earth's exosphere temp is 1273.0  # degrees Kelvin
	# multiply by star's luminosity to make it work for stars other than the sun
	var ret = star.luminosity * (1273.0 / pow(axis, 2))
		
	#print("Exospheric temp: ", ret, " K")
	return ret

# calculations from Accrete/Starform
func rms_molecule(molecule, exo_temp):
	return sqrt((3.0 * chem.MOLAR_GAS_CONST * exo_temp) / chem.weights[molecule]) # in cm/s

func has_gas_retention(molecule, exo_temp):
	var esc_vel = get_escape_vel(mass, radius) # relative to Earth escape vel
	#esc_vel *= 1118600 # in cm/s
	#print("Esc vel: ", esc_vel, " of Earth escape vel")
	#print("Escape vel: ", esc_vel*1118600, " cm/s")
	
	var rms_vel = rms_molecule(molecule, exo_temp)
	# 6.0 seems to be based on https://cseligman.com/text/planets/retention.htm
	# "over 10 billion years if the ratio is 6"
	#About 100 million years if the ratio of escape velocity to average particle velocity is 5.
	#Well under 1 million years if the ratio is 4 (since there are more particles in the high-velocity tail).
	#Well under 10 thousand years if the ratio is 3
	# And well over 1 trillion years if the ratio is 7
	return ((esc_vel*1118600) / rms_vel) >= 6.0

# from Accrete, refs Fogg's eq.21
func boiling_point():
	var pressure = (atm*1.01325) # in bars
	# 373 is water's boiling point, hardcoded, and -273 is to convert to Celsius 
	var boil_pt = pow(log(pressure) / -5050.5 + 1.0 / 373.0, -1) - 273
	print("Boiling point of water: ", boil_pt, "C")
	return boil_pt


# sort
class MyCustomSorter:
	static func sort_atm_fraction(a, b):
		if a[1] > b[1]:
			return true
		return false

# based on Keris's starform (an Accrete variant)
func atmosphere_gases():
	#print("Atmo gases...")
	
	var exo_temp = get_exospheric_temp()
	var esc_vel = get_escape_vel(mass, radius)*1118600
	
	var pressure = (atm*1.01325) # in bars
	
	var total_amount = 0
	var gases_kinds = []
	# 5.0 is a placeholder for the star's age, in bilions of years
	# 1e9 is 1 billion (a thousand million to be extremely clear, aka "miliard" in some EU languages
	var star_age = 5.0
	
	var gases = ["N", "CH4", "NH3", "H2O", "Ne", "O2", "CO2", "O3"] # remove hydrogen from the list, as we are looking at rocky planets
	for g in gases:
		var molecule = chem.weights[g]
		if molecule >= molecule_limit():
			# if we're not a gas, skip
			if g in chem.boil and exo_temp < chem.boil[g]:
				print("Skipping ", g, " because it's not a gas @ ", str(exo_temp) + "K")
				continue
				
			# no idea what exactly this is, except it is connected to rms
			var pvrms = pow(1 / (1 + rms_molecule(g, exo_temp) / esc_vel), star_age)
			#var abund = chem.abunds[g]
			var abund = chem.abundance[g] # more realistic abundance values
			# dummies
			var react = 1.0
			var fract = 1.0
			var pres2 = 1.0
			
			# gas-specific stuff
			if g == "Ar":
				react = .15 * (star_age/4.0);
			elif g == "He":
				# wants pressure in bars
				pres2 = (0.75 + pressure)
				react = pow(1 / (1 + chem.reactivity[g]), 
								star_age/2.0 * pres2)
			elif g == "O" or g == "O2":
				var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
				# if too cold, no oxygen around (simplified from Keris)
				if temp < 270:
					react = 0.0
					print("Too cold! React: ", react)
				# if planet. check for solar wind, which reaches at least Venus @ 0.70 AU
				# and is powerful enough to strip it of any oxygen
				elif axis < 0.72 and not is_in_group("moon"):
					print("Solar wind stripped us of oxygen")
					react = 0.0
				else:
					# wants pressure in bars
					#pres2 = (0.65 + pressure/2)
					pres2 = (0.89 + pressure/4)

					# this react calculation is based on Keris Starform
					#print("Fact: ", 1 / (1 + reactivity[g]))
					# fractional exponents are funny
					# inverse relation to both star age and pressure
					# older or higher pressure = less react
					#print("Exp: ", (pow(star_age/2.0, 0.5) * pres2))
					
					react = pow(1 / (1 + chem.reactivity[g]), 
									(pow(star_age/2.0, 0.25) * pres2))

			elif g == "CO2":
				pres2 = (0.75 + pressure)
				react = pow(1 / (1 + chem.reactivity[g]), 
								pow(star_age/2.0, 0.5) * pres2)
				#react *= 1.5;
				react /= 2;
				
			# 2020 hacks for Ne/N to work with realistic abundances
			elif g == "Ne":
				pres2 = (0.75 + pressure)
				# pretend there is less of it around (vast majority gets dissipated in the solar wind)
				abund /= 100;

				react = pow(1 / (1 + chem.reactivity[g]), 
								star_age/2.0 * pres2)
			elif g == "N":
				abund *= 2 # nitrogen from plants/ground contributes most likely
				pres2 = (0.75 + pressure)
				react = pow(1 / (1 + chem.reactivity[g]), 
								star_age/2.0 * pres2)
			else:
				pres2 = (0.75 + pressure)
				react = pow(1 / (1 + chem.reactivity[g]), 
								star_age/2.0 * pres2)
			
			# if we're not a gas on the surface, but we are in exosphere, only allow limited amounts
			# e.g. H2O on Earth
			if g in chem.boil and temp < chem.boil[g] and exo_temp > chem.boil[g]:
				print("Limiting quantities of ", g, " because it's a liquid on the surface @", str(temp), "K")
				react = min(react, 0.01)
			
				
			fract = (1 - (molecule_limit() / molecule))
			print("Gas ", g, ": ", str(abund*pvrms), " fract:", fract, " react: ", react)
			var amount = abund * pvrms * react * fract
			if amount > 0:
				print("Gas ", g, " amt: ", amount)
			total_amount = total_amount + amount
			#gases_kinds[g] = amount
			gases_kinds.append([g, amount])
	
	var gases_atm = {}
	var gases_disp = []
	# needs to be a separate loop so that we calculate relative to the total
	for g in gases_kinds:
		var amount = g[1]
		# pressure exerted by our gas
		var ratio = amount/total_amount
		var gas_pressure = atm * ratio # since atm is in atmospheres, this is necessarily so, too
		print("Gas " , g[0], " pressure: ", gas_pressure, " atm ")
		# how much % of atmosphere is the gas
		var atm_fraction = 100 * (gas_pressure / atm)
		gases_atm[g[0]] = gas_pressure
		gases_disp.append([g[0], atm_fraction])
	
	# custom sort
	gases_disp.sort_custom(MyCustomSorter, "sort_atm_fraction")
	
	return [gases_atm, gases_disp]

# Smallest molecular weight retained, useful for determining atmo
# calculation comes from well known Starform/Accrete program which references Fogg here
func molecule_limit():
	var escape_vel = get_escape_vel(mass, radius) ##*1118.6
	#print("Esc vel: ", escape_vel, " of Earth escape vel")
	#print("Escape vel: ", escape_vel*1118600, " cm/s")
	
	# 6.0 is the gas_retention_threshold
	
	var gas = pow(6.0 * 100.0, 2.0) 
	var tmp  = chem.MOLAR_GAS_CONST * get_exospheric_temp()
	# Earth escape vel is 11.186 km/s, give it in cm/s as Accrete wants
	var esc = pow((escape_vel*1118600), 2.0)
	
	var limit = (3.0 * (gas * tmp)) / esc
	#print("Smallest molecule: ", str(limit))
	
	return limit
	#return((3.0 * gas * 1273.0) / pow(escape_vel*1118.6, 2.0));
	
	#return ((3.0 * 8314.41 * get_exospheric_temp()) /
	#		(pow((escape_vel*1118.6 / 6.0) / 100.0, 2)))


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

# --------------------------------
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
	
	if hydro > 0.25 and self.scanned:
		return "terrestrial"
	if mass < 5:
		return "rocky"
	else:
		return "gas giant"

# http://spaceengine.org/news/blog170924/
# temperature cutoffs based on physical properties of substances
func get_temp_desc():
	if temp < 90:
		return "frigid"
	elif temp < 170:
		return "cold"
	elif temp < 250:
		return "chilly" # "cool" in SE, which is too visually similar to cold
	elif temp < 330:
		return "temperate"
	elif temp < 500:
		return "warm"
	elif temp < 1000:
		return "hot"
	else:
		return "scorched" #"torrid" in SE

# http://spaceengine.org/news/blog170924/
func get_volatiles_desc():
	# 1013250100 nanobar in 1 atm => 1 nanobar is 9.869e-10 atm
	if atm < 9.869e-10:
		return "airless"
	else:
		if hydro < 0.01:
			return "desertic"
		if hydro < 0.2:
			return "semi-arid" # Space Engine uses "lacustrine"
		if hydro > 0.2: # "a significant amount of [a liquid substance]"
			return "marine"
		if hydro > 0.8:
			return "oceanic"

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
			# fix to work with shadered (rotating) planets
			var rc_h = tr.get_rect().size.x * tr.get_scale().x
			var rc_w = tr.get_rect().size.y * tr.get_scale().y
			# add a tiny margin to avoid obscuring drawn atmo effect
			var rect = Rect2(Vector2(int(-rc_w/2)-2, int(-rc_h/2)-2), Vector2(int(rc_w)+4, int(rc_h)+4))
			
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
		
		# officer message
		if not self.scanned:
			game.player.emit_signal("officer_message", "Planet targeted. Press S to scan")

# --------------------

func _on_Area2D_area_exited(area):
	if area == game.player and not has_solid_surface():
		game.player.scooping = false
		print("No longer scooping")


# colonies
func reparent(area):
	area.get_parent().get_parent().remove_child(area.get_parent())
	add_child(area.get_parent())

func reposition(area):
	area.get_parent().set_position(Vector2(0,0))
	# make them visible
	area.get_node("blue_colony").set_z_index(1)
	if area.has_node("Sprite"):
		area.get_node("Sprite").set_z_index(1)

func _on_Area2D_area_entered(area):
	if area == game.player:
		#print("Player entered planet area")
		if not has_solid_surface():
			print("Player can scoop from gas giant ", get_node("Label").get_text())
			game.player.scooping = true
			
	# colonies
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
			#pass

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
		# tint label cyan
		get_node("Label").set_self_modulate(Color(0, 1, 1))
		
		# set modules table
		set_debris_table()
		
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
			
		# this signal wants the top node, not the area itself
		area.emit_signal("colony_colonized", area.get_parent(), self)
		#print("Adding colony to planet")
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
	# avoid double-adding
	if !orbiters.has(orbiter):
		orbiters.append(orbiter)
	print("Planet orbited " + str(get_node("Label").get_text()) + "; orbiter: " + str(orbiter.get_parent().get_name()))

	var rel_pos = get_node("orbit_holder").get_global_transform().xform_inv(orbiter.get_global_position())
	
	
	orbiter.get_parent().set_position(Vector2(0,0))
	orbiter.set_position(Vector2(0,0))
	orbiter.pos = Vector2(0,0)

	#print("Rel pos: " + str(rel_pos))
	orbiter.set_position(rel_pos)
	
	var _a = atan2(rel_pos.x, rel_pos.y)
#	var a = atan2(200,0)

	#print("Initial angle " + str(a))
	
	# redraw (debugging)
	update()

func remove_orbiter(ship):
	var sh = orbiters.find(ship)
	if sh != -1:
		orbiters.remove(sh)

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

#  ----------------------
func get_colony():
	for c in get_children():
		if c.is_in_group("colony"):
			return c

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

	# tint us gray to represent pollution
	if atm > 0.01:
		# thresholds are completely arbitrary
		if population > 8000.0:
			get_node("Sprite").set_modulate(Color(0.75, 0.75, 0.75, 1.0))
		if population > 3000.0:
			get_node("Sprite").set_modulate(Color(0.65, 0.65, 0.65, 1.0))
		if population > 500.0: # 0.5B or 500M
			get_node("Sprite").set_modulate(Color(0.5, 0.5, 0.5, 1.0)) # tint light gray
		
		
		
#	else:
#		print("No colony?")

# ----------------------
func set_debris_table():
	# randomizing is done here and not in debris because planet-spawned debris has different chances
	deb_chances.append(["cloak", 30])
	deb_chances.append(["shields", 70])

# TODO: those are used at least in 4 spots (here and in asteroids and in proc star system, unify?
func get_chance_roll_table(chances, pad=false):
	var num = -1
	var chance_roll = []
	for chance in chances:
		#print(chance)
		var old_num = num + 1
		num += 1 + chance[1]
		# clip top number to 100
		if num > 100:
			num = 100
		chance_roll.append([chance[0], old_num, num])

	if pad:
		# pad out to 100
		print("Last number is " + str(num))
		# print "Last number is " + str(num)
		chance_roll.append(["None", num, 100])

	return chance_roll

# wants a table of chances [[name, low, upper]]
func random_choice_table(table):
	var roll = randi() % 101 # between 0 and 100
	print("Roll: " + str(roll))
	
	for row in table:
		if roll >= row[1] and roll <= row[2]:
			print("Random roll picked: " + str(row[0]))
			return row[0]

# random select from a table
func select_random_module():
	var chance_roll_table = get_chance_roll_table(deb_chances)
	print(chance_roll_table)
	
	var res = random_choice_table(chance_roll_table)
	print("Module res: " + str(res))
	return res

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
		
		# randomize
		var sel = select_random_module()
		mo.get_child(0).module = mo.get_child(0).match_string(sel)
		
		#mo.get_child(0).module = 3 # cloak
		get_parent().add_child(mo)
		# slight offset
		var offset = Vector2(10,10)
		mo.set_global_position(pos+offset)
		mo.set_z_index(2)

# ---------------------
func convert_planetnode_to_id():
	var planets = get_tree().get_nodes_in_group("planets")
	
	var id = 0
	var moon = false	
	if is_in_group("moon"):
		#var parent = planet.get_parent().get_parent()
		#var moons = parent.get_moons()
		var moons = get_tree().get_nodes_in_group("moon")
		id = moons.find(self)
		moon = true
		#id = planets.find(parent)
	else:
		id = planets.find(self)
		
	#print("For " + get_node("Label").get_text() + " ID is " + str(id))
	return [id, moon]
