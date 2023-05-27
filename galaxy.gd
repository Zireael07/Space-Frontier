extends Node
# remaining stuff is implemented in hud/star map.gd, usually due to use of child nodes/drawing


# Declare member variables here. Examples:
# data
var data = []
# map
var map_graph = []
var map_astar = null
# problem: we have coordinates (3 floats) and we need to have a unique identifier per star
# idenfifier must be an int because AStar3D uses integer ids
# as of Godot 4 those ids are int64
var mapping = {}

# helpers
func sign_to_bit(sign):
	if sign < 0:
		return 1
	else:
		return 0
		
func bit_to_sign(bit):
	if bit > 0:
		return -1
	else:
		return 1

# https://stackoverflow.com/questions/65706804/bitwise-packing-unpacking-generalized-solution-for-arbitrary-values
# for some reason this (just like collapsing 3D to 1D index) only works for positive numbers
# https://stackoverflow.com/questions/6556961/use-of-the-bitwise-operators-to-pack-multiple-values-in-one-int/6557022#6557022

# this applies to storing positions in a sector - which are coded as ints to avoid floating points
# and stored as positive coords (starting from sector begin) so we need values up to 999 (i.e. up to 99.9ly away from sector begin)
# storing unsigned positions wouldn't help because we'd save one bit but need a bit for sign
# no component can be bigger then 999 that means we need 10 bits of storage per component (allows numbers up to 1014).

# pack sector too since we have 32 more bits to play with in Godot 4
# without that, packing/unpacking won't work properly for other sectors
# we have enough bits that we can pack signed numbers too since a sign is just a single bit more
# NOTE: output needs to be positive since Godot AStar only accepts positive ids
func pack_data(vec3, sector):
	#print("sign bits: " , int(sign(sector[0])), " ", int(sign(sector[1])))
	#print("bits: ", int(sign_to_bit(sign(sector[0]))), " ", int(sign_to_bit(sign(sector[1]))) )
	
	# sector[1] sign bit << (all the sizes) | sector[1] << ... | sector[0] sign bit << .. | sector[0] << (size1+size2+size3) 
	# packed vector = v3 << (size1 + size2) | v2 << size1 | v1;
	return (int(sign_to_bit(sign(sector[1]))) << (10+10+10+10+10+1) | int(abs(sector[1])) << (10+10+10+10+1) | int(sign_to_bit(sign(sector[0]))) << (10+10+10+10) | int(abs(sector[0])) << (10+10+10) | int(vec3.z) << (10 + 10) | int(vec3.y) << 10 | int(vec3.x))

func unpack_sector(id):
	var mask = ((1 << 10) -1) # this preserves 10 rightmost bits
	var sign_mask = ((1 << 10) -1)
	
	# the last 30 bits are vector coords (10 for x, 10 for y 10 for z)
	var offset = 30
	
	var sec0 = id >> 30 & mask
	var sign0 = id >> 30+10 & sign_mask
	var sec1 = id >> 30+(1+10) & mask
	var sign1 = id >> 30+(1+10+10) & sign_mask
	
	#print("Decoded sector data: ", " s: ", sign0, " sec0: ", sec0, " s1: ", sign1, " sec2: ", sec1)
	print("Decoded sector: ", [bit_to_sign(sign0)*sec0, bit_to_sign(sign1)*sec1])
	return [bit_to_sign(sign0)*sec0, bit_to_sign(sign1)*sec1]
	
func unpack_vector(id):
	#var sample1 = int(pow(2,10+1)-1) #511 (8+1) #1023 (9+1) #2047 (10+1); #pow(2, 10+1)-1;
	#var sample2 = int(pow(2,10+1)-1) #pow(2,10+1)-1;
	#print(sample1)
	
	var mask = ((1 << 10) - 1) # mask hides all the bits of the left except the 10 rightmost
	var v1 = (id >> 0) & mask
	var v2 = (id >> 10) & mask
	var v3 = id >> (10 + 10) & mask
	return Vector3(v1, v2, v3)

func float_to_int(vec3):
	#print("original: ", vec3)
	# TODO: Godot4 - use Vector3i here
	# integer that represents a float with one decimal place (shave off the last to know the decimals)
	return Vector3(int(float("%.1f" % vec3.x)*10),int(float("%.1f" % vec3.y)*10), int(float("%.1f" % vec3.z)*10))

func float_to_int2(vec2):
	# integer that represents a float with one decimal place (shave off the last to know the decimals)
	return Vector2(int(float("%.1f" % vec2.x)*10),int(float("%.1f" % vec2.y)*10))

func pos_offset_from_sector_zero(vec3):
	# assume the sector is 50 ly in each direction, extended to closest power of 2
	# a digit was added to represent a decimal place (see above)
	var sector_start = Vector3(-512,-512,-512)
	var pos = Vector3(vec3.x-sector_start.x, vec3.y-sector_start.y, vec3.z-sector_start.z)
	return pos

