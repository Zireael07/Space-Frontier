# map emulates the look of http://www.projectrho.com/public_html/rocket/images/spacemaps/RECONSmap.jpg

tool
extends Control


# Declare member variables here. Examples:

var icon = preload("res://hud/star map icon.tscn")

const LY_TO_PX = 50;
var offset = Vector2(0,0)
var center = Vector2(382.5, 242.5) # experimentally determined
var grid = Vector2(0, -138) # experimentally determined

# data
var data = []
# map
var map_graph = []
var map_astar = null
# problem: we have coordinates (3 floats) and we need to have a unique identifier per star
# idenfifier must be an int because AStar uses integer ids
var mapping = {}

# https://stackoverflow.com/questions/65706804/bitwise-packing-unpacking-generalized-solution-for-arbitrary-values
# for some reason this (just like collapsing 3D to 1D index) only works for positive numbers
# https://stackoverflow.com/questions/6556961/use-of-the-bitwise-operators-to-pack-multiple-values-in-one-int/6557022#6557022
# no component can be bigger then 999 that means we need 10 bits of storage per component (allows numbers up to 1014).
func pack_vector(vec3):
	# packed = v3 << (size1 + size2) | v2 << size1 | v1;
	return (int(vec3.z) << (10 + 10) | int(vec3.y) << 10 | int(vec3.x))
	
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

func pos_to_positive_pos(vec3):
	# assume the sector is 50 ly in each direction, extended to closest power of 2
	# a digit was added to represent a decimal place (see l.29 above)
	var sector_start = Vector3(-512,-512,-512)
	var pos = Vector3(vec3.x-sector_start.x, vec3.y-sector_start.y, vec3.z-sector_start.z)
	#print("original: ", vec3, " positive: ", pos)
	# test
	#positive_to_original(pos)
	return pos
	
func positive_to_original(vec3):
	var sector_start = Vector3(-512,-512,-512)
	var pos = Vector3(vec3.x+sector_start.x, vec3.y+sector_start.y, vec3.z+sector_start.z)
	#print("positive: ", vec3, " original: ", pos)
	return pos

func save_graph_data(x,y,z, nam):
	map_graph.append([x,y,z, nam])
	
	# skip any stars outside the sector
	if x < -50 or y < -50 or z < -50:
		return
	
	# as of Godot 3.5, AStar's key cannot be larger than 2^32-1 (hashes will overflow)
	
	var id = pack_vector(pos_to_positive_pos(float_to_int(Vector3(x,y,z))))
	#print("ID: ", id, "; unpacked: ", unpack_vector(id))
	#print("Nearest po2: ", nearest_po2(id)) # 2^30 for storing 3*2^10 max
	#print("AStar overflow: ", id > (pow(2,31)-1)) # 2^31-1
	
	mapping[float_to_int(Vector3(x,y,z))] = id
	
	# the global scope function returns an integer hash
	#mapping[Vector3(x,y,z)] = hash(Vector3(x,y,z))
	# https://godotengine.org/qa/43078/create-an-unique-id
	#mapping[Vector3(x,y,z)] = Vector3(x,y,z).get_instance_id()

