@tool
extends Node2D

# class member variables go here, for example:
@export var planet_rad_factor: float = 1.0

#export var orbit_angle: int setget setOrbitAngle #, getAngle
#export var dist: int = 100 setget setDist #, getDist

@export var data: Vector2 #: set = setData

@export var mass: float = 1 # in Earth masses
var radius = 1.0 # in Earth radius
var gravity = 1.0 # in Earth gravity
@export var hydro: float = 0.3 # land/water ratio (surface, not volume = 30% for Earth which is known to be 70% water 30% land)
@export var ice: float = 0.0 # how much of the surface is covered by ice (eyeballed for most planets)
var albedo = 0.3 # test value Bond albedo (matches Earth), ranges from 0 to 1
var temp = 0 # in Kelvin
@export var atm: float = 0.0 # in Earth atmospheres
@export var greenhouse: float = 0.0 # greenhouse coefficient from 0 to 1, see: http://phl.upr.edu/library/notes/surfacetemperatureofplanets

var dist = 0

@export var population: float = 0.0 # in millions
	
var targetted = false
signal planet_targeted

signal planet_orbited
signal planet_deorbited
var orbiters = []
var orbiter
var orbit_rot = 0
var orbit_rate = 0.04
@export var tidally_locked: bool = false
var axis_rot = 0.0


signal planet_colonized

@onready var module = preload("res://debris_friendly.tscn")

var scanned = false
var atm_gases
var composition = []

var labl_loc = Vector2()
var no_shadow = false # for HUD display

# see asteroid.gd and debris_resource.gd
enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN, NICKEL, SILVER, PLATINUM, GOLD, SULFUR}

#Methane = CH4, carborundum (silicon carbide) = SiC
# plastics are chains of (C2H4)n
# electronics are made out of Si + Al/Cu; durable variant (for higher temps & pressures) - SiC + Au/Ag/Pl
enum processed { METHANE, CARBORUNDUM, PLASTICS, ELECTRONICS, DURABLE_ELECTRONICS } 
var storage = {}

var deb_chances = []

# Called when the node is added to the scene for the first time.
# Initialization here
func _ready():
	#print("Planet init")
	set_z_index(game.PLANET_Z)
	var _conn
	_conn = connect("planet_orbited",Callable(self,"_on_planet_orbited"))
	_conn = connect("planet_deorbited",Callable(self,"_on_planet_deorbited"))
	
		
	# preset the vectors texture if any rotating shader
	if $Sprite2D.material != null and $Sprite2D.material.get_shader_parameter("vectors") != null:
		var vecs = load("res://assets/bodies/texture_template.png")
		$Sprite2D.material.set_shader_parameter("vectors", vecs)
	
	# FIXME: set Label position on basis of planet scale factor
	
	labl_loc = $"Label".get_position()
	
	# if colonized, give some storage and a module table
	if has_colony():
		# tint label cyan
		# TODO: ideally just the text would be cyan, but that works too, and is easier
		get_node("Label").set_self_modulate(Color(0, 1, 1))
		set_debris_table()
		randomize_storage()
		if !Engine.is_editor_hint():
			# don't show hub shadow for very small planets
			if planet_rad_factor > 0.2 and not is_in_group("aster_named"):
				get_colony().get_child(0).show_shadow()
		
		# not in original Stellar Frontier: tint us gray to represent pollution
		if atm > 0.01:
			# thresholds are completely arbitrary
			if population > 8000.0:
				get_node("Sprite2D").set_modulate(Color(0.75, 0.75, 0.75, 1.0))
			if population > 3000.0:
				get_node("Sprite2D").set_modulate(Color(0.65, 0.65, 0.65, 1.0))
			if population > 500.0: # 0.5B or 500M
				get_node("Sprite2D").set_modulate(Color(0.5, 0.5, 0.5, 1.0)) # tint light gray
	
	# debug old positions
#	dist = get_position().length()
#	var ls = dist/game.LIGHT_SEC
#	print("Dist to parent star: " + str(dist) + " " + str(ls) + " ls, " + str(ls/game.LS_TO_AU) + " AU")
	
	#setup()

func randomize_storage():
	randomize()
	for e in processed:
		storage[e] = int(randf_range(8.0, 20.0))
	for e in elements:
		if e != "SULFUR":
			storage[e] = int(randf_range(2.0, 6.0))
		# hack to have enough resources for some initial colonies
		else:
			storage[e] = int(randf_range(5.0, 15.0))
	