# NOTE: these two need to account for other sectors!!!
# NOTE: this vec3 is the INTERNAL star data
func pos_to_positive_pos(vec3):
	var sector = pos_to_sector(Vector3(vec3.x, -vec3.y, vec3.z), false)
	var sector_zero_start = Vector2(-512,-512)
	# unlike other examples we need
	var sector_start_2d = Vector2(sector[0]*1024, -sector[1]*1024)+sector_zero_start
	var sector_start = Vector3(sector_start_2d.x, sector_start_2d.y, -512)
	#var sector_start = Vector3(-512,-512,-512)
	var pos = Vector3(vec3.x-sector_start.x, vec3.y-sector_start.y, vec3.z-sector_start.z)
	#print("original: ", vec3, " positive: ", pos, " sector ", sector)
	# test
	#positive_to_original(pos, sector)
	
	if pos.x < 0 or pos.y < 0 or pos.z < 0:
		print("ERROR! negative coord detected ", pos)
	
	return [pos, sector]
	
func positive_to_original(vec3, sector=[0,0]):
	#var sector_start = Vector3(-512,-512,-512)
	var sector_zero_start = Vector2(-512,-512)
	var sector_start_2d = Vector2(sector[0]*1024, -sector[1]*1024)+sector_zero_start
	var sector_start = Vector3(sector_start_2d.x, sector_start_2d.y, -512)
	var pos = Vector3(vec3.x+sector_start.x, vec3.y+sector_start.y, vec3.z+sector_start.z)
	#print("positive: ", vec3, " original: ", pos)
	return pos

# "want to determine which face encloses a point in world space, use floor instead of round" - Amit
# NOTE: this assumes "visual"/map coords, i.e. +Y increases as we go down the map
func pos_to_sector(pos, need_convert=true):
	print("Determining sector for: ", pos)
	
	if need_convert:
		pos = float_to_int(pos)
	
	# "how is our position offset compared to start of sector 0?"
	pos = pos_offset_from_sector_zero(pos)
	print("Pos offset from beginning of sector 0: ", pos)
	# 1024 is the sector size
	# divide by tile size to get grid coordinates
	#var sector = [floor((pos.x-512)/1024), floor((pos.y-512)/1024)] ##, floor((pos.z-512)/1024)]
	var sector = [floor(pos.x/1024), floor(pos.y/1024)]
	print("Sector", sector)
	# NOTE: the way this is calculated implies that those go the same way as Godot visual coords
	# i.e. +Y goes down
	return sector

# more generic version of the below function
func quadrants(begin, size_x, size_y, debug=true):
	print("Begin: ", begin, " x: ", size_x, " y: ", size_y)
	# divide into four quads
	var nw = Rect2(begin.x, begin.y, size_x, size_y).abs()
	var ne = Rect2(begin.x+size_x, begin.y, size_x, size_y).abs()
	var se = Rect2(begin.x+size_x, begin.y+size_y, size_x, size_y).abs()
	var sw = Rect2(begin.x, begin.y+size_y, size_x, size_y).abs()
	if debug:
		print("Quadrants: ", [nw, nw.end, ne, ne.end, se, se.end, sw, sw.end])
	return [nw, ne, se, sw]
	

func sector_to_quadrants(sector_begin):
	# center of sector is sector_begin + half sector size (half of 1024)
	var center = Vector2(sector_begin.x+512, sector_begin.y+512)
	#print("Center: ", center)
	# divide into four quads
	var nw = Rect2(sector_begin.x, sector_begin.y, 512, 512)
	var ne = Rect2(sector_begin.x+512, sector_begin.y, 512, 512)
	var se = Rect2(sector_begin.x+512, sector_begin.y+512, 512, 512)
	var sw = Rect2(sector_begin.x, sector_begin.y+512, 512, 512)
	#print("Quadrants: ", [nw, nw.end, ne, ne.end, se, se.end, sw, sw.end] )
	return [nw, ne, se, sw]

func save_graph_data(x,y,z, nam):
	map_graph.append([x,y,z, nam])
	
	# skip any stars outside the sector
	if x < -50 or y < -50 or z < -50:
		# test
		#pos_to_sector(Vector3(x,y,z))
		return
	
	# doing some magic to ensure we stay within AStar3D's id bounds (2^64 in Godot 4 now)
	var pos_data = pos_to_positive_pos(float_to_int(Vector3(x,y,z)))
	var id = pack_data(pos_data[0], pos_data[1])
	print("ID: ", id, "; unpacked: ", unpack_sector(id))
	
	
	#print("Nearest po2: ", nearest_po2(id)) # 2^30 for storing 3*2^10 max
	#print("AStar3D overflow: ", id > (pow(2,31)-1)) # 2^31-1
	
	mapping[float_to_int(Vector3(x,y,z))] = id
	
	# the global scope function returns an integer hash
	# hashes can collide so we're not using them (or overflow if data is limited to 2^32-1)
	#mapping[Vector3(x,y,z)] = hash(Vector3(x,y,z))
	# https://godotengine.org/qa/43078/create-an-unique-id
	#mapping[Vector3(x,y,z)] = Vector3(x,y,z).get_instance_id()

	
