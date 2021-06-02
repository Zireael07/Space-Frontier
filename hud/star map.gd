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
		if line[0] == "Barnard's Star" or line[0] == "Wolf 359" or line[0] == "Luyten 726-8":
			var ic = icon.instance()
			ic.named = str(line[0])
			ic.x = float(line[1])
			ic.y = float(line[2])
			ic.depth = float(line[3])
			
			get_node("Control").add_child(ic)
	
	
	#pass # Replace with function body.

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