func setup(angle=0, dis=0, mas=0, rad=0, gen_atm=false):
	#print("Setup: " + str(angle) + ", " + str(dis) + ", m: " + str(mas) + ", R:" +str(rad))
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
			atm = randf_range(0.01, 1.5)
			#greenhouse = randf_range(0.2, 0.7)
			if mol > 18.0:
				hydro = randf_range(0.1, 0.45)
	
			atm_gases = atmosphere_gases()
			if atm_gases[0].has("CO2"):
				print("Planet ", get_node("Label").get_text(), " has ", atm_gases[0]["CO2"], " atm CO2")
				# match atm of CO2 to greenhouse effect
				# 91 atm of CO2 is 0.975 greenhouse effect (data for Venus)
				# hence 93,3 atm is 1.0 effect
				greenhouse = lerp(0.0, 1.0, atm_gases[0]["CO2"]/93.3)
				print("Greenhouse from ", atm_gases[0]["CO2"], " atm CO2 is ", greenhouse)
	
	# planetary composition
	if not is_in_group("moon") and not is_in_group("aster_named"):
		
		if mass < 5:
			if get_node("Label").get_text() == "Earth":
				# Earth's composition according to Spaarengen https://arxiv.org/abs/2211.01800
				composition = [["core mass", 32.5], ["SiO2", 39.85], ["CaO", 3.25], ["Na2O", 0.3], ["MgO", 48.24], ["Al2O3", 2.23], ["FeO", 5.96] ]
			elif get_node("Label").get_text() == "Mars":
				#https://www.researchgate.net/publication/348949548_Earth_and_Mars_-_Distinct_inner_solar_system_products
				# page 26 (note they have higher values for Earth than Spaarengen or Donough)
				# https://progearthplanetsci.springeropen.com/articles/10.1186/s40645-017-0139-4
				# Mars’ core mass is about 0.24 of the planetary mass (Table 1), and Earth’s core mass fraction is 0.32 (Stacey 1992)
				composition = [["core mass", 24], ["SiO2", 45.5],  ["CaO", 2.88], ["Na2O", 0.59], ["MgO", 31.0], ["Al2O3", 3.5], ["FeO", 14.7]]
			elif get_node("Label").get_text() == "Venus":
				# Like that of Earth, the Venusian core is most likely at least partially liquid because the two planets have been cooling at about the same rate
				
				# https://arxiv.org/pdf/1410.3509.pdf Table 6 page 59 gives core mass, SiO2 and FeO
				# various sources assume Venus has the same composition as Earth, so we fill in the gaps with Earth-like values
				# 39.85/45.7 = 48.24/x => x*39.85 = 45.7*48.24 => x = (45.7*48.24)/39.85
				var mgo = (45.7*48.24)/39.85
				composition = [["core mass", 30], ["SiO2", 45.7], ["CaO", 3.2], ["Na2O",0.2], ["MgO", mgo], ["Al2O3", 2.1], ["FeO", 7.38] ] 
				
			elif get_node("Label").get_text() == "Mercury":
				# Mercury appears to have a solid silicate crust and mantle overlying a solid, iron sulfide outer core layer, a deeper liquid core layer, and a solid inner core
				# The radius of Mercury's core is estimated to be 2,020 ± 30 km (1,255 ± 19 mi), based on interior models constrained to be consistent with the value of the moment of inertia factor.
				# Hence, Mercury's core occupies about 57% of its volume; for Earth this proportion is 17%. 
				# Mercury's core has a higher iron content than that of any other major planet in the Solar System, and several theories have been proposed to explain this.
				# The most widely accepted theory is that Mercury originally had a metal–silicate ratio similar to common chondrite meteorites, thought to be typical of the Solar System's rocky matter, and a mass approximately 2.25 times its current mass
				
				# composition from https://arxiv.org/pdf/1712.02187.pdf page 32 (averaged)
				# Given our input parameters and assumptions, Mercury's core mass fraction is significantly larger than the other terrestrial planets and has a broad range of plausible values (53–78% of the total planet mass)
				# https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2007JE002993
				composition = [["core mass", 60], ["SiO2", 52], ["CaO", 2.5], ["Na2O", 2], ["MgO", 38], ["Al2O3", 3], ["FeO", 0.02] ]

			else:
				# so far I only have numbers for rocky/terrestrial planets
				composition = planetary_composition()
			
			#print("Composition: ", composition)
		if mass > 5:
			# since hydrogen and helium are both so light (but helium is twice as heavy) 
			# it makes more sense to use volume measurements and not mass
			
			# TODO: come up with vaguely sensible looking numbers for other gas giants
			
			if get_node("Label").get_text() == "Jupiter":
				# Jupiter is 90% hydrogen 10% helium by volume, but 24% helium by mass due to the above
				#  trace amounts of methane, water vapour, ammonia, and silicon-based compounds
				# fractional amounts of carbon, ethane, hydrogen sulfide, neon, oxygen, phosphine, and sulfur. 
				composition = [["H", 90], ["He", 10]]
			if get_node("Label").get_text() == "Saturn":
				# Saturn is very similar to Jupiter
				# The proportion of helium is significantly deficient compared to the abundance of this element in the Sun.
				# The quantity of elements heavier than helium (metallicity) is not known precisely, 
				# but the proportions are assumed to match the primordial abundances from the formation of the Solar System. 
				# The total mass of these heavier elements is estimated to be 19–31 times the mass of the Earth, with a significant fraction located in Saturn's core region.
				# Trace amounts of ammonia, acetylene, ethane, propane, phosphine, and methane have been detected in Saturn's atmosphere
				composition = [["H", 96], ["He", 3]]
			if get_node("Label").get_text() == "Uranus":
				# source: Wikipedia infobox
				composition = [["H", 83], ["He", 15], ["CH4", 2.3]]
			if get_node("Label").get_text() == "Neptune":
				# source: Wikipedia infobox
				composition = [["H", 80], ["He", 19], ["CH4", 1.5]]
	elif is_in_group("moon"):
		
		if get_node("Label").get_text() == "Moon":
			# The average composition of the lunar surface by weight is roughly 
			# 43% oxygen, 20% silicon, 19% magnesium, 10% iron, 3% calcium, 3% aluminum, 0.42% chromium, 0.18% titanium and 0.12% manganese.
			
			# most of the material that eventually forms the Moon comes from the impactor, Theia
			#  analysis of samples brought from the Moon by the Apollo missions showed otherwise—in terms of composition, the Earth and Moon are almost twins
			# their compositions are almost the same, differing by at most few parts in a million.
			# https://phys.org/news/2015-04-moon-composition.html
			
			# Earth's composition according to Spaarengen https://arxiv.org/abs/2211.01800
			# core mass 32,5% SiO 39.85 CaO 3.25 Na2O 0.3 MgO 48.24  Al2O3 2.23 FeO 5.96
			composition = [["core mass", 32.5], ["SiO2", 39.85], ["CaO", 3.25], ["Na2O", 0.3], ["MgO", 48.24], ["Al2O3", 2.23], ["FeO", 5.96] ]
		
		if get_node("Label").get_text() == "Phobos" or get_node("Label").get_text() == "Deimos":
			# those two are captured asteroids, see below
			composition = [["SiO", 33], ["CaO", 0], ["Na2O", 0.5], ["MgO", 24], ["Al2O3", 2.5], ["FeO", 15]]
		
		# Galilean moons
		if get_node("Label").get_text() == "Io":
			# Io and Europa are closer in bulk composition to the terrestrial planets than to other satellites in the outer Solar System
			# Io's metallic core makes up approximately 20% of its mass.
			# the mantle is composed of at least 75% of the magnesium-rich mineral forsterite, and has a bulk composition similar to that of L-chondrite and LL-chondrite meteorites
			# with higher iron content (compared to silicon) than the Moon or Earth, but lower than Mars
			
			# Keszthelyi et al. 2007 assumed a refractory composition of 36% SiO2/30% FeO/25% MgO bulk composition
			# publicly accessible abstract https://www.sciencedirect.com/science/article/abs/pii/S0019103507003132?via%3Dihub 
			# "In general, it has been assumed that Io, like the rest of the Solar System, is broadly chondritic. 
			# Io's bulk density is consistent with such a bulk composition, though lower density chondrites are somewhat preferred (Kuskov and Kronrod, 2001).
			# the rest of bulk composition was additional oxides with potassium, calcium, sodium, and aluminum."
			# http://www.gishbartimes.org/2010/01/chemical-composition-of-io.html
			
			# CaO, Na2O and Al2O3 are just my guesses since I can't find them in the accessible data
			composition = [["core mass", 20], ["SiO2", 36], ["CaO", 0], ["Na2O", 0.5], ["MgO", 25], ["Al2O3", 3], ["FeO", 30]]
			
		if get_node("Label").get_text() == "Europa":
			# https://www.researchgate.net/publication/257687446_The_internal_structure_models_of_Europa
			# we pick model II which is roughly midway between the two, giving a core mass of 22%
			# A Europa model with a water ice-liquid shell about 170 km thick has a bulk Fe/Si ratio about equal to the CI carbonaceous chondrite value of 1.7 ± 0.1.
			# https://lasp.colorado.edu/home/mop/files/2015/08/jupiter_ch13-1.pdf
			
			# in absence of any better data, let's just go with the "broadly chondritic" guesses (see Io and Callisto)
			composition = [["core mass", 22], ["SiO2", 36], ["CaO", 0], ["Na2O", 0.5], ["MgO", 25], ["Al2O3", 3], ["FeO", 30]]
		
		if get_node("Label").get_text() == "Callisto":
			# The mass fraction of ices is 49–55%
			# The exact composition of Callisto's rock component is not known, but is probably close to the composition of L/LL type ordinary chondrites
			#  The weight ratio of iron to silicon is 0.9–1.3 in Callisto, whereas the solar ratio is around 1:8.
			
			# L/LL chondritic composition:
			
			# FIXME: this gives too high CaO!
			# https://bibliotekanauki.pl/api/full-texts/2020/12/12/bb78fdfd-83e5-4f39-a6ea-6bb92046339c.pdf
			# (Table 2: Mg/Si 0.93 Al/Si 0.65 to 0.68 Ca/Si 0.48-0.49 Fe/Si 0.49 to 0.58 Ca/Al 0.72-0.74 Ni/Si 0.25-0.31
			
			#https://www.researchgate.net/publication/348949548_Earth_and_Mars_-_Distinct_inner_solar_system_products
			# page 26 gives compositions for chondrites
			# O 35.8% Fe 22.7% Mg 15.7% Si 19.5% Ca 1.38 Al 1.29 Mg/Si 0.81 Al/Si 0.07 Fe/Si 1.2
			# for comparison, Earth is O 29.7% Fe 32% Mg 15.4% Si 16% Ca 1.71 Al 1.59 Mg/Si 0.96 Al/Si 0.10 Fe/Si 2.0
			# and Mars is O 36.3% Fe 23.7 Mg 15.3% Si 17.4% Ca 1.69 Al 1.56  Mg/Si 0.88 Al/Si 0.09 Fe/Si 1.4
			# judging by high Fe% that's "bulk" w/o differentiating core vs mantle
			
			# mash-up between the composition given for Io, which is also "broadly chondritic", and ratios given above
			var feo = 0.36*0.5
			var mgo = 0.36*0.81