# Called when the node enters the scene tree for the first time.
func _ready():
	data = load_data()
	for line in data:
		# name, x, y, z, color
		#print(line)
		if line[0] != "Sol":
			var ic = icon.instance()
			ic.named = str(line[0])
			if line[1] != " -":
				# strip units
				ic.x = strip_units(str(line[1]))
				#ic.x = float(line[1])
				ic.y = strip_units(str(line[2]))
				ic.depth = strip_units(str(line[3]))
				ic.pos = float_to_int(Vector3(ic.x,ic.y,ic.depth))
				# does the star have planets?
				ic.planets = false
				if "yes" in line[5]:
					ic.planets = true
				save_graph_data(ic.x, ic.y, ic.depth, ic.named)
			
			# line[6] is for comments
			
			# ra-dec conversion
			if line.size() > 7 and line[1] == " -":
				#print("RA/DEC candidate...")
				var ra = line[7]
				var de = line[8] 
				if ra != "" and de != "" and line[9] != "":
					#print("RA/DEC convert for ", str(line[0]))
					var ra_deg = 0
					var dec = 0
					if "h" in ra and not "m" in ra:
						# if no minutes specified, we assume decimal hours
						# 15 degrees in an hour (360/24) 
						ra_deg = float(15*float(ra.rstrip("h")))
						# for now, assume degrees are given in decimal degrees
						dec = float(line[7])
					elif "h" in ra and "m" in ra:
						# http://voyages.sdss.org/preflight/locating-objects/ra-dec/
						# 0,25 (1/4) degree in a minute since it takes 4 minutes for a degree (60/15)
						var parts = ra.split("h")
						ra_deg = float(15*float(parts[0].rstrip("h")))
						ra_deg += float(0.25*float(parts[1].rstrip("m")))
					if "d" in de and "m" in de:
						var parts = de.split("d")
						dec = float(parts[0].rstrip("d"))
						dec += float(parts[1].rstrip("m"))/60
					if not "h" in ra:
						ra_deg = float(ra)
					if not "d" in de and not "m" in de:
						dec = float(de)
					
					var dist = float(line[9])
					if "pc" in line[9]:
						dist = strip_units(line[9])
					var data = galactic_from_ra_dec(ra_deg, dec, dist)
					# assign calculated values - no need to strip units as it's always
					ic.x = data[0]
					ic.y = data[1]
					ic.depth = data[2]
					ic.pos = float_to_int(Vector3(ic.x,ic.y,ic.depth))
					save_graph_data(ic.x, ic.y, ic.depth, ic.named)
			get_node("Control").add_child(ic)
	
	# create a graph of stars we can route on
	create_map_graph()
	
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
	ra = deg2rad(ra)
	dec = deg2rad(dec)
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
	print("Galactic coords: ", gal)
	return gal

func load_data():
	var file = File.new()
	var opened = file.open("res://hud/starmap.csv", file.READ)
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# -------------------------------------------------------------------------

func update_map(marker):
	# update marker position
	var system = get_tree().get_nodes_in_group("main")[0].curr_system

	if $"Control".has_node(system):
		marker.get_parent().remove_child(marker)
		$"Control".get_node(system).add_child(marker)
		$"Control".src = $"Control".get_node(system)

	if system == "tauceti":
		marker.get_parent().remove_child(marker)
		$"Control/Tau Ceti".add_child(marker)
		$"Control".src = $"Control/Tau Ceti"
	if system == "barnards":
		marker.get_parent().remove_child(marker)
		$"Control/Barnard's Star".add_child(marker)
		$"Control".src = $"Control/Barnard's Star"

	# clear any previous tint
	for c in get_node("Control").get_children():
		c.get_node("Label").set_self_modulate(Color(1,1,1))
	
	# show target on map (tint cyan to match marker above)	
	#var lookup = {"luyten726-8": "Luyten 726-8", "barnards":"Barnard's Star", "wolf359":"Wolf 359"}	
	var lookup = {"Barnards":"Barnard's Star", "Trappist": "Trappist-1"}	
	
	if game.player.w_hole.target_system:
		print("Target system: ", game.player.w_hole.target_system)
		
		var coords = unpack_vector(game.player.w_hole.target_system)
		#print("unpacked coords: ", coords)
		coords = positive_to_original(coords)
		#print("Coords: ", coords)
		var icon = find_icon_for_pos(coords)
		print("Icon: ", icon.get_name(), " @ ", coords if icon != null else "None")
		$"Control".tg = icon
		icon.get_node("Label").set_self_modulate(Color(0,1,1))
		
		# paranoia
		if $"Control".src == $"Control".tg:
			print("Something went wrong, same src and tg!!!")
		
		# this relied on string ids
