tool
extends Control


# Declare member variables here. Examples:

var icon = preload("res://hud/star map icon.tscn")

# data
var data = []


# Called when the node enters the scene tree for the first time.
func _ready():
	data = load_data()
	for line in data:
		# name, x, y, z, color
		print(line)
		if line[0] != "Sol" and line[0] != "Tau Ceti":
			var ic = icon.instance()
			ic.named = str(line[0])
			# strip units
			ic.x = strip_units(str(line[1]))
			#ic.x = float(line[1])
			ic.y = strip_units(str(line[2]))
			ic.depth = strip_units(str(line[3]))
			
			# test ra-dec conversion
			if line[5] != "" and line[6] != "" and line[7] != "":
				if "h" in line[5] and not "m" in line[5]:
					# if no minutes specified, we assume decimal hours
					# 15 degrees in an hour (360/24) 
					var ra_deg = float(15*float(line[5].rstrip("h")))
					# for now, assume degrees are given in decimal degrees
					var dec = float(line[6])
					galactic_from_ra_dec(ra_deg, dec, float(line[7]))
					# we need to minus the y coordinate for our uses for some reason?
			
			get_node("Control").add_child(ic)
	
	
func strip_units(entry):
	var num = 0.0
	if "ly" in entry:
		num = float(entry.rstrip("ly"))
	elif "pc" in entry:
		num = float(entry.rstrip("pc"))
	return num

# based on Winchell Chung's Star3D spreadsheet and 
# http://starmap.whitten.org/files/src/gal_pl.txt
# input in degrees by default!!!
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

func update_marker(marker):
	# update marker position
	var system = get_tree().get_nodes_in_group("main")[0].curr_system

	if system == "Sol":
		marker.get_parent().remove_child(marker)
		$"Control/Sol".add_child(marker)
	if system == "proxima":
		marker.get_parent().remove_child(marker)
		$"Control/proxima".add_child(marker)
	if system == "alphacen":
		marker.get_parent().remove_child(marker)
		$"Control/alphacen".add_child(marker)
	if system == "luyten726-8":
		marker.get_parent().remove_child(marker)
		$"Control/Luyten 726-8".add_child(marker)
	if system == "tauceti":
		marker.get_parent().remove_child(marker)
		$"Control/tau ceti".add_child(marker)
	if system == "barnards":
		marker.get_parent().remove_child(marker)
		$"Control/Barnard's Star".add_child(marker)
	if system == "wolf359":
		marker.get_parent().remove_child(marker)
		$"Control/Wolf 359".add_child(marker)

	# show target on map (tint cyan)
	for c in get_node("Control").get_children():
		c.get_node("Label").set_self_modulate(Color(1,1,1))
	
	
	var lookup = {"luyten726-8": "Luyten 726-8", "barnards":"Barnard's Star", "wolf359":"Wolf 359"}	
	
	if game.player.w_hole.target_system:
		print("Target system: ", game.player.w_hole.target_system)
		get_node("Control").get_node(lookup[game.player.w_hole.target_system]).get_node("Label").set_self_modulate(Color(0,1,1))
	else:
		if system == "Sol":
			$"Control/proxima/Label".set_self_modulate(Color(0,1,1))
		if system == "proxima":
			$"Control/alphacen/Label".set_self_modulate(Color(0,1,1))
		if system == "luyten726-8":
			$"Control/tau ceti/Label".set_self_modulate(Color(0,1,1))
