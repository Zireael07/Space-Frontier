extends Control

var octree_data = {}
var font

# Called when the node enters the scene tree for the first time.
func _ready():
	font = get_theme_default_font()
	# this would match the galaxy.gd assumptions about sectors
	#octree_data = octree_divide(AABB(Vector3(-512, -512, -512), Vector3(1024, 1024, 1024)))
	
	# test purposes: scale down by half
	octree_data[-1] = octree_divide(AABB(Vector3(-256, -256, -256), Vector3(512, 512, 512)))
	
	# test
	#var o = octree_data[-1][7]
	#octree_data[7] = octree_divide(AABB(o[0], o[1]-o[0]))

	for o_i in octree_data[-1].size():
		var o = octree_data[-1][o_i]
		octree_data[o_i] = octree_divide(AABB(o[0], o[1]-o[0]))
	
	#print(octree_data)
	
	#print(octree_data[1])
	
	# test searching (start node exactly equal to AABB above)
	nearest(Vector3(10, 10, 2), [512+512+512, null], [Vector3(-256, -256, -256), Vector3(256, 256, 256)], -1)
	
	#queue_redraw()
	

func octree_divide(bounds):
	#var half = bounds.size.y/2.0; # assumes x=y i.e. cubic octants
	var center = bounds.get_center()
	
	var octants = []
	# for simplicity, assume positive size (i.e. position is always the smallest)
	# https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/introduction-to-octrees-r3529/
	# this list is position and end, i.e. AABB constructor will be position, end-position (i.e. size)
	
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

# ref: https://chidiwilliams.com/post/quadtrees/
func nearest(pos, best, node, n_i=-2):
	print("Looking for nearest to ", pos, " node: ", node, " n_i: ", n_i)
	# At each node of the quadtree, we check to see if the node has been subdivided.
	# If it has, we recursively check its child nodes. Importantly, we’ll check the child node that contains the search location first, before checking the other child nodes.3
	# When we get to a node that has not been subdivided, we’ll loop through all its points and return the point nearest to the search location.
	# As we recurse back up the tree, when we get to a node that is farther away than the nearest point we’ve found, we can safely discard that quadrant without checking its child quadrants or points.

	# Exclude if node is farther away than best distance
	if pos.x < node[0].x - best[0] || pos.x > node[1].x + best[0] || pos.y < node[0].y - best[0] || pos.y > node[1].y + best[0] || pos.z < node[0].z - best[0] || pos.z > node[0].z + best[0]:
		return best
	
	# Now test points in the node if doesn't have children
	if n_i == -2:
		print("Should test points within node... ", node)
		# get list of all points within node
		var aabb = AABB(node[0], node[1]-node[0])
		var test_data = [Vector3(30, 30, -2), Vector3(0,0,0), Vector3(-50, 20, 5), Vector3(25, -20, 2), Vector3(8, 10, 0), Vector3(18, 15, -3), Vector3(9, 7, 10)]
		for p in test_data:
			if aabb.has_point(p):
				print("Distance check for point within node: ", p)
				# now check for distance
				# this only returns one
				if pos.distance_to(p) < best[0]:
					best = [pos.distance_to(p), p]
		
		print("Best point found: ", best)
		return best
	
	# check each axis for most likely neighbors
	# ref: https://gist.github.com/patricksurry/6478178
	var ew = (2*pos.x > node[0].x + node[1].x)
	var sn = (2*pos.y > node[0].y + node[1].y)
	var bf = (2*pos.z > node[0].z + node[1].z)
	
	print("east or west:", ew, " south or north: ", sn, " front or back: ", bf)
	
	# now recurse into octants deemed most likely
	if !ew and !sn and !bf:
		nearest(pos, best, octree_data[n_i][0], 0 if n_i == -1 else -2)
	if ew and !sn and bf:
		nearest(pos, best, octree_data[n_i][1], 1 if n_i == -1 else -2)
	if ew and sn and bf:
		nearest(pos, best, octree_data[n_i][6], 6 if n_i == -1 else -2)
	if ew and sn and !bf:
		nearest(pos, best, octree_data[n_i][4], 4 if n_i == -1 else -2)

func _draw():
	draw_string(font, Vector2(250, 0), "X-Y axis front")
	draw_string(font, Vector2(800,0), "X-Y axis 2nd Z layer (back)")
	#draw_string(font, Vector2(800, 0), "X-Z axis")
	
	# cyan for front, red for back (mirrors cyan for positive Z-axis and red for neg used on map)
	
	for n in octree_data:
		for o_i in octree_data[n].size():
			var o = octree_data[n][o_i]
			
			# 0 is position, 1 is end and we want size so 0-1
			# XY axis for both front and back
			var offset = 550 if o[0].z != octree_data[-1][0][0].z else 0 # if our Z is different than start octant's
			var color = Color(1,0,0) if offset == 0 else Color(0,1,1)
			if n == 1:
				color = Color(0,1,0) # debug
			draw_rect(Rect2(Vector2(o[0].x+offset, o[0].y), Vector2(o[1].x-o[0].x, o[1].y-o[0].y)), color, false, 3.0)
			
			#draw_string(font, Vector2(o[0].x+offset, o[0].y), str(o_i))
				
			
			# XZ axis (offset by 550 to the right AND differently colored)
			#draw_rect(Rect2(Vector2(o[0].x+550, o[0].z), Vector2(o[1].x-o[0].x, o[1].z-o[0].z)), Color(0,0,1), false, 3.0)
			#draw_string(font, Vector2(o[0].x+550, o[0].y), str(o_i))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