#		if game.player.w_hole.target_system in lookup:
#			$"Control".tg = get_node("Control").get_node(lookup[game.player.w_hole.target_system])
#			get_node("Control").get_node(lookup[game.player.w_hole.target_system]).get_node("Label").set_self_modulate(Color(0,1,1))
#		else:
#			$"Control".tg = get_node("Control").get_node(game.player.w_hole.target_system)
#			get_node("Control").get_node(game.player.w_hole.target_system).get_node("Label").set_self_modulate(Color(0,1,1))
	else:
		if system == "Sol":
			$"Control/proxima/Label".set_self_modulate(Color(0,1,1))
		if system == "Proxima":
			$"Control/alphacen/Label".set_self_modulate(Color(0,1,1))
		if system == "Luyten 726-8":
			$"Control/Tau Ceti/Label".set_self_modulate(Color(0,1,1))
	
	# center on star (needs target to be set because it resets the distance label)
	offset = -$"Control".src.rect_position
	move_map_to_offset(offset)
	
	# show distance involved along the line
	get_node("Grid/VisControl/Label").set("custom_colors/font_color", Color(0,1,1))
	# halfway along
	#print("tg loc: ", $"Control".get_tg_loc(), "src loc: ", $"Control".get_src_loc())
	var gl_loc = ($"Control".get_tg_loc() - $"Control".get_src_loc())/2
	get_node("Grid/VisControl/Label").set_global_position(gl_loc) #$"Control".rect_position + ($"Control".get_tg_loc() - $"Control".get_src_loc())/2
	var dist = get_star_distance($"Control".src, $"Control".tg)
	get_node("Grid/VisControl/Label").set_text("%.2f ly" % (dist))

func create_map_graph():
	map_astar = AStar.new()
	# hardcoded stars
	mapping[Vector3(0,0,0)] = pack_vector(pos_to_positive_pos(float_to_int(Vector3(0,0,0))))
	map_astar.add_point(mapping[Vector3(0,0,0)], Vector3(0,0,0)) # Sol
	#map_astar.add_point(1, Vector3(-3.4, 0.4, -11.4)) # Tau Ceti
	
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
	print("AStar points:")
	for p in map_astar.get_points():
		print(p, ": ", map_astar.get_point_position(p))
	
	# connect stars
	#map_astar.connect_points(0,1) # Sol to Tau Ceti
	#map_astar.connect_points(0,2) # Sol to Barnard's
	#map_astar.connect_points(0,3) # Sol to Wolf359
	#map_astar.connect_points(0,4) # Sol to Luyten 726-8/UV Ceti
	
	map_astar.connect_points(mapping[Vector3(0,0,0)],mapping[Vector3(-34, 4, -114)]) # Sol to Tau Ceti
	map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(50, 30,14)]) # Sol to Barnard's
	map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(-19, -39, 65)]) # Sol to Wolf359
	#map_astar.connect_points(mapping[Vector3(0,0,0)], mapping[Vector3(-21, 2, -85)]) # Sol to Luyten 726-8/UV Ceti
	
#	# check distances to Gliese 1002
#	for i in range(4):
#		var dist = map_astar.get_point_position(i).distance_to(map_astar.get_point_position(7))
#		print(i, ": ", dist)
	
#	map_astar.connect_points(1,7) # Tau Ceti to Gliese 1002 (6.8ly according to the above)
#	map_astar.connect_points(5,7) # Gliese 1005 to Gliese 1002
#	map_astar.connect_points(7,8) # Gliese 1002 to Gliese 1286
#	map_astar.connect_points(8,9) # Gliese 1286 to Gliese 867 (FK Aquarii)
#	map_astar.connect_points(10,9) # Gliese 1265 to Gliese 867
#	map_astar.connect_points(11,10) # NN 4281 to Gliese 1265
#	map_astar.connect_points(11,12) # NN 4281 to TRAPPIST-1

	map_astar.connect_points(mapping[Vector3(-34, 4, -114)],mapping[Vector3(-2, 58, -141)]) # Tau Ceti to Gliese 1002
