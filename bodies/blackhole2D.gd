extends Node2D

var entered = false
var active = false
var target_system = null
var ly = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	# override texture size
	get_node("Sprite2").texture.set_size_override(Vector2i(50, 50))
	pass # Replace with function body.


# change the system
func jump():
	var system = get_tree().get_nodes_in_group("main")[0].curr_system
	#if target_system != null:
	var time = 0.5 #default
	# calculate distances involved
	var starmap = game.player.HUD.get_node("Control4/star map")
	ly = starmap.get_star_distance(starmap.get_node("Control").src, starmap.get_node("Control").w_hole_tg)
	print("Calculated ly: ", ly)
	time = ly/game.WORMHOLE_SPEED # fraction of a year
	
	time = time * 12 # because one month is 1/12 of a year
	get_tree().get_nodes_in_group("main")[0].change_system(starmap.get_node("Control").w_hole_tg, time) #target_system, time)
	return 

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



func _on_Area2D2_area_entered(area):
	if area.get_parent().get_groups().has("player"):
		area.disrupted = true
		area.get_node("shield_indicator").hide()

func _on_Area2D2_area_exited(area):
	if area.get_parent().get_groups().has("player"):
		area.disrupted = false
		area.get_node("shield_indicator").show()
