tool
extends Node2D

# class member variables go here, for example:
export var rotation_rate = 0.15
export var orbit_rate = 0.00002
export var star_radius_factor = 1.0
export var luminosity = 1.00 # 1 is the luminosity of the Sun

# TODO: put them somewhere global for the whole game to use
const LIGHT_SEC = 400	# must match LIGHT_SPEED for realism
const LS_TO_AU = 30 #500 realistic value
const AU = LS_TO_AU*LIGHT_SEC

var hz_inner = 0.9 #dummy, in AU
var hz_outer = 1.1

var rot = 0
var orbit_rot = 0

onready var sprite = $"Sprite"
onready var planets = $"planet_holder"

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	var hzs = calculate_hz(luminosity)
	hz_inner = hzs[0]
	hz_outer = hzs[1]
	pass

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
func calculate_hz(luminosity):
	# "normalized solar flux factor" values for a G-type star
	var inner = 1 * pow(luminosity / 1.41, 0.5)
	var outer = 1 * pow(luminosity / 0.36, 0.5)
	
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
	
func _draw():
	# if Engine.is_editor_hint():
	
	draw_empty_circle(make_circle(Vector2(0,0), 24, hz_inner*AU))
	draw_empty_circle(make_circle(Vector2(0,0), 24, hz_outer*AU))
	
#	draw_line(Vector2(0,0), Vector2(0,600), Color(0,1,0))
	pass