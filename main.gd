extends Control

# Declare member variables here. Examples:
var friendly = preload("res://ships/friendly_ship.tscn")
var starbase = preload("res://ships/starbase.tscn")
var enemy_starbase = preload("res://ships/enemy_starbase.tscn")

# star systems
var proc_system = preload("res://systems/star system.tscn")
var sol = preload("res://systems/Sol system.tscn")
var trappist = preload("res://systems/Trappist system.tscn")

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
	
	return system
	
func spawn_core():
	var cor = core.instance()
	add_child(cor)



# Called when the node enters the scene tree for the first time.
func _ready():
	print("Main init")
	
	var system = spawn_system()
	spawn_core()
	
	for i in range(4):
		spawn_friendly(i)
	
	spawn_starbase()
	spawn_enemy_starbase(system)
	
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


func spawn_friendly(i):
	var p = get_colonized_planet()
	if p:
		var sp = friendly.instance()
		# random factor
		randomize()
		var offset = Vector2(rand_range(50, 150), rand_range(50, 150))
		sp.set_global_position(p.get_global_position() + offset)
		print("Spawning @ : " + str(p.get_global_position() + offset))
		sp.get_child(0).set_position(Vector2(0,0))
		sp.set_name("friendly"+str(i))
		get_child(2).add_child(sp)
		var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
		print("Player index: " + str(p_ind))
		get_child(2).move_child(sp, p_ind+1)
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
		# give minimap icon
		var mmap = get_tree().get_nodes_in_group("minimap")[0]
		mmap._on_ship_spawned(sp.get_child(0))
		
		print("Spawned friendly")

func spawn_starbase():
	var p = get_colonized_planet()
	
	if p:
		var sb = starbase.instance()
		# random factor
		randomize()
		var offset = Vector2(rand_range(500, 1000), rand_range(500, 1000))
		sb.set_global_position(p.get_global_position() + offset)
		sb.set_name("friendly_base")
		get_child(2).add_child(sb)
		var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
		print("Player index: " + str(p_ind))
		get_child(2).move_child(sb, p_ind+1)
		
		# give minimap icon
		var mmap = get_tree().get_nodes_in_group("minimap")[0]
		mmap._on_starbase_spawned(sb.get_child(0))
		
func spawn_enemy_starbase(system):
	var p
	
	var sb = enemy_starbase.instance()
	
	if system == "Sol":
		p = get_tree().get_nodes_in_group("planets")[1] # Venus
	else:
		p = get_tree().get_nodes_in_group("planets")[3]

	# random factor
	randomize()
	var offset = Vector2(rand_range(200, 400), rand_range(200, 400))
	sb.set_global_position(p.get_global_position() + offset)
	
	sb.set_name("enemy_base")
	get_child(2).add_child(sb)
	var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
	print("Player index: " + str(p_ind))
	get_child(2).move_child(sb, p_ind+1)
	
	# give minimap icon
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	mmap._on_enemy_starbase_spawned(sb.get_child(0))

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
