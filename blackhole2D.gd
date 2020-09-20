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


func _on_Area2D_area_entered(_area):
	if not entered and active:
		var system = get_tree().get_nodes_in_group("main")[0].curr_system
		print("Wormhole entered in system: ", system)
		entered = true
		
		if target_system != null:
			get_tree().get_nodes_in_group("main")[0].change_system(target_system)
			return 
			
		# change the system
		if system == "Sol":
			ly = 4.24
			print("Distance: ", ly, " light years")
			get_tree().get_nodes_in_group("main")[0].change_system("proxima")
		if system == "proxima":
			ly = 0.21 # between Proxima and Alpha Centauri
			print("Distance: ", ly, " light years")
			get_tree().get_nodes_in_group("main")[0].change_system("alphacen")
		
		


func _on_Timer_timeout():
	active = true
	#pass # Replace with function body.
