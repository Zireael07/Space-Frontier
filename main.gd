extends Control

# Declare member variables here. Examples:
var friendly = preload("res://friendly_ship.tscn")

# star systems
var proc_system = preload("res://star system.tscn")
var sol = preload("res://Sol system.tscn")
var trappist = preload("res://Trappist system.tscn")

# game core
var core = preload("res://game_core.tscn")

func spawn_system(system="proc"):
	var sys = proc_system
	if system == "Sol":
		sys = sol
	elif system == "trappist":
		sys = trappist
		
	var system_inst = sys.instance()
	add_child(system_inst)
	
func spawn_core():
	var cor = core.instance()
	add_child(cor)



# Called when the node enters the scene tree for the first time.
func _ready():
	print("Main init")
	
	spawn_system()
	spawn_core()
	
	spawn_friendly()
	
	
	#pass # Replace with function body.

func get_colonized_planet():
	var ret
	var ps = get_tree().get_nodes_in_group("planets")
	for p in ps:
		# is it colonized?
		var col = p.has_colony()
		if col and col == "colony":
			ret = p

	if ret != null:
		return ret
	else:
		print("No colonized planet found")
		return null


func spawn_friendly():
	var p = get_colonized_planet()
	if p:
		var sp = friendly.instance()
		# random factor
		randomize()
		var offset = Vector2(rand_range(50, 150), rand_range(50, 150))
		sp.set_global_position(p.get_global_position() + offset)
		print("Spawning @ : " + str(p.get_global_position() + offset))
		sp.get_child(0).set_position(Vector2(0,0))
		sp.set_name("friendly2")
		get_child(2).add_child(sp)
		var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
		print("Player index: " + str(p_ind))
		get_child(2).move_child(sp, p_ind+1)
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
		# give minimap icon
		var mmap = get_tree().get_nodes_in_group("minimap")[0]
		mmap._on_ship_spawned(sp.get_child(0))
		
		print("Spawned friendly")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
