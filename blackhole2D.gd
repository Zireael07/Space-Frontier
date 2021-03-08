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
		var time = 0.5
		if target_system == "Sol":
			ly = 4.24
			print("Distance: ", ly, " light years")
			time = ly/game.WORMHOLE_SPEED # fraction of a year

		time = time * 12 # because one month is 1/12 of a year
		get_tree().get_nodes_in_group("main")[0].change_system(target_system, time)
		return 

	# change the system
	if system == "Sol":
		ly = 4.24
		print("Distance: ", ly, " light years")
		var time = ly/game.WORMHOLE_SPEED # fraction of a year
		time = time * 12 # because one month is 1/12 of a year
		get_tree().get_nodes_in_group("main")[0].change_system("proxima", time)
	if system == "proxima":
		ly = 0.21 # between Proxima and Alpha Centauri
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("alphacen", time)
	if system == "luyten726-8":
		ly = 3.38 # between UV Ceti and Tau Ceti
		var time = ly/game.WORMHOLE_SPEED
		time = time * 12 # because one month is 1/12 of a year
		print("Distance: ", ly, " light years")
		get_tree().get_nodes_in_group("main")[0].change_system("tauceti", time)


func _on_Area2D_area_entered(_area):
	if not entered and active:
		var system = get_tree().get_nodes_in_group("main")[0].curr_system
		print("Wormhole entered in system: ", system)
		entered = true
		
		game.player.w_hole = self
		game.player.HUD.show_starmap()
		


func _on_Timer_timeout():
	active = true
	#pass # Replace with function body.
