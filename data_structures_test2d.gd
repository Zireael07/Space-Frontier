extends Control

var octree_data = []
var font

# Called when the node enters the scene tree for the first time.
func _ready():
	font = get_theme_default_font()
	# this would match the galaxy.gd assumptions about sectors
	#octree_data = octree_divide(AABB(Vector3(-512, -512, -512), Vector3(1024, 1024, 1024)))
	
	# test purposes: scale down by half
	octree_data = octree_divide(AABB(Vector3(-256, -256, -256), Vector3(512, 512, 512)))
	
	# test
	var o = octree_data[7]
	octree_data.append_array(octree_divide(AABB(o[0], o[1]-o[0])))
	#o = octree_data[5]
	#octree_data.append_array(octree_divide(AABB(o[0], o[1]-o[0])))
	#for o in octree_data:
	#	octree_data.append_array(octree_divide(AABB(o[0], o[1]-o[0])))
	
	queue_redraw()
	

func octree_divide(bounds):
	#var half = bounds.size.y/2.0; # assumes x=y i.e. cubic octants
	var center = bounds.get_center()
	
	var octants = []
	# for simplicity, assume positive size (i.e. position is always the smallest)
	# https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/introduction-to-octrees-r3529/
	# for AABB: position and end, i.e. AABB constructor will be position, end-position (i.e. size)
	
	# "front" means closer to bounds.position
	# 0 = (F)NW
	octants.append([bounds.position, center])
	# 1 = (F)NE
	octants.append([Vector3(center.x, bounds.position.y, bounds.position.z), Vector3(bounds.end.x, center.y, center.z)])
	# 2 = (B)NE
	octants.append([Vector3(center.x, bounds.position.y, center.z), Vector3(bounds.end.x, center.y, bounds.end.z)])
	# 3 = (B)NW
	octants.append([Vector3(bounds.position.x, bounds.position.y, center.z), Vector3(center.x, center.y, bounds.end.z)])
	# 4 = (F)SE
	octants.append([Vector3(bounds.position.x, center.y, bounds.position.z), Vector3(center.x, bounds.end.y, center.z)])
	# 5 = (F)SW
	octants.append([Vector3(center.x, center.y, bounds.position.z), Vector3(bounds.end.x, bounds.end.y, center.z)])
	# 6 = (B)SE
	octants.append([center, bounds.end])
	# 7 = (B)SW
	octants.append([Vector3(bounds.position.x, center.y, center.z), Vector3(center.x, bounds.end.y, bounds.end.z)])
	
	#print(octants)
		
	return octants

func _draw():
	draw_string(font, Vector2(250, 0), "X-Y axis front")
	draw_string(font, Vector2(800,0), "X-Y axis 2nd Z layer (back)")
	#draw_string(font, Vector2(800, 0), "X-Z axis")
	
	# cyan for front, red for back (mirrors cyan for positive Z-axis and red for neg used on map)
	
	for o_i in octree_data.size():
		var o = octree_data[o_i]
		# 0 is position, 1 is end and we want size so 0-1
		# XY axis for both front and back
		var offset = 550 if o[0].z != octree_data[0][0].z else 0
		draw_rect(Rect2(Vector2(o[0].x+offset, o[0].y), Vector2(o[1].x-o[0].x, o[1].y-o[0].y)), Color(1,0,0) if offset == 0 else Color(0,1,1), false, 3.0)
		
		#draw_string(font, Vector2(o[0].x+offset, o[0].y), str(o_i))
			
		
		# XZ axis (offset by 550 to the right AND differently colored)
		#draw_rect(Rect2(Vector2(o[0].x+550, o[0].z), Vector2(o[1].x-o[0].x, o[1].z-o[0].z)), Color(0,0,1), false, 3.0)
		#draw_string(font, Vector2(o[0].x+550, o[0].y), str(o_i))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
