tool
extends Node2D

# class member variables go here, for example:
export var rotation_rate = 0.15
export var orbit_rate = 0.00002
export var star_radius_factor = 1.0
export var luminosity = 1.00 # 1 is the luminosity of the Sun

var hz_inner = 0.9 #dummy, in AU
var hz_outer = 1.1

var rot = 0
var orbit_rot = 0

onready var sprite = $"Sprite"
onready var planets = $"planet_holder"

# for minimap
export var zoom_scale = 12
export var custom_orrery_scale = 0

# data
var data = []

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	print("[Star system] Star system init")
	# load data
	data = load_data(get_name())
	
	if data != null:
		for line in data:
			# line is [name, angle, dist, (mass), type]
			print(str(line))
			# match rows to planets
			for c in get_node("planet_holder").get_children():
				if c.has_node("Label"):
					var nam = c.get_node("Label").get_text()
					if line[0] == nam:
						print("Name fits, setup @ " + str(line[1]) + " d: " + str(line[2]) + " m:" + str(line[3]))
						# for planets, distance is given in AU
						# the measure of mass varies by type
						# by default, plain Earth masses
						var mas = float(line[3])
						# for moons or dwarf planets, Moon masses
						if line[4] == " dwarf_planet":
							mas = float(line[3])*game.MOON_MASS
						# asteroids are given in Ceres masses (because otherwise the numbers'd be vanishingly small)
						var Ceres = 0.0128*game.MOON_MASS
						#print(str(Ceres))
						if line[4] == " asteroid":
							mas = float(line[3])*Ceres
							
						c.setup(int(line[1]), float(line[2])*game.AU, mas)
				# moons
				if c.has_node("orbit_holder"):
					for m in c.get_node("orbit_holder").get_children():
						var nam = m.get_node("Label").get_text()
						if line[0] == nam:
							# for moons, distance is absolute
							print("Name fits, setup @ " + str(line[1]) + " d: " + str(line[2]))
							var mas = 0
							# if we have a mass and our type is moon
							if line[3] != " moon" and line[4] == " moon":
								mas = float(line[3])*game.MOON_MASS
								
							m.setup(int(line[1]), int(line[2]), mas)
					
			#if data[3] == "planet":
	# if no csv
	else:
		print("[Star system] No csv..")
		for c in get_node("planet_holder").get_children():
			if c.is_in_group("planets"):
				c.setup()
				# moons
				for m in c.get_node("orbit_holder").get_children():
					m.setup()
	
	var hzs = calculate_hz(luminosity)
	hz_inner = hzs[0]
	hz_outer = hzs[1]

func load_data(name):
	var file = File.new()
	var opened = file.open("res://systems/"+str(name)+"_system.csv", file.READ)
	if opened == OK:
		while !file.eof_reached():
			var csv = file.get_csv_line()
			if csv != null:
				# skip header
				if csv[0] == "name":
					continue
				# skip empty lines
				if csv.size() > 1:
					data.append(csv)
					#print(str(csv))
	
		file.close()
		return data

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
func calculate_hz(lum):
	# "normalized solar flux factor" values for a G-type star
	var inner = 1 * pow(lum / 1.41, 0.5)
	var outer = 1 * pow(lum / 0.36, 0.5)
	
	return [inner, outer]

# based on arc functions that I seem to love :P	
func make_circle(center, segments, radius):
	var points_arc = PoolVector2Array()
	var angle_from = 0
	var angle_to = 360

	for i in range(segments+1):
		var angle_point = angle_from + i*(angle_to-angle_from)/segments - 90
		var point = center + Vector2( cos(deg2rad(angle_point)), sin(deg2rad(angle_point)) ) * radius
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
