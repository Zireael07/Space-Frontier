# this map emulates a style variously known as "London Underground map", "tube map", "connection map" or "node map"
#tool
extends Control
#extends "../galaxy.gd" 


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var stars_c = get_parent().get_node("star map").get_node("Control").get_child_count()
	get_node("Node2D").total = stars_c
	get_node("Node2D").set_seed(get_node("Node2D").seede)

	
	#get_parent().get_node("star map").map_astar
	
	for i in range(stars_c):
		if get_parent().get_node("star map").get_node("Control").get_child(i) is TextureRect:
			continue # skip ship marker
		var l = Label.new()
		#print(get_node("Node2D").samples[i])
		var node_pos = Vector2(get_node("Node2D").samples[i][0], get_node("Node2D").samples[i][1])
		l.set_position(node_pos + Vector2(-15, -20))
		l.set_text(get_parent().get_node("star map").get_node("Control").get_child(i).get_node("Label").get_text())
		add_child(l)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