func strip_units(entry):
	var num = 0.0
	if "ly" in entry:
		num = float(entry.rstrip("ly"))
	elif "pc" in entry:
		num = float(entry.rstrip("pc"))*3.26
	return num

# based on Winchell Chung's Star3D spreadsheet and 
# http://starmap.whitten.org/files/src/gal_pl.txt
# input in degrees by default!!!
# output is in whatever unit dist used (light years in my case)
func galactic_from_ra_dec(ra, dec, dist):
	# Find Equatorial cartesian coordinates
	ra = deg_to_rad(ra)
	dec = deg_to_rad(dec)
	# dec and ra in radians from here on
	var rvect = dist * cos(dec);

	var equat_x = rvect * cos(ra);
	var equat_y = rvect * sin(ra);
	var equat_z = dist * sin(dec);
	
	# Find Galactic cartesian coordinates
	var xg = -(.055 * equat_x) - (.8734 * equat_y) - (.4839 * equat_z);
	var yg =  (.494 * equat_x) - (.4449 * equat_y) + (.747 * equat_z);
	var zg = -(.8677 * equat_x) - (.1979 * equat_y) + (.4560 * equat_z);
	
	var gal = Vector3(xg, yg, zg)
	#print("Galactic coords: ", gal)
	return gal

# parsing it happens in star_map.gd because it's creating the icons as it's being parsed
func load_data():
	#var file = File.new()
	var opened = FileAccess.open("res://known_systems.csv", FileAccess.READ)
	if opened.get_error() == OK:
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

# -------------------------------------------------------------
# called on demand as needed
func create_procedural_sector(sector):
	print("Generating sector for sector ", sector)
	if sector[0] == 0 and sector[1] == 0:
		print("Error! Tried procedurally generating sector 0,0!")
		return
	# poisson2D
	get_node("Grid/VisControl/Node2D").width = 512
	get_node("Grid/VisControl/Node2D").height = 512 # 512 to cover all sector
	# sector 264,-5 is the center of the galaxy
	var to_center = Vector2(sector[0]-264, sector[1]+5).length()
	var factor = inverse_lerp(265*2, 0, to_center)
	print("Center distance factor: ", factor, " inv: ", 1/factor)
	# it seems those all need to be casted to int to work properly
	get_node("Grid/VisControl/Node2D").r = int(40*(1/factor)) # the further from core, the bigger the radius
	get_node("Grid/VisControl/Node2D").total = int(256*factor) # the default of 20 was enough for 128 height
	get_node("Grid/VisControl/Node2D").k = int(256*factor)
	print("[sectorgen] r: ", get_node("Grid/VisControl/Node2D").r, " number: ", get_node("Grid/VisControl/Node2D").k)
	get_node("Grid/VisControl/Node2D").set_seed(1000001+sector[0]+sector[1])
	var samples = get_node("Grid/VisControl/Node2D").samples.duplicate() # because we'll be generating more samples
	#print("Generated points: ", samples)
	# sector begin, sector center is begin + 512 (half sector size)
	var sector_zero_start = Vector2(-512,-512)
	# NOTE: we're generating star DATA here, which has Y opposite to visual/map coords
	var sector_begin = Vector2(sector[0]*1024, -sector[1]*1024)+sector_zero_start
	var sector_center = sector_begin+Vector2(512, 512)
	print("[sectorgen] ", sector, " sector start: ", sector_begin, " sector center: ", sector_center)
	# now a second set of samples
	get_node("Grid/VisControl/Node2D").set_seed(1000002+sector[0]+sector[1])
	var sampl2 = get_node("Grid/VisControl/Node2D").samples.duplicate()
	# poisson2d generates points in +X +Y, so for remaining quadrants we need to remap
	sampl2 = sampl2.map(func(s): return [s[0], -s[1]] )
	#print("Generated points: ", sampl2)
	get_node("Grid/VisControl/Node2D").set_seed(1000003+sector[0]+sector[1])
	var sampl3 = get_node("Grid/VisControl/Node2D").samples.duplicate()
	sampl3 = sampl3.map(func(s): return [-s[0], -s[1]] )
	get_node("Grid/VisControl/Node2D").set_seed(1000004+sector[0]+sector[1])
	var sampl4 = get_node("Grid/VisControl/Node2D").samples.duplicate()
	sampl4 = sampl4.map(func(s): return [-s[0], s[1]] )
	samples = samples + sampl2 + sampl3 + sampl4
	return [sector_center, samples]

func get_sector_positions(sector_data):
	if sector_data == null:
		return []
	
	var positions = []
	#print(sector_data)
	for s in sector_data[1]:
		# s here can be a float
		#print("[sectorgen] s: ", s)
		# pos here is sector_center+sample position
		# shave off that unneeded decimal
		var pos2d = Vector2((sector_data[0][0] + s[0])/10, (sector_data[0][1]+s[1])/10)
		# vary the Z (the visual vs data Y is handled when generating, see l. 252)
		var pos = Vector3(pos2d.x, pos2d.y, randf_range(-11, +11))
		positions.append(pos)
	
	print("[sectorgen] Done generating...")
	return positions

