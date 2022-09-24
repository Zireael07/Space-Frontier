extends Node2D

var entered = false
var active = false
var target_system = null
var ly = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# change the system
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

# TODO: target systems should be drawn from an external source of truth
# to be in sync with the starmap graph
var lookup_target = {"Sol": "Proxima", "Proxima":"Alpha Centauri", "Luyten 726-8":"Tau Ceti", "Tau Ceti":"Gliese 1002",
"Gliese 1002": "Gliese 1286", "Gliese 1286":"Gliese 867", "Gliese 867":"Gliese 1265", "Gliese 1265":"Gliese 4281", "Gliese 4281":"Trappist"
}
func get_target_system(system):
	return lookup_target[system]

func _on_Area2D_area_entered(_area):
	if _area.get_parent().get_groups().has("player"):
		if active and not entered:
			var system = get_tree().get_nodes_in_group("main")[0].curr_system
			print("Wormhole entered in system: ", system)
			if target_system == null:
				target_system = get_target_system(system)
			
			entered = true
			
			game.player.w_hole = self
			game.player.HUD.show_starmap()
		


func _on_Timer_timeout():
	active = true
	#pass # Replace with function body.



func _on_Area2D2_area_entered(area):
	if area.get_parent().get_groups().has("player"):
		area.disrupted = true
		area.get_node("shield_indicator").hide()

func _on_Area2D2_area_exited(area):
	if area.get_parent().get_groups().has("player"):
		area.disrupted = false
		area.get_node("shield_indicator").show()
