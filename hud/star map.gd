# map emulates the look of http://www.projectrho.com/public_html/rocket/images/spacemaps/RECONSmap.jpg
# the Z-lines are inspired by the so-called "hockey sticks" in Elite/Oolite
tool
extends "../galaxy.gd" #Control

# Declare member variables here. Examples:

var icon = preload("res://hud/star map icon.tscn")

const LY_TO_PX = 50;
var offset = Vector2(0,0)
var center = Vector2(382.5, 242.5) # experimentally determined
var grid = Vector2(0, -138) # experimentally determined



# Called when the node enters the scene tree for the first time.
func _ready():
	parse_data()

func parse_data():
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
				save_graph_data(ic.x, ic.y, ic.depth, ic.named)
			
			ic.star_type = str(line[4]).strip_edges()
			# does the star have planets?
			ic.planets = false
			if "yes" in line[5]:
				ic.planets = true

			if line.size() > 6:
				if str(line[6]).strip_edges() == "double":
					ic.multiple = line[6]
			
			# line[7] is for comments
			
			# ra-dec conversion
			if line.size() > 8 and line[1] == " -":
				#print("RA/DEC candidate...")
				var ra = line[8]
				var de = line[9] 
				if ra != "" and de != "" and line[10] != "":
					#print("RA/DEC convert for ", str(line[0]))
					var ra_deg = 0
					var dec = 0
					if "h" in ra and not "m" in ra:
						# if no minutes specified, we assume decimal hours
						# 15 degrees in an hour (360/24) 
						ra_deg = float(15*float(ra.rstrip("h")))
						# for now, assume degrees are given in decimal degrees
						dec = float(line[8])
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
					
					var dist = float(line[10])
					if "pc" in line[10]:
						dist = strip_units(line[10])
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# -------------------------------------------------------------------------
func find_icon_for_pos(pos):
	var ret = null
	
	# special case
	if pos == Vector3(0,0,0):
		ret = $"Control".get_node("Sol")
		return ret
	
	for c in $"Control".get_children():
		if 'pos' in c and c.pos == pos:
			ret = c
			break
	return ret

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
	var lookup = {"Barnards":"Barnard's Star", "Trappist": "Trappist-1"}	
	
	if game.player.w_hole.target_system:
		print("Target system: ", game.player.w_hole.target_system)
		
		var coords = unpack_vector(game.player.w_hole.target_system)
		#print("unpacked coords: ", coords)
		coords = positive_to_original(coords)
		#print("Coords: ", coords)
		var icon = find_icon_for_pos(coords)
		if icon != null:
			print("Icon: ", icon.get_name(), " @ ", coords) 
		$"Control".tg = icon
		icon.get_node("Label").set_self_modulate(Color(0,1,1))
		# reveal Z line and planet icon for target
		if icon.has_node("Line2D"):
			icon.get_node("Line2D").show()
		icon.get_node("StarTexture").show()
		
		# paranoia
		if $"Control".src == $"Control".tg:
			print("Something went wrong, same src and tg!!!")
		
	else:
		if system == "Sol":
			$"Control/proxima/Label".set_self_modulate(Color(0,1,1))
		if system == "Proxima":
			$"Control/alphacen/Label".set_self_modulate(Color(0,1,1))
		if system == "Luyten 726-8":
			$"Control/Tau Ceti/Label".set_self_modulate(Color(0,1,1))
	
	# center on star (needs target to be set because it resets the distance label)
	offset = -($"Control".src.rect_position+$"Control".src.get_node("StarTexture").rect_position)
	move_map_to_offset(offset)
	
	# show distance involved along the line
	# positioning label handled in move_map_to_offset() above
	get_node("Grid/VisControl/Label").set("custom_colors/font_color", Color(0,1,1))
	var dist = get_star_distance($"Control".src, $"Control".tg)
	get_node("Grid/VisControl/Label").set_text("%.2f ly" % (dist))
	# update displayed starmap info
	display_star_map_info($"Control".tg)

func display_star_map_info(star_icon):
	var text = ""
	# actual text begins here
	text = text + star_icon.named + "\n" + "\n"
	# basics
	text = text + "Star type/color: " + str(star_icon.star_type) + "\n"
	var fmt_multiple = "no" if not star_icon.multiple else str(star_icon.multiple)
	text = text + "Multiple system: " + fmt_multiple + "\n"
	var fmt_planets = "yes" if star_icon.planets else "no"
	text = text + "Planets: " + fmt_planets + "\n"
	
	# wormhole connections
	#var n = get_neighbors(star_icon.pos)
	# this one uses preconverted values unlike the function above
	var neighbors = map_astar.get_point_connections(mapping[star_icon.pos])
	
	var neighbors_text = ""
	for n in neighbors:
		var coords = unpack_vector(n)
		#print("unpacked coords: ", coords)
		coords = positive_to_original(coords)
		#print("Coords: ", coords)
		var icon = find_icon_for_pos(coords)
		
		neighbors_text += str(icon.get_name()) + ", " #str(n) would display the internal ID
	text = text + "Wormholes to: " + neighbors_text
	
	# need to go up the tree and back down :/
	var rtl = $"../../Control2/Panel_rightHUD/PanelInfo/StarSystemInfo/RichTextLabel"
	rtl.set_text(text)

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
	# halfway along
	var gl_loc = $"Control".get_src_loc() + ($"Control".get_tg_loc() - $"Control".get_src_loc())/2
	#print($"Control".get_tg_loc(),  " ", $"Control".get_src_loc(), " gl: ", gl_loc)
	get_node("Grid/VisControl/Label").set_global_position(gl_loc) 
	#get_node("Grid/VisControl/Label").rect_position = $"Control".rect_position + ($"Control".get_tg_loc() - $"Control".get_src_loc())/2
	
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
		offset = -(found.rect_position+found.get_node("PlanetTexture").rect_position)
		move_map_to_offset(offset)