# generate a map graph for the above sector	
func generate_map_graph(positions, sector):
	print("points pre addition: ", map_astar.get_point_count())
	
	#print(sector_data)
	#for s in sector_data[1]:
		# s here can be a float
		#print("[sectorgen] s: ", s)
		# shave off that unneeded decimal
	#	var pos2d = Vector2((sector_data[0][0] + s[0])/10, (sector_data[0][1]+s[1])/10)
		# vary the Z
	#	var pos = Vector3(pos2d.x, pos2d.y, randf_range(-20, +20))
		#print("[sectorgen]", " pos2d: ", pos2d, " ", pos)
	for pos in positions:
		# see star map.gd line 560
		var nam = "TST"+"%.2f" % pos[0]+"--"+"%.2f" % pos[1]
		map_graph.append([pos[0],pos[1],pos[2], nam]) # needed for finding name from pos
		var pos_data = pos_to_positive_pos(float_to_int(pos))
		mapping[float_to_int(pos)] = pack_data(pos_data[0], pos_data[1])
		map_astar.add_point(mapping[float_to_int(pos)], Vector3(pos.x, pos.y, pos.z))
		#print("[sectorgen] ", sector, " ", pos2d, " added to astar: ", Vector3(pos.x/10, pos.y/10, pos.z))
	
	print("Points post addition: ", map_astar.get_point_count())
	
	# connect stars
	var data = auto_connect_stars(sector)
	
	connect_sectors(sector, data[1])
	return data # for debugging

# ------------------------------------------------------------
func create_map_graph():
	# A* stores actual float positions (in light years)
	map_astar = AStar3D.new()
	# hardcoded stars
	var pos_data = pos_to_positive_pos(float_to_int(Vector3(0,0,0)))
	mapping[Vector3(0,0,0)] = pack_data(pos_data[0], pos_data[1])
	map_astar.add_point(mapping[Vector3(0,0,0)], Vector3(0,0,0)) # Sol
	
	# graph is made out of nodes
	for i in map_graph.size():
		var n = map_graph[i]
		
		# skip any stars outside the sector
		if n[0] < -50 or n[1] < -50 or n[2] < -50:
			continue
		
		# the reason for doing this is to be independent of any sort of a catalogue ordering...
		map_astar.add_point(mapping[float_to_int(Vector3(n[0], n[1], n[2]))], Vector3(n[0], n[1], n[2]))
		#map_astar.add_point(i+1, Vector3(n[0], n[1], n[2]))
	
	# debug
	#print("AStar3D points:")
	#for p in map_astar.get_point_ids():
	#	print(p, ": ", map_astar.get_point_position(p))
	
	# connect stars
	var data = auto_connect_stars([0,0])
	return data # for debugging

func pretty_print_quadrants(quad_pts):
	print("NW:")
	for p in quad_pts[0]:
		print(find_name_from_pos(p), ": ", p)
	print("NE:")
	for p in quad_pts[1]:
		print(find_name_from_pos(p), ": ", p)
	print("SE:")
	for p in quad_pts[2]:
		print(find_name_from_pos(p), ": ", p)
	print("SW:")
	for p in quad_pts[3]:
		print(find_name_from_pos(p), ": ", p)		
	print("/n")

# this gets INTERNAL sector begin and seems to work correctly
func get_quad_points(sector_begin, center_star):
	var quad_pts = [[],[], [], []]
	var quads = sector_to_quadrants(sector_begin)
	for i in quads.size():
		var q = quads[i]
		for p in map_astar.get_point_ids():
			# skip center star
			if p == center_star:
				continue
			
			# this is the actual star position in light years
			var pos = map_astar.get_point_position(p)
			#print("Pos from A*: ", pos)
			# we don't care about Z here
			#if q.has_point(Vector2(pos.x, pos.y)):
			# need to check coords converted back to int
			if q.has_point(float_to_int2(Vector2(pos.x, pos.y))):
				quad_pts[i].append(map_astar.get_point_position(p))
				#print("Appended to quad pts, ", pos)
				continue
			#else:
			#	print("Not in quadrant: ", q, " pos: ", float_to_int2(Vector2(pos.x, pos.y)))

	#print("Quad pts: ", quad_pts)
	return quad_pts
	