#			var mgo = 0.36*0.93
			var alo = 0.36*0.10
			# Na2O and CaO are a guess (CaO is usually similar to Al2O3), since they're not in the data
			composition = [["SiO2", 36], ["CaO", 3], ["Na2O", 0.5], ["MgO", mgo*100], ["Al2O3", alo*100], ["FeO", feo*100]]
			print("Composition: ", composition)

		
		if get_node("Label").get_text() == "Ganymede":
			# The mass fraction of ices is between 46 and 50 percent, which is slightly lower than that in Callisto
			# same observations apply as Callisto; iron/silicon ratio ranges between 1.05 and 1.27
			
			# The most compelling evidence for the existence of a liquid, iron-nickel-rich core is Ganymede's intrinsic magnetic field
			
			# https://presentations.copernicus.org/EPSC2022/EPSC2022-11_presentation-h643675.pdf
			# core mass is a guess because it's not in the data
			composition = [["core mass", 20], ["SiO2", 41], ["CaO", 2.37], ["Na2O", 1.19], ["MgO", 30], ["Al2O3", 3], ["FeO", 22]]
			
		
		# TODO: moons of Uranus/Neptune
		if get_node("Label").get_text() == "Titan":
			# https://www.sciencedirect.com/science/article/pii/S0032063311001401
			#  Given that smaller rock (or rock+ice) densities are indicative of core temperatures too low to allow partial melting and segregation of metal into an inner core, 
			# then the balance of probability must be that MoI=0.34 means that Titan has no metallic core
			# such small (metallic) cores (would) represent a very small fraction of Titan’s total mass (<0.5 wt%).
			
			# core radius of 2054; moon radius of 2574
			# 'core' is rock (as is the case with most moons hereon)
			var core_mass = pow(0.79, 1.0/0.5)
			# composition is a guess
			composition = [["core mass", core_mass*100], ["SiO2",45], ["CaO",2.5], ["Na2O", 1.5], ["MgO", 30 ], ["Al2O3", 2.5], ["FeO",5]]
			
		
		if get_node("Label").get_text() == "Mimas":
			# https://www.sciencedirect.com/science/article/abs/pii/001910358890084X
			# We conclude that Mimas is probably differentiated. The satellite may have a rocky core of radius (0.44 ± 0.09) 〈R〉, 
			# in which case the material outside the core probably has a mean density of 0.96 ± 0.08 g/cm3, consistent with that of uncompressed, but moderately contaminated, water-ice
			# If the matrix of the mantle material is water-ice, then the silicate mass fraction of Mimas is 0.27 ± 0.04; Mimas is markedly deficient in rock.
			
			# The empirical scaling relation of CRF ≈ CMF^0.5 proposed in Zeng and Jacobsen (2017)
			# CMF = CRF*root(0.5) since square root = inverse of ^2
			# nth root of x is x^(1/n), so you can do 9**(1/2) to find the 2nd (square) root of 9
			
			var core_mass = pow(0.44, 1.0/0.5)
			# no data that I can find on the rest, so just guess
			composition = [ ["core mass", core_mass*100], ["SiO2", 40], ["CaO", 2], ["Na2O", 1.5], ["MgO", 30], ["Al2O3", 2.5], ["FeO", 8] ]
			#print("Core mass: ", core_mass)

		if get_node("Label").get_text() == "Rhea":
			# https://solarsystem.nasa.gov/moons/saturn-moons/rhea/in-depth/
			# Thus, it is thought that Rhea is composed of a homogenous mixture of ice and rock — a frozen dirty snowball.
			
			# just a guess based on asteroid/chondritic composition
			composition = [["SiO2", 0.33], ["CaO", 1], ["Na2O", 0.5], ["MgO", 0.3], ["Al2O3", 2.5], ["FeO", 15]]
			pass
		if get_node("Label").get_text() == "Tethys":
			# The density of Tethys is 0.98 g/cm3, indicating that it is composed almost entirely of water-ice.
			#  It is not known whether Tethys is differentiated into a rocky core and ice mantle. 
			# However, if it is differentiated, the radius of the core does not exceed 145 km, and its mass is below 6% of the total mass. 
			
			# no data I can find, so a guess
			composition = [["core mass", 5], ["SiO2", 35], ["CaO",2], ["Na2O",1], ["MgO", 48], ["Al2O3", 3], ["FeO",5]]
			
		if get_node("Label").get_text() == "Dione":
			# Shape3D and gravity observations collected by Cassini suggest a roughly 400 km radius rocky core surrounded by a roughly 160 km envelope of H2O
			# radius of 560km per Wikipedia gives a core radius fraction of 0.71
			var core_mass = pow(0.71, 1.0/0.5)
			# again, all of the composition data is a guess
			composition = [["core mass", core_mass*100], ["SiO2", 30], ["CaO",2.5], ["Na2O",1.5], ["MgO", 42], ["Al2O3", 3], ["FeO",8]]

		if get_node("Label").get_text() == "Enceladus":
			# Since the ocean in Enceladus supplies the jets, and the jets produce Saturn’s E ring, to study material in the E ring is to study Enceladus’ ocean
			# https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4639802/
			# Enceladus' seawater is suggested to be mildly alkaline (pH∼8.5–10.5)
			
			# https://www.academia.edu/59711602/The_Interior_of_Enceladus
			# core radius of ~190 km (table 3, page 68)
			# Enceladus has a radius of 252km per Wiki, so a radius factor of 0.75
			# note that this core is likely porous rock, not so much metal
			
			var core_mass = pow(0.75, 1.0/0.5)
			# no data for the bulk composition, so just guessing again
			composition = [["core mass", core_mass*100], ["SiO2", 40], ["CaO",2], ["Na2O",1.5], ["MgO",35], ["Al2O3", 2], ["FeO", 5]]
		
		# The low density of Iapetus indicates that it is mostly composed of ice, with only a small (~20%) amount of rocky materials
			
	elif is_in_group("aster_named"):
		# asteroid composition (assuming carbonaceous because they're by far the most common)
		# see asteroid.gd for details (based on http://web.archive.org/web/20220210052125/https://www.permanent.com/meteorite-compositions.html )
		var sio = 0.33
		var cao = 0.00 # not listed in the source
		var nao = 0.005
		var mgo = 0.24
		var alo = 0.025
		var feo = 0.15
		
		if get_node("Label").get_text() == "Vesta":
			# Vesta is the only asteroid to have a differentiated interior (i.e. core, mantle and crust)
			# Vesta composition based on https://www.researchgate.net/figure/Bulk-silicate-Vesta-compositions-wt_tbl1_282940471
			
			sio = 0.45
			cao = 0.03
			nao = 0.001
			mgo = 0.31
			alo = 0.035
			feo = 0.15
			# https://www.researchgate.net/publication/234393401_On_the_Core_Mass_of_the_Asteroid_Vesta
			# estimates vary from 2 to 50%
			var core_mass = 0.20
		
		composition = [["SiO", sio*100], ["CaO", cao*100], ["Na2O", nao*100], ["MgO", mgo*100], ["Al2O3", alo*100], ["FeO", feo*100]]

	
	# water freezes
	if temp < game.ZEROC_IN_K-1:
		#print("Water freezes on ", get_node("Label").get_text())
		ice = hydro
		hydro = 0.0
		
	# send temperature to shader if procedural planet
	if $Sprite2D.texture is NoiseTexture2D:
		# automatically duplicate/make unique the material if procedural
		$Sprite2D.material.set_local_to_scene(true)
		
		#if temp > 400 Celsius then change graphics to lava planet
		# roughly 670 K iirc?
		if (temp-game.ZEROC_IN_K) > 400:
			print("Hot lava planet")
			var lava = preload("res://bodies/planet_lava_test.tscn")
			var tmp = lava.instantiate()
			get_node("Sprite2D").set_material(tmp.get_node("Sprite2D").material)
			# prevent mem leak
			tmp.queue_free()
		else:
			# send temp in Celsius to the shader
			get_node("Sprite2D").get_material().set_shader_parameter("temperature", (temp-game.ZEROC_IN_K))
			print("Sending temp %.2f" % (temp-game.ZEROC_IN_K), " C to shader")
	
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
		
