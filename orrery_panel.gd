extends Panel

# Declare member variables here
# weird fudge
var center = Vector2(80, 80) + Vector2(1,2)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# draw orbits

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
	draw_polyline(circle, Color(1,0,0), 2.0)

func _draw():
	if not is_visible():
		return
	
	#draw_circle(center, 24, Color(1,0,0))
	var fudge = 0 #2.5
	
	for p in get_parent().planets:
		#var fudge = 36*p.planet_rad_factor*0.2
		#print(str(fudge))
		draw_empty_circle(make_circle(center, 24, int(p.dist/get_parent().zoom_scale) +fudge))