func auto_connect_stars(sector):
	# sector begin, sector center is begin + 512 (half sector size)
	var sector_zero_start = Vector2(-512,-512)
	# this works on star DATA (see l. 387), not visuals, which has the Y axis opposite to visuals
	# this way we only put the sign in one place, instead of doing it everywhere where we check for positions, rects etc.
	var sector_begin = Vector2(sector[0]*1024, -sector[1]*1024)+sector_zero_start
	var sector_center = sector_begin+Vector2(512, 512)
	print("[Auto connect] sector", sector, " sector begin: ", sector_begin, " ", sector_center)

	# sector_center is in ints encoding floats, so we need to shave off the last decimal
	var center_point = Vector3(sector_center.x/10, sector_center.y/10, 0)
	print("Center point in ly: ", center_point)
	var center_star = map_astar.get_closest_point(center_point)
	print("Center star: ", find_name_from_pos(map_astar.get_point_position(center_star)), " @ ", map_astar.get_point_position(center_star))
	
	# do it by quadrants
	var quad_pts = get_quad_points(sector_begin, center_star)
	
	# better debugging
	#pretty_print_quadrants(quad_pts)
	
	#print("NW: ", quad_pts[0], " ", quad_pts[0].size(), "\n NE: ", quad_pts[1], " ", quad_pts[1].size(), "\n SE: ", quad_pts[2], " ", quad_pts[2].size(), "\n SW: ", quad_pts[3], " ", quad_pts[3].size())
	#print("NW+NE+SE+SW:", quad_pts[0].size()+quad_pts[1].size()+quad_pts[2].size()+quad_pts[3].size())
	
	var mst_sum = []
	var tree = []
	for qp in quad_pts:
		# paranoia
		if qp.size() == 0:
			return
			
		var prim_data = auto_connect_prim(qp.size(), qp[0], qp)

		var in_mst = prim_data[0]
		var sub_tree = prim_data[1]

		# combine into one structure
		for i in range(0, in_mst.size()):
			mst_sum.append(in_mst[i])
		for i in range(0, sub_tree.size()):
			tree.append(sub_tree[i])
		#mst_sum.append(in_mst)
		#tree.append(sub_tree)


		# convert mst to connections
		for i in range(1,in_mst.size()):
			if !typeof(in_mst[i]) == TYPE_VECTOR3:
				continue # paranoia skip
			map_astar.connect_points(mapping[in_mst[i-1]], mapping[in_mst[i]])
		for i in range(1, sub_tree.size()):
			if !typeof(sub_tree[i]) == TYPE_VECTOR3:
				continue # paranoia skip
			map_astar.connect_points(mapping[in_mst[i-1]], mapping[sub_tree[i]])

			#print("Connecting: ", in_mst[i-1], " and ", sub_tree[i])

	# old: entire sector at once
#	var V = map_astar.get_points().size()
#	#print("Points in astar: ", V)
#	var prim_data = auto_connect_prim(V, Vector3(0,0,0))
#	var in_mst = prim_data[0]
#	var tree = prim_data[1]
#	# convert mst to connections
#	for i in range(1,in_mst.size()):
#		if !typeof(in_mst[i]) == TYPE_VECTOR3:
#			continue # paranoia skip
#		map_astar.connect_points(mapping[in_mst[i-1]], mapping[in_mst[i]])
#	for i in range(1, tree.size()):
#		if !typeof(tree[i]) == TYPE_VECTOR3:
#			continue # paranoia skip
#		map_astar.connect_points(mapping[in_mst[i-1]], mapping[tree[i]])
#
#		#print("Connecting: ", in_mst[i-1], " and ", tree[i])

	var secondary = []
	for i in range(1, tree.size()-1):
		if !typeof(tree[i]) == TYPE_VECTOR3:
			continue # paranoia skip

		# for debugging
		var connect = [find_name_from_pos(mst_sum[i-1], false), find_name_from_pos(tree[i], false)]
		secondary.append(connect)
		#var connect = [find_icon_for_pos(mst_sum[i-1]), find_icon_for_pos(tree[i])]
		#get_node("Grid/VisControl").secondary.append(connect)

	# connect stars close by across quadrants (e.g, Barnard's and Alpha Cen)
	# gets away with no sorting because of very limited distances (see l. 506)
	var cross_quad = []
	for qp in quad_pts:
		for p in qp:
			# skip if we're already in the list
			if p in cross_quad:
				continue 
				
			var stars = get_closest_stars_to(float_to_int(p))
			
			# some postprocessing to remove one of a pair of very close stars
			stars = closest_stars_postprocess(stars)
			
			# filter
			var tmp = []
			for s in stars:
				if s[1] in cross_quad:
					continue
				# not center star and not in our quadrant
				if !s[1] in qp and s[1] != map_astar.get_point_position(center_star):
					# limit by distance (experimental values)
					if s[0] < 8 and s[0] > 0.15: #10:
						tmp.append(s)
			
			stars = tmp
			if !stars.is_empty():
				#print(stars)
				map_astar.connect_points(mapping[float_to_int(p)], mapping[float_to_int(stars[0][1])])
				print("Connecting across quadrants, ", p, " ", find_name_from_pos(p), " and ", find_name_from_pos(stars[0][1]), " @ ", stars[0][1])
				# prevent multiplying connections
				cross_quad.append(stars[0][1])
				cross_quad.append(p)


	# connect the central (hub) star
	for qp in quad_pts:
		# find the closest star in each quadrant (they're NOT in distance order by default)
		var stars = get_closest_stars_to(float_to_int(map_astar.get_point_position(center_star)))
		
		# filter
		var tmp = [] #stars.duplicate()
		for s in stars:
			if s[1] in qp:
				tmp.append(s)
				#print("Star not in list: ", s[1], " ", find_name_from_pos(s[1]))
				#tmp.remove(tmp.find(s))
		#print("post filter: ", tmp, " ", quad_pts.find(qp))
		stars = tmp
		
		# if we were using raw stars we'd be using index 1 because 0 is center star itself, but we're filtering first so 0
		#print("Connecting the hub: ", map_astar.get_point_position(center_star), " to: ", find_name_from_pos(stars[0][1]), " @ ", stars[0][1])
		map_astar.connect_points(center_star, mapping[float_to_int(stars[0][1])])

	# manually add Sol's connections (for now) since that's what the wormhole setup script expects...
	# funnily enough, the auto-hub algorithm picks up the EXACT same stars!
	#map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(28, -31, 1)]) # Sol to Proxima Centauri
	#map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(50, 30,14)]) # Sol to Barnard's
	#map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(-19, -39, 65)]) # Sol to Wolf359
	#map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(-21, 2, -85)]) # Sol to Luyten 726-8/UV Ceti

	return [secondary, quad_pts]