func in_venus_zone():
	var star = get_parent().get_parent()
	# paranoia
	if not 'luminosity' in star:
		return false
	
	var axis = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	if axis <= star.calculate_vz(star.luminosity)[0]:
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
# this is in Kelvin
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
	#print("Axis: ", axis, "AU")
	
	# https://spacemath.gsfc.nasa.gov/astrob/6Page61.pdf
	# T = 273*((L(1-a) / D2)^0.25)
	# where L = star luminosity
	
	if inc_greenhouse == false:
		green = 0
	
	# http://web.archive.org/web/20211018072330/http://phl.upr.edu/library/notes/surfacetemperatureofplanets
	# T = 278*((L(1-a)) / D2*(1-g))
	var t = star.luminosity*(1.0-albedo) / (pow(axis,2) * (1.0-green))
	var T = 278.0 * pow(t, 0.25)
#	print("Temp in K: ", T)

	# another version of the calculation
	# https://web.archive.org/web/20210605120431/https://scied.ucar.edu/earth-system/planetary-energy-balance-temperature-calculate
	# http://home.ustc.edu.cn/~baishuxu/planettempcalc.html (see their source)
	# https://ui.adsabs.harvard.edu/abs/2012PASP..124..323K/abstract (arxiv:1202.2377) equation 3
