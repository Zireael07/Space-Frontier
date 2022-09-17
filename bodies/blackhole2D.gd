extends Node2D

var entered = false
var active = false
var target_system = null
var ly = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func jump():
	var system = get_tree().get_nodes_in_group("main")[0].curr_system
	if target_system != null:
		var time = 0.5 #default
		# calculate distances involved
		var starmap = game.player.HUD.get_node("Control4/star map")
		ly = starmap.get_star_distance(starmap.get_node("Control").src, starmap.get_node("Control").tg)
		print("Calculated ly: ", ly)
		time = ly/game.WORMHOLE_SPEED # fraction of a year
		
		if target_system == "Sol":
			ly = 4.24
			print("Distance: ", ly, " light years")
			time = ly/game.WORMHOLE_SPEED # fraction of a year

		time = time * 12 # because one month is 1/12 of a year
		get_tree().get_nodes_in_group("main")[0].change_system(target_system, time)
		return 

	# change the system
	# TODO: target systems and distances should be drawn from an external source of truth
	# to be in sync with the starmap graph
	if system == "Sol":
		ly = 4.24
		print("Distance: ", ly, " light years")
		var time = ly/game.WORMHOLE_SPEED # fraction of a year
		time = time * 12 # because one month is 1/12 of a year
		get_tree().get_nodes_in_group("main")[0].change_system("Proxima", time)
	if system == "Proxima":
		ly = 0.21 # between Proxima and Alpha Centauri
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Alpha Centauri", time)
	if system == "Luyten 726-8":
		ly = 3.38 # between UV Ceti and Tau Ceti
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Tau Ceti", time)
	if system == "Tau Ceti":
		ly = 6.8 # between Tau Ceti and Gliese 1002
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Gliese 1002", time)
	if system == "Gliese 1002":
		ly = 8.78 # between Gliese 1002 and Gliese 1286
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Gliese 1286", time)
	if system == "Gliese 1286":
		ly = 11.31 # between Gliese 1286 and Gliese 867
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Gliese 867", time)
	if system == "Gliese 867":
		ly = 6.7 # between Gliese 867 and Gliese 1265
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Gliese 1265", time)
	if system == "Gliese 1265":
		ly = 3.7 # between Gliese 1265 to Gliese 4281
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Gliese 4281", time)
	if system == "Gliese 4281":
		ly = 9.7
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("Trappist", time)


func _on_Area2D_area_entered(_area):
	if _area.get_parent().get_groups().has("player"):
		if active and not entered:
			var system = get_tree().get_nodes_in_group("main")[0].curr_system
			print("Wormhole entered in system: ", system)
			entered = true
			
			game.player.w_hole = self
			game.player.HUD.show_starmap()
		


func _on_Timer_timeout():
	active = true
	#pass # Replace with function body.