func auto_connect_prim(V, start, list=null):
	var debug = false
	#if start == Vector3(0.1,-5.6,9.3):
	if start.x < -100:
		debug = true
	#print("Prim's: #", V, " ", start)
	# we're not using Kruskal as we don't have edges
	# Prim's algorithm: start with one vertex
	# 1. Find the edges that connect to other vertices. Find the edge with minimum weight and add it to the spanning tree.
	# Repeat step 1 until the spanning tree is obtained.
	# i.e. step 1 is: get closest stars[1]... since [0] is ourselves

	var in_mst = [] # unlike most Prim exmaples, we store positions here, not just bools
	# preallocate for speedup
	in_mst.resize(V)
	in_mst.fill(0)
	var edge_count = 0
	in_mst[0] = float_to_int(start)
	
	var tree = [] # separate struct for other connections
	tree.resize(V)
	tree.fill(0)
	
	while edge_count < V-1:
		# Find closest star to each star
		var pos = in_mst[edge_count]
		if !typeof(pos) == TYPE_VECTOR3 and pos == 0:
			print("ERR! Pos is 0")
			edge_count += 1
			continue
		
		if debug:	
			print("Connecting: ", find_name_from_pos(pos, false))
		var stars = get_closest_stars_to(pos)
		#print(stars)
		
		# filter
		var tmp = [] #stars.duplicate()
		if list:
			#print(list)
			for s in stars:
				if s[1] in list:
					tmp.append(s)
					#print("Star not in list: ", s[1], " ", find_name_from_pos(s[1]))
					#tmp.remove(tmp.find(s))
		#print("post filter: ", tmp)
		stars = tmp
		
		# some postprocessing to remove one of a pair of very close stars
		stars = closest_stars_postprocess(stars)
		
#		for i in range(1,3): #(stars.size()):
#			var s = stars[i]
#			print(find_name_from_pos(s[1]), ": ", s[1])
#		print("/n")
		
		# sometimes the closest star is already in mst
		for c in range(1,stars.size()): #-1): #-1 because we add next closest, too
			# paranoia
			if c == stars.size()-1 and in_mst.has(float_to_int(stars[c][1])):
				print(find_name_from_pos(pos, false), ": all stars already in mst?! ", stars[c], find_name_from_pos(stars[c][1]), in_mst.has(float_to_int(stars[c][1])))
				edge_count += 1
				break
			#if debug:
			#	print("Star at #, ", c, " ", stars[c], ": ", in_mst.has(float_to_int(stars[c][1])))
			if !in_mst.has(float_to_int(stars[c][1])):
				#print("Star, ", stars[c], " not in mst...")
				edge_count += 1
				in_mst[edge_count] = float_to_int(stars[c][1])
				if c < stars.size()-1:
					# add the next closest star to a separate listing
					if !tree.has(float_to_int(stars[c+1][1])) and !in_mst.has(float_to_int(stars[c+1][1])):
						#print("Star, ", stars[c+1][1], " to be added to tree")
						tree[edge_count] = float_to_int(stars[c+1][1])
				
				break # no need to keep looking through closest stars if we already found

				
	# debugging		
	#print(start, " : ", in_mst.size(), " ", in_mst)
	
	if debug:
		for i in in_mst.size():
			var s = in_mst[i]
			if !typeof(s) == TYPE_VECTOR3:
				continue # paranoia skip
			print(i, ": ", find_name_from_pos(s, false), " @ ", s)
	
	return [in_mst, tree]

