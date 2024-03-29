@tool
extends Node2D

# class member variables go here, for example:
@export var rotation_rate = 0.15
@export var orbit_rate = 0.00002
@export var star_radius_factor = 1.0
@export var luminosity = 1.00 # 1 is the luminosity of the Sun

var hz_inner = 0.9 #dummy, in AU
var hz_outer = 1.1

var rot = 0
var orbit_rot = 0

@onready var sprite = $"Sprite2D"
#onready var planets = $"planet_holder"
var planets = null

var star_types = { RED_DWARF = 0, ORANGE = 1, YELLOW = 2, BLUE = 3, WHITE = 4, BLACK = 5, BROWN_DWARF = 6 }
var star_type = 0

# for minimap
@export var zoom_scale = 12
@export var custom_orrery_scale = 0
@export var custom_map_scale = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	if has_node("planet_holder"):
		planets = get_node("planet_holder")
		for c in get_node("planet_holder").get_children():
			if c != null and c.is_in_group("planets"):
				c.setup()
				# moons
				for m in c.get_node("orbit_holder").get_children():
					m.setup()
	
	var hzs = calculate_hz(luminosity)
	hz_inner = hzs[0]
	hz_outer = hzs[1]

func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	if not Engine.is_editor_hint():
		# rotate the star sprite
		rot += rotation_rate * delta
		sprite.set_rotation(rot)
		
		if planets != null:
			orbit_rot += orbit_rate * delta
			planets.set_rotation(orbit_rot)


# http://www.solstation.com/habitable.htm
# formula from Kasting et al, 1993
# d = (1 AU) * [ (L = Lsun) / Seff ] 0.5
func calculate_hz(lum,  type="yellow"):
	# "normalized solar flux factor" Seff values from Kaltenegger et al 2010
	var factors = {"yellow": [1.41, 0.36], "red": [1.05, 0.27], "orange": [1.05, 0.27], "F": [1.90, 0.46]}
	var inner = 1 * pow(lum / factors[type][0], 0.5)
	var outer = 1 * pow(lum / factors[type][1], 0.5)
	
	return [inner, outer]

# Venus Zone; inner border = cosmic shoreline; outer = recent Venus CHZ
# recent Venus solar flux factor (Seff) is 1.776 per https://arxiv.org/abs/1301.6674 https://arxiv.org/abs/1404.5292 
# cosmic shoreline: Solar flux = 5* 10^-16*escape_vel^4 or 25* Earth's solar flux (http://arxiv.org/abs/1409.2886)
# Earth's solar flux is 1360 Wm^-2
func calculate_vz(lum):
	var outer = 1 * pow(lum/1.776, 0.5)
	return [outer]

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
