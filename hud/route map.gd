# this map emulates a style variously known as "London Underground map", "tube map", "connection map" or "node map"
#tool
extends Control
#extends "../galaxy.gd" 


# Declare member variables here. Examples:
var map = null
var mapping = []
var ruler = null

# Called when the node enters the scene tree for the first time.
func _ready():
	ruler = preload("res://hud/ruler.tscn")
	map = get_parent().get_node("star map")
	var stars_c = map.get_node("Control").get_child_count()
	get_node("Node2D").total = stars_c
	get_node("Node2D").set_seed(get_node("Node2D").seede)

	
	#get_parent().get_node("star map").map_astar
	
	for i in range(1, stars_c):
		if map.get_node("Control").get_child(i) is TextureRect:
			continue # skip ship marker
		var star_icon = map.get_node("Control").get_child(i)
		# map things
		#mapping[star_icon] = i
		#mapping[i] = star_icon
		mapping.append(star_icon)
		# show names
		var l = Label.new()
		#print(get_node("Node2D").samples[i])
		var node_pos = Vector2(get_node("Node2D").samples[i-1][0], get_node("Node2D").samples[i-1][1])
		l.set_position(node_pos + Vector2(-15, -20))
		l.set_text(star_icon.get_node("Label").get_text())
		l.set_name(star_icon.get_name())
		add_child(l)
		
		
		
	# now check connections
	# because we have Node2D before our labels
	for i in range(2, get_child_count()-1):
		#print("i: ", i, ": ", get_child(i).get_name())
		var star_icon = mapping[i-2]
		#print("Checking neighbors for ", star_icon.get_name())
		
		var neighbors = []
		if 'pos' in star_icon:
			neighbors = map.map_astar.get_point_connections(map.mapping[star_icon.pos])
		else:
			neighbors = map.map_astar.get_point_connections(map.mapping[Vector3(0,0,0)])
	
		#var neighbor_icons = []
		for n in neighbors:
			var coords = map.unpack_vector(n)
			#print("unpacked coords: ", coords)
			coords = map.positive_to_original(coords)
			#print("Coords: ", coords)
			var icon = map.find_icon_for_pos(coords)
			#print(icon)
			var id = -1
			#id = mapping[icon]
			for _icon in mapping:
				if _icon == icon:
					print("Icon found: ", _icon, " @ index: ", mapping.find(_icon))
					id = mapping.find(_icon)
					break

			if id > 1: id += 1 # hackfix
			var next_node_pos = Vector2(get_node("Node2D").samples[id-1][0], get_node("Node2D").samples[id-1][1])
			print("Node pos for id ", id, ": ", next_node_pos+Vector2(-15,-20))
			#next_node_pos + Vector2(-15,-20)
			
			var dist_f = get_distance(star_icon, icon)
			
			# draw a ruler now
			var r = ruler.instantiate()
			r.pts = [get_child(i).get_position()+Vector2(15,20), next_node_pos]
			r.text = str(dist_f)
			r.set_name(star_icon.get_name() + " " + icon.get_name())
			add_child(r)

	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func get_distance(star_icon,icon):
	var dist = map.get_star_distance(star_icon, icon)
	
	var dist_f = "%.2f" % dist

	return dist_f

#func _draw():
#	for pt in midpts:
#		draw_circle(pt, 5, Color(0,1,1))