#	var sigma = 5.670367e-8 # Stefan-Boltzmann constant
#	var sol_flux = 3.828e26 # in Watts?
#	var AU = 1.4959789e11 #meters
#	# per https://www.tfeb.org/fragments/2015/09/30/black-body-planet/ the upper part equals S (insolation, Wm^-2) ?
#	var t = star.luminosity*sol_flux*(1.0-albedo) / (16 * PI * axis * axis * AU * AU * sigma);
#	var T = pow(t, 0.25)
	#print("Temp in K: ", T)
	return T

# https://arxiv.org/pdf/1603.08614v2.pdf (Jingjing, Kipping 2016)
func calculate_radius(type="rocky"):
	randomize()
	# <= 2 masses of Earth
	if type == "rocky":
		radius = pow(mass, 0.28)
		# fudge
		var max_dev = radius*0.04 # 4% max spread
		radius = randf_range(radius-max_dev, radius+max_dev)
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
		radius = randf_range(radius-max_dev, radius+max_dev)
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
			#print("Considering gas...", g)
			# if we're not a gas, skip
			if g in chem.boil and exo_temp < chem.boil[g]:
				print("Skipping ", g, " because it's not a gas @ ", str(exo_temp) + "K (exospheric temp)")
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
				
				# https://ui.adsabs.harvard.edu/abs/2006P%26SS...54.1445L/abstract
				# "Our study indicates that on Venus [..] the most relevant atmospheric escape processes of oxygen involve ions and are caused by the interaction with the solar wind."
				# the solar wind can reach even Mars https://www.sci.news/space/maven-martian-atmosphere-lost-space-04750.html
				
				# if planet. check for solar wind which can strip us of any oxygen
				elif in_venus_zone() and not is_in_group("moon"):
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
			#print("Gas ", g, ": ", str(abund*pvrms), " fract:", fract, " react: ", react)
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
	gases_disp.sort_custom(Callable(MyCustomSorter,"sort_atm_fraction"))
	
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

