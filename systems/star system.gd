@tool
extends Node2D

# this is for systems that are generated based on csv

# class member variables go here, for example:
@export var rotation_rate = 0.15
@export var orbit_rate = 0.00002
@export var star_radius_factor = 1.0
@export var luminosity = 1.00 # 1 is the luminosity of the Sun

var star_types = { RED_DWARF = 0, ORANGE = 1, YELLOW = 2, BLUE = 3, WHITE = 4, BLACK = 5, BROWN_DWARF = 6 }
var star_type = 0 # default

var hz_inner = 0.9 #dummy, in AU
var hz_outer = 1.1

var rot = 0
var orbit_rot = 0

@onready var sprite = $"Sprite2D"
@onready var planets = $"planet_holder"

# for minimap
@export var zoom_scale = 12
@export var custom_orrery_scale = 0
@export var custom_map_scale = 0

# data
var data = []

var type_lookup = { "yellow" = 2, "red" = 0 }

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	print("[Star system] Star system init: ", get_name())
	# load data
	data = load_data(get_name())
	var sol = get_name().find("Sol")
	#print("Star system is sol: ", sol)
	var atm = sol != 0
	#print("Atm is:", atm);
	var star_type = null
	
	if data != null:
		for line in data:
			# line is [name, angle, dist, (mass), (radius), type]
			#print(str(line))
			
			if line.size() > 4 and "star" in line[4]:
				# reuse column 1 as luminosity
				luminosity = float(line[1])
				print("Set luminosity to ", luminosity)
				# use type column as hint to type
				star_type = line[4].lstrip("star (").rstrip(")")
				print("Star type from data: ", star_type)
				if star_type == "":
					star_type = "red"
				
				# fix star type reported by HUD	
				self.star_type = type_lookup[star_type]
				continue
			
			# match rows to planets
			for c in get_node("planet_holder").get_children():
				if c.has_node("Label"):
					var nam = c.get_node("Label").get_text()
					if line[0] == nam:
						#print("Name fits, setup @ " + str(line[1]) + " d: " + str(line[2]) + " m:" + str(line[3]))
						# for planets, distance is given in AU
						# the measure of mass varies by type
						# by default, plain Earth masses
						var mas = float(line[3])
						# for moons or dwarf planets, Moon masses
						if line[4] == " dwarf_planet":
							mas = float(line[3])*game.MOON_MASS
							atm = false
						# asteroids are given in Ceres masses (because otherwise the numbers'd be vanishingly small)
						var Ceres = 0.0128*game.MOON_MASS
						#print(str(Ceres))
						if line[4] == " asteroid":
							mas = float(line[3])*Ceres
							atm = false
						
						var rad = 0
						if line.size() > 4:
							rad = float(line[4])
							
						c.setup(int(line[1]), float(line[2])*game.AU, mas, rad, atm)
						# Planets in solar system start pre-scanned
						if sol == 0:
							c.scanned = true
				# moons
				if c.has_node("orbit_holder"):
					for m in c.get_node("orbit_holder").get_children():
						var nam = m.get_node("Label").get_text()
						if line[0] == nam:
							# for moons, distance is absolute
							#print("Name fits, setup @ " + str(line[1]) + " d: " + str(line[2]))
							var mas = 0
							# if we have a mass and our type is moon
							if line[3] != " moon" and line[4] == " moon":
								mas = float(line[3])*game.MOON_MASS
								
							m.setup(int(line[1]), int(line[2]), mas)
							# Planets in solar system start pre-scanned
							if sol == 0:
								m.scanned = true
					
			#if data[3] == "planet":
	# if no csv
	else:
		print("[Star system] No csv..")
		for c in get_node("planet_holder").get_children():
			if c.is_in_group("planets"):
				c.setup(0,0,0,0,true)
				# moons
				for m in c.get_node("orbit_holder").get_children():
					m.setup(0,0,0,0,false)
		# default to red
		star_type = "red"
	
	
	var hzs = calculate_hz(luminosity, star_type)
	hz_inner = hzs[0]
	hz_outer = hzs[1]

func load_data(name):
	#var file = FileAccess.new()
	var opened = FileAccess.open("res://systems/"+str(name)+"_system.csv", FileAccess.READ)
	if opened != null and opened.get_error() == OK:
		while !opened.eof_reached():
			var csv = opened.get_csv_line()
			if csv != null:
				# skip header
				if csv[0] == "name":
					continue
				# skip empty lines
				if csv.size() > 1:
					data.append(csv)
					#print(str(csv))
	
		opened.close()
		return data

func get_star_type(sel):
	# swap the dictionary around
	var reverse = {}
	
	for i in range(star_types.keys().size()):
#		print(str(i))
#		print(str(star_type.keys()[i]))
		reverse[i] = star_types.keys()[i]
	
	print(str(reverse))

	if reverse.has(sel):
		return reverse[reverse.keys().find(sel)]


func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	if not Engine.is_editor_hint():
		# rotate the star sprite
		rot += rotation_rate * delta
		sprite.set_rotation(rot)
		
		orbit_rot += orbit_rate * delta
		planets.set_rotation(orbit_rot)


# http://www.solstation.com/habitable.htm
# Kasting et al, 1993
# d = (1 AU) * [ (L = Lsun) / Seff ] 0.5
func calculate_hz(lum, type="red"):
	# "normalized solar flux factor" values for a G-type star and M-type
	var factors = {"yellow": [1.41, 0.36], "red": [1.05, 0.27]}
	var inner = 1 * pow(lum / factors[type][0], 0.5)
	var outer = 1 * pow(lum / factors[type][1], 0.5)
	print(type, " hz: inner: ", inner, " AU, outer: ", outer, " AU")
	return [inner, outer]
	
# Venus Zone; inner border = cosmic shoreline; outer = recent Venus CHZ
# recent Venus solar flux factor (Seff) is 1.776 per https://arxiv.org/abs/1301.6674 https://arxiv.org/abs/1404.5292 
# cosmic shoreline: Solar flux = 5* 10^-16*escape_vel^4 or 25* Earth's solar flux (http://arxiv.org/abs/1409.2886)
# Earth's solar flux is 1360 Wm^-2
func calculate_vz(lum):
	var outer = 1 * pow(lum/1.776, 0.5)
	return [outer]

# based on arc functions that I seem to love :P	
func make_circle(center, segments, radius):
	var points_arc = PackedVector2Array()
	var angle_from = 0
	var angle_to = 360

	for i in range(segments+1):
		var angle_point = angle_from + i*(angle_to-angle_from)/segments - 90
		var point = center + Vector2( cos(deg_to_rad(angle_point)), sin(deg_to_rad(angle_point)) ) * radius
		points_arc.push_back( point )
	
	return points_arc	

func draw_empty_circle(circle):
	draw_polyline(circle, Color(0,1,0), 2.0)		
	
#func _draw():
#	# if Engine.is_editor_hint():
#
#	draw_empty_circle(make_circle(Vector2(0,0), 24, hz_inner*AU))
#	draw_empty_circle(make_circle(Vector2(0,0), 24, hz_outer*AU))
#
##	draw_line(Vector2(0,0), Vector2(0,600), Color(0,1,0))
#	pass