#	map_astar.connect_points(mapping[Vector3(4, 39, -158)],mapping[Vector3(-2, 58, -141)]) # Gliese 1005 to Gliese 1002
	map_astar.connect_points(mapping[Vector3(-2, 58, -141)],mapping[Vector3(14, 119,-202)]) # Gliese 1002 to Gliese 1286
	map_astar.connect_points(mapping[Vector3(14, 119,-202)],mapping[Vector3(113, 95, -241)]) # Gliese 1286 to Gliese 867 (FK Aquarii)
	map_astar.connect_points(mapping[Vector3(160, 130, -270)],mapping[Vector3(113, 95, -241)]) # Gliese 1265 to Gliese 867
	map_astar.connect_points(mapping[Vector3(139, 155, -287)],mapping[Vector3(160, 130, -270)]) # NN 4281 to Gliese 1265
	map_astar.connect_points(mapping[Vector3(139, 155, -287)],mapping[Vector3(78, 211, -339)]) # NN 4281 to TRAPPIST-1
	
		
	# check connectedness
	print("To TRAPPIST: ", map_astar.get_id_path(mapping[Vector3(0,0,0)],mapping[Vector3(78, 211, -339)])) #12))
		
	return map_astar


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
	
func find_icon_for_pos(pos):
	var ret = null
	for c in $"Control".get_children():
		if 'pos' in c and c.pos == pos:
			ret = c
			break
	return ret

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
	return map_astar.get_point_position(id1).distance_to(map_astar.get_point_position(id2))

func get_neighbors(coords):
	var neighbors = map_astar.get_point_connections(mapping[float_to_int(coords)])
	print("Neighbors for id: ", mapping[float_to_int(coords)], " ", neighbors)
	return neighbors


# --------------------------------------------------
func _on_ButtonConfirm_pressed():
	game.player.w_hole.jump()
	$"PopupPanel/VBoxContainer/ButtonLog/PanelLog".hide()

func _on_ButtonAbort_pressed():
	game.player.HUD.hide_starmap()
	$"PopupPanel/VBoxContainer/ButtonLog/PanelLog".hide()
	game.player.w_hole.entered = false
	game.player.w_hole = null

func display_captain_log():
	#$"PopupPanel/VBoxContainer/ButtonLog/PanelLog/RichTextLabel".set_text(str(game.captain_log))
	
	# same trick as in update_cargo_listing()
	var listing = str(game.captain_log).lstrip("[").rstrip("]").replace("], ", "\n").replace("[", "")	
	$"PopupPanel/VBoxContainer/ButtonLog/PanelLog/RichTextLabel".set_text(listing)

func _on_ButtonLog_pressed():
	if !$"PopupPanel/VBoxContainer/ButtonLog/PanelLog".is_visible():
		display_captain_log()
		$"PopupPanel/VBoxContainer/ButtonLog/PanelLog".show()
	else:
		$"PopupPanel/VBoxContainer/ButtonLog/PanelLog".hide()
	

func move_map_to_offset(offset):
	$Control.set_position(center+offset)
	$"Grid/VisControl".update() # redraw direction lines if any
	# recalculate distance label position
	get_node("Grid/VisControl/Label").rect_position = $"Control".rect_position + ($"Control".get_tg_loc() - $"Control".get_src_loc())/2
	
	$Legend/Label.set_text("1 ly = 50 px" + "\n" + "Map pos: " + str(-offset))
	if offset != Vector2(0,0):
		$Grid.origin = false
	else:
		$Grid.origin = true
	$Grid.update_grid()
	# recalculate starmap icons sfx
	for c in $"Control".get_children():
		# because some star icons are hardcoded
		if c.has_method("calculate_label_and_sfx"):
			c.calculate_label_and_sfx(offset)
	
func _on_ButtonL_pressed():
	offset += Vector2(LY_TO_PX,0)
	move_map_to_offset(offset)

func _on_ButtonR_pressed():
	offset += Vector2(-LY_TO_PX,0)
	move_map_to_offset(offset)

func _on_ButtonUp_pressed():
	offset += Vector2(0, LY_TO_PX)
	move_map_to_offset(offset)

func _on_ButtonDown_pressed():
	offset += Vector2(0, -LY_TO_PX)
	move_map_to_offset(offset)


func _on_LineEdit_text_entered(new_text):
	# search for the star
	var found = null
	for c in $Control.get_children():
		if c.get_node("Label").get_text().find(new_text) != -1:
			found = c
			print("Found the star: ", new_text, "!")
			break
	
	# center map on found star
	if found:
		offset = -found.rect_position
		move_map_to_offset(offset)
