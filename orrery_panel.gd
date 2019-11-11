# this draws below the orrery container
extends Panel

# Declare member variables here
# weird fudge
var center = Vector2(80, 80) + Vector2(1,2)

# TODO: put them somewhere global for the whole game to use
const LIGHT_SEC = 400	# must match LIGHT_SPEED for realism
const LS_TO_AU = 30 #500 realistic value
const AU = LS_TO_AU*LIGHT_SEC

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



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

func draw_empty_circle(circle, color):
	draw_polyline(circle, color, 2.0)

func _draw():
	if not is_visible():
		return
	
	#draw_circle(center, 24, Color(1,0,0))
	var fudge = 0 #2.5
	# draw orbits
	for p in get_parent().planets:
		#var fudge = 36*p.planet_rad_factor*0.2
		#print(str(fudge))
		draw_empty_circle(make_circle(center, 24, int(p.dist/get_parent().zoom_scale) +fudge), Color(1,0,0))
	
	# draw star hz
	var star = get_parent().stars[0]
	draw_empty_circle(make_circle(center, 24, int((star.hz_inner*AU)/get_parent().zoom_scale) + fudge), Color(0,1,0))
	draw_empty_circle(make_circle(center, 24, int((star.hz_outer*AU)/get_parent().zoom_scale) + fudge), Color(0,1,0))