# -----------------------------------------------------

# planetary composition

# mantle: SiO2, CaO, Na2O, MgO, Al2O3, FeO, NiO (in order of ease of oxidation)
# very minor amounts: SO3, CO2, graphite, metals
# core: Fe, Ni, S 
# all of the above based on https://doi.org/10.1093/mnras/sty2749

# shortcut: instead of using https://github.com/astro-seanwhy/ExoInt and doing a Monte Carlo
# this is based on sample compositions and correlations by Spaarengen https://arxiv.org/abs/2211.01800
func planetary_composition():
	randomize()
	# core sizes range from 18-35%
	var core_mass = randf_range(0.18,0.35)
	# FeO correlates linearly with the above. Earth has 6% FeO and 32.5% core mass
	# 6/32.5 = x/core_mass -> x = 6*core_mass/32.5
	var feo = 0.06*core_mass/0.325
	# Mg/Si ratio can vary between 1.0 and 2.0 
	var mgsi_ratio = randf_range(1.0, 2.0)
	# varies between 28% and 46% (see table 4)
	var sio = randf_range(0.28, 0.46)
	var mgo = sio*mgsi_ratio;
	# varies between 6 and 13%; Earth's is 6%
	# this is Ca+Al+Na/Ca+Al+Na+Fe+Mg+Si but note the divisor (after the slash) sums up to 100%
	# (those six are all the elements under consideration)
	var minor_fraction = randf_range(0.06, 0.13)
	# varies between 1.3% and 3.5% (table 4)
	var alo = randf_range(0.013, 0.035)
	# varies between ~1.0 and 3.0 (basic calculations on table 4)
	var caal_ratio = randf_range(1.0, 3.0)
	var cao = caal_ratio*alo
	# simple maths; in practice is a very small fraction (~0.3%)
	var nao = clamp(minor_fraction-(cao+alo), 0.02, 0.03)
	
	return [ ["Core mass", core_mass*100], ["SiO", sio*100], ["CaO", cao*100], ["Na2O", nao*100], ["MgO", mgo*100], ["Al2O3", alo*100], ["FeO", feo*100]]

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
	var pos = Vector2(0, dist).rotated(deg_to_rad(angle))
	#print("vec: 0, " + str(dist) + " rot: " + str(deg_to_rad(angle)))
	#print("Position is " + str(pos))
	
	set_position(pos)