func pick_quads_across_sectors(sector, quad_pts):
	var sector_zero_start = Vector2(-512, -512)
	# this operates on internal values
	var sector_begin = Vector2(sector[0]*1024, -sector[1]*1024)+sector_zero_start
	#print("Sector, ", sector, " begin: ", sector_begin)
	# the weird Y offsets are a hack solution to get this to work properly for internal star values
	var smaller_quads_one = quadrants(sector_begin+Vector2(512,512), 256, 256)
	var smaller_quads_two = quadrants(sector_begin-Vector2(0,-512), 256, 256)

	var sub_quad_pts_one = [[],[], [], []]
	for i in smaller_quads_one.size():
		var q = smaller_quads_one[i]
		for p in map_astar.get_point_ids():
#					# skip center star
#					if p == center_star:
#						continue
			
			# this is the actual star position in light years
			var pos = map_astar.get_point_position(p)
			#print("Pos from A*: ", pos)
			# we don't care about Z here
			#if q.has_point(Vector2(pos.x, pos.y)):
			# need to check coords converted back to int
			if q.has_point(float_to_int2(Vector2(pos.x, pos.y))):
				sub_quad_pts_one[i].append(map_astar.get_point_position(p))
				#print("Appended to quad pts, ", pos)
				continue
	
	var sub_quad_pts_two = [[],[], [], []]
	for i in smaller_quads_two.size():
		var q = smaller_quads_two[i]
		for p in map_astar.get_point_ids():
#					# skip center star
#					if p == center_star:
#						continue
			
			# this is the actual star position in light years
			var pos = map_astar.get_point_position(p)
			#print("Pos from A*: ", pos)
			# we don't care about Z here
			#if q.has_point(Vector2(pos.x, pos.y)):
			# need to check coords converted back to int
			if q.has_point(float_to_int2(Vector2(pos.x, pos.y))):
				sub_quad_pts_two[i].append(map_astar.get_point_position(p))
				#print("Appended to quad pts, ", pos)
				continue
	
	#print("Sub quads nw: ", sub_quad_pts_nw)
	#print("Sub quads ne: ", sub_quad_pts_ne[0], sub_quad_pts_ne[1])
	
	# visual coords {0: "NW", 1: "NE", 2:"SE", 3:"SW"}
	# internal coords {0: "SW", 1: "SE", 2:"NE", 3:"NW"}

	var all_quad_pts = [sub_quad_pts_one[2], sub_quad_pts_one[3], quad_pts[0], quad_pts[1]]
	return all_quad_pts

func connect_sectors(sector, our_quad_pts):
	var all_quad_pts = []
	var sector_zero_start = Vector2(-512, -512)
	# special case: sector 0,0 as neighbor
	if abs(sector[0]) == 1 or abs(sector[1]) == 1:
		print(sector, " neighboring sector 0,0")
		
		var quad_pts = get_quad_points(Vector2(-512,-512), map_astar.get_closest_point(Vector3(0,0,0))) # sector 0

		# visual coords {0: "NW", 1: "NE", 2:"SE", 3:"SW"}
		# internal coords {0: "SW", 1: "SE", 2:"NE", 3:"NW"}	
		if sector[0] == 1:
			print("our neighboring quadrants: NW, SW") # for sector 0, they're NE, SE
			print("NW: ", our_quad_pts[0])
			print("SW: ", our_quad_pts[3])
			print("NE: ", quad_pts[1])
			print("SE: ", quad_pts[2])
		if sector[0] == -1:
			print("our neighboring quadrants: NE, SE") # for sector 0, they're NW, SW
			print("NE: ", our_quad_pts[1])
			print("SE: ", our_quad_pts[2])
			print("NW: ", quad_pts[0])
			print("SW: ", quad_pts[3])
		if sector[1] == -1:
			print("our neighboring quadrants: SE, SW") # for sector 0, they're NE, NW
			print("SE: ", our_quad_pts[2])
			print("SW: ", our_quad_pts[3])
			print("NE: ", quad_pts[1])
			print("NW: ", quad_pts[0])
		if sector[1] == 1:
			print("our neighboring quadrants: NE, NW") # for sector 0, they're SE, SW
			#print("NE: ", our_quad_pts[1])
			#print("NW: ", our_quad_pts[0])
			print("SE: ", quad_pts[2])
			print("SW: ", quad_pts[3])
			
			all_quad_pts = pick_quads_across_sectors(sector, quad_pts)

	# here the magic happens!
	var cross_sector = []
	for qp_i in range(0,3):
		# first entries are ours
		if qp_i < 2:
			var qp = all_quad_pts[qp_i]
	#for qp in all_quad_pts:
			for p in qp:
				#print("Connecting across sectors, ", p, " ", find_name_from_pos(p))
				# skip if we're already in the list
				if p in cross_sector:
					continue 
	
				var stars = get_closest_stars_to(float_to_int(p))
				
				# filter
				var tmp = []
				for s in stars:
					if s[1] in cross_sector:
						continue
					# if it's in one of the other two quadrants
					if s[1] in all_quad_pts[all_quad_pts.size()-2] or s[1] in all_quad_pts[all_quad_pts.size()-1]:
					# not in our quadrant
					#if !s[1] in qp: #and s[1] != map_astar.get_point_position(center_star):
						# limit by distance (experimental values)
						#if s[0] < 110 and s[0] > 0.15: #10:
							tmp.append(s)
				
				stars = tmp
				if !stars.is_empty():
					#print("Candidate stars: ", stars)
					map_astar.connect_points(mapping[float_to_int(p)], mapping[float_to_int(stars[0][1])])
					print("Connecting across sectors, ", p, " ", find_name_from_pos(p), " and ", find_name_from_pos(stars[0][1]), " @ ", stars[0][1])
					# prevent multiplying connections
					cross_sector.append(stars[0][1])
					cross_sector.append(p)				