#func setOrbitAngle(val):
#	print("Set angle to : " + str(val))
#	var pos = Vector2(0, dist).rotated(deg_to_rad(val))
#	print("vec: 0, " + str(dist) + " rot: " + str(deg_to_rad(val)))
#	print("Position is " + str(pos))
#
#	set_position(pos)
	#place(val, getDist())

#func setDist(val):
#	print("Set dist to: " + str(val))
#	var pos = Vector2(0, val).rotated(deg_to_rad(orbit_angle))
#	print("vec: 0, " + str(val) + " rot: " + str(deg_to_rad(orbit_angle)))
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
	if get_node("Sprite2D").get_material() != null:
		get_node("Sprite2D").get_material().set_shader_parameter("time", axis_rot)
	
	# redraw
	queue_redraw()

	
	if get_parent().is_class("Node2D"):
		#print("Parent is a Node2D")
		# straighten out labels
		if not Engine.is_editor_hint():
			$"Label".set_rotation(-get_parent().get_rotation())
			
			# get the label to stay in one place from player POV
			var angle = -get_parent().get_rotation() + deg_to_rad(45) # because the label is located at 45 deg angle...
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
		# straighten out the dome sprite if any
		if has_colony():
			var dome = get_colony().get_child(0).get_child(1).get_node("dome")
			dome.set_rotation(-get_parent().get_rotation())
	
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
				var tg = o.get_global_position() * get_global_transform()
				if not o.is_in_group("drone"):
					draw_line(Vector2(0,0),tg,Color(1,0,0),6.0)
				else:
					draw_line(Vector2(0,0),tg,Color(0,0,1),3.0)
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
			
#		# redraw
#		queue_redraw()
		
		# officer message
		if not self.scanned:
			game.player.emit_signal("officer_message", "Planet targeted. Press S to scan")

# --------------------

func _on_Area2D_area_exited(area):
	if area == game.player and not has_solid_surface():
		game.player.scooping = false
		game.player.HUD.get_node("AnimationPlayer").stop()
		print("No longer scooping")


# colonies
func reparent_helper(area):
	area.get_parent().get_parent().remove_child(area.get_parent())
	add_child(area.get_parent())

func reposition(area):
	area.get_parent().set_position(Vector2(0,0))
	# make them visible
	area.get_node("blue_colony").set_z_index(1)
	if area.has_node("Sprite2D"):
		area.get_node("Sprite2D").set_z_index(1)

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
	call_deferred("reparent_helper", area)
	# must happen after reparenting
	call_deferred("reposition", area)
	# set timer and sink (disappear) the colony after a couple seconds
	var sink_time = Timer.new()
	sink_time.autostart = true
	area.add_child(sink_time)
	sink_time.set_wait_time(2.0)
	sink_time.start(2.0)
	sink_time.connect("timeout",Callable(self,"_on_sink_timer").bind(area))
	
func _on_sink_timer(area):
	print("Sink timed out", area)
	area.get_parent().queue_free()

func do_colonize(area):
#	print("Colony released")
	if not has_node("colony") and not has_colony() is StringName:
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
		call_deferred("reparent_helper", area)
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
	if not ship.is_in_group("drone"):
		print("Planet orbited " + str(get_node("Label").get_text()) + "; orbiter: " + str(orbiter.get_parent().get_name()))

	var rel_pos = orbiter.get_global_position() * get_node("orbit_holder").get_global_transform()
	
	
	orbiter.get_parent().set_position(Vector2(0,0))
	orbiter.set_position(Vector2(0,0))
	orbiter.pos = Vector2(0,0)

	#print("Rel pos: " + str(rel_pos))
	
	# fix offset due to drone scale
	#print("Scale:" + str(orbiter.get_parent().scale))
	orbiter.set_position(rel_pos*(Vector2(1,1)/orbiter.get_parent().scale))
	
	var _a = atan2(rel_pos.x, rel_pos.y)
#	var a = atan2(200,0)

	#print("Initial angle " + str(a))
	
	# redraw (debugging)
	queue_redraw()

func remove_orbiter(ship):
	var sh = orbiters.find(ship)
	if sh != -1:
		orbiters.remove_at(sh)

func _on_planet_deorbited(ship):
	remove_orbiter(ship)
	# redraw (debugging)
	queue_redraw()
	if not ship.is_in_group("drone"):
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
			#print("Found hostile orbiter: " + str(o.get_parent().get_name()))
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

# add or remove the mark showing that we have colonies available
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
				node = String(l.get_name())
	
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
		# vary increase based on how big we are already
		var factor = population/8500.0
		var fact = clampf(factor, 0.01, 1.0) # to ensure no negative natural growth
		var growth_rate = lerpf(0.0125, 0.0001, fact) # just by eyeballing historical stats (max is around 2.0% i.e. 0.02)
		var change = growth_rate*population # in millions
		# clamp to prevent gaining billions at one tick
		change = clampf(change, 0.00001, 750.0)
		print(get_node("Label").get_text(), " factor ", factor, " fact ", fact, " growth rate: ", "%.2f" % (growth_rate*100), "%", " growth: %.2f M " % change)
		population += change #1/1000.0 # 1K in milions
	
	# does it have enough pop for a colony?
	if population > 51/1000.0: # in milions
		update_HUD_colony_pop(self, true)

	# not in original Stellar Frontier: tint us gray to represent pollution
	if atm > 0.01:
		# thresholds are completely arbitrary
		if population > 8000.0:
			get_node("Sprite2D").set_modulate(Color(0.75, 0.75, 0.75, 1.0))
		if population > 3000.0:
			get_node("Sprite2D").set_modulate(Color(0.65, 0.65, 0.65, 1.0))
		if population > 500.0: # 0.5B or 500M
			get_node("Sprite2D").set_modulate(Color(0.5, 0.5, 0.5, 1.0)) # tint light gray
		
		
		
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
		if "CARBORUNDUM" in storage and storage["CARBORUNDUM"] >= 2 and "PLASTICS" in storage and storage["PLASTICS"] >= 2:
			enough = true
		
	return enough

func _on_module_timer_timeout():
	if has_colony() and enough_materials() and not enough_modules():
		# remove materials
		storage["CARBORUNDUM"] -= 2
		storage["PLASTICS"] -= 2
		
		#print("Module timer")
		var pos = get_global_position()
		var mo = module.instantiate()
		
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


func toggle_shadow_anim():
	if is_in_group("moon"):
		get_node("AnimationPlayer").get_animation("scanning").track_set_enabled(1, false)
	else:
		get_node("AnimationPlayer").get_animation("scanning").track_set_enabled(1, true)

func _on_AnimationPlayer_animation_finished(_anim_name):
	if is_in_group("moon"):
		get_node("Sprite_shadow").hide()