# ------------------------------------------------------
func find_name_from_pos(pos, need_conv=true):
	#print("Looking up name from graph for pos: ", pos)

	if need_conv:
		# use ints for comparison to avoid floating point inaccuracies	
		pos = float_to_int(pos)

	#var id = -1
	var nam = ""
	for i in map_graph.size():
		var n = map_graph[i]
		var _int = float_to_int(Vector3(n[0], n[1], n[2]))
		if pos == _int:
		#if n[0] == pos.x and n[1] == pos.y and n[2] == pos.z:
			#id = i
			nam = n[3]
			break
	#print("Name: ", nam)
	return nam

# this is why we don't nuke map_graph after creating the Astar graph...
func find_graph_id(nam):
	print("Looking up graph id for: ", nam)
	var id = -1
	for i in map_graph.size():
		var n = map_graph[i]
		if n[3] == nam:
			id = i #+1 # +1 because Sol is hardcoded at #0 (see l.200)
			break
	return id

func find_coords_for_name(nam):
	var id = find_graph_id(nam)
	var coords = Vector3(0,0,0)
	if id != -1:
		coords = Vector3(map_graph[id][0], map_graph[id][1], map_graph[id][2])
	print("For name, ", nam, " id ", id, " real float coords: ", coords)
	return coords
	

func get_star_distance_old(a,b):
	var start_name = a.get_node("Label").get_text().replace("*", "")
	var end_name = b.get_node("Label").get_text().replace("*", "")
	var id1 = find_graph_id(start_name)
	var id2 = find_graph_id(end_name)
	#print("ID # ", id1, " ID # ", id2, " pos: ", map_astar.get_point_position(id1), " & ", map_astar.get_point_position(id2))
	# see above - astar graph is created from map_graph so the id's match
	return map_astar.get_point_position(id1).distance_to(map_astar.get_point_position(id2))

func get_star_distance(a,b):
	var start = a.pos if "pos" in a else Vector3(0,0,0)
	var end = b.pos if "pos" in b else Vector3(0,0,0)
	var id1 = mapping.get(start)
	var id2 = mapping.get(end)
	print("id1:", id1, " id2: ", id2)
	# if star is not in mapping (not in sector)
	if id2 == null:
		# return placeholder value
		return "Unknown"
	
	return map_astar.get_point_position(id1).distance_to(map_astar.get_point_position(id2))

# converts float to int
func get_neighbors(coords):
	var neighbors = map_astar.get_point_connections(mapping[float_to_int(coords)])
	print("Neighbors for id: ", mapping[float_to_int(coords)], " ", neighbors)
	return neighbors

# sort
class MyCustomSorter:
	static func sort_stars(a, b):
		if a[0] < b[0]:
			return true
		return false

func get_closest_stars_to(pos):
	var src = map_astar.get_point_position(mapping[pos])
	
	#print("Getting closest stars to ", src)
	# sort by dist
	var dists = []
	var stars = []

	for p in map_astar.get_point_ids():
		var dist = map_astar.get_point_position(p).distance_to(src)
		dists.append(dist)
		stars.append([dist, map_astar.get_point_position(p)])

	#dists.sort()
	#print("Dists sorted: " + str(dists))

	# custom sort
	stars.sort_custom(Callable(MyCustomSorter,"sort_stars"))

	#print(stars)
	#print("Closest to ", src, " stars: ", stars)
	
	return stars

func closest_stars_postprocess(stars):
	var to_rem = []
	for i in range(1, stars.size()-1):
		var s = stars[i]
		var s_next = stars[i+1]
		#print("Comparing ", (s[1]-s_next[1]).length())
		if (s[1]-s_next[1]).length() < 0.15:
		#if abs(s[0]-s_next[0]) < 0.1:
			#print("Detected two close stars in the list! ", s[1], s_next[1])
			to_rem.append(i+1)
	
	for r in to_rem:
		stars.remove_at(r)
	
	return stars

# wants internal ids
func route(src, tg):
	if tg in map_astar.get_point_connections(src):
		return
		
	if map_astar.get_point_connections(tg).size() < 1:
		return
		
	return map_astar.get_id_path(src, tg)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
