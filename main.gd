extends Control

# Declare member variables here. Examples:
var friendly = preload("res://ships/friendly_ship.tscn")
var starbase = preload("res://ships/starbase.tscn")
var drone = preload("res://ships//friendly_drone.tscn")

var enemy = preload("res://ships/enemy_ship.tscn")
var enemy_starbase = preload("res://ships/enemy_starbase.tscn")

var wormhole = preload("res://blackhole2D.tscn")

# star systems
var proc_system = preload("res://systems/star system.tscn")
var sol = preload("res://systems/Sol system.tscn")
var trappist = preload("res://systems/Trappist system.tscn")
var proxima = preload("res://systems/Proxima Centauri system.tscn")

# game core
var core = preload("res://game_core.tscn")

# how many higher ranks to assign to (friendly) AI
var rank_list = [1,1]

func spawn_system(system="proc"):
	var sys = proc_system
	if system == "Sol":
		sys = sol
	elif system == "trappist":
		sys = trappist
	elif system == "proxima":
		sys = proxima
		
	var system_inst = sys.instance()
	add_child(system_inst)
	
	return [system, system_inst]
	
func spawn_core():
	var cor = core.instance()
	add_child(cor)



# Called when the node enters the scene tree for the first time.
func _ready():
	print("Main init")
	
	var data = spawn_system("Sol") # this is always child #2 (#0 is parallax bg and #1 is a timer)
	var system = data[0]
	spawn_core() 
	
	var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
	print("Player index: " + str(p_ind))
	
	for i in range(4):
		spawn_friendly(i, p_ind)
	
	for i in range(4):
		spawn_friendly_drone(i, p_ind)
	
	spawn_starbase(system, p_ind)
	var pos = spawn_enemy_starbase(system, p_ind)

	spawn_enemy(pos, p_ind)
	
	# test
	spawn_wormhole(p_ind, 11)
	
	# update census
	var flt1 = "Fleet 1	" + str(game.fleet1[0]) + "		" + str(game.fleet1[1]) + "	" + str(game.fleet1[2])
	var flt2 = "Fleet 2	" + str(game.fleet1[0]) + "		" + str(game.fleet2[1]) + "	" + str(game.fleet2[2])
	game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label1").set_text(flt1)
	game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label2").set_text(flt2)


# ------------------------------------

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


func spawn_friendly(i, p_ind):
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
		get_child(2).move_child(sp, p_ind+1)
		# doesn't work for some reason
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
		# give minimap icon
		var mmap = get_tree().get_nodes_in_group("minimap")[0]
		mmap._on_friendly_ship_spawned(sp.get_child(0))
		
		# give higher ranks if any left
		if rank_list.size() > 0:
			sp.get_child(0).rank = rank_list.pop_front()
			print("Friendly " + sp.get_name() + " received rank " + str(sp.get_child(0).rank))
		
		print("Spawned friendly")
		# add to fleet census
		game.fleet1[1] += 1

func spawn_starbase(system, p_ind):
	var p = get_colonized_planet()
	
	if p:
		var sb = starbase.instance()
		randomize()
		
		# max offset
		var max_o = 700
		
		if system == "Sol":
			max_o = 1000
			
		# random factor
		var offset = Vector2(rand_range(500, max_o), rand_range(500, max_o))
		
		# sign
		if system == "proc":
			# force negative
			offset = offset*-1
		else:
			var sig = randf()		
			if sig > 0.5:
				offset = offset*-1
			
		sb.set_global_position(p.get_global_position() + offset)
		sb.set_name("friendly_base")
		get_child(2).add_child(sb)
		get_child(2).move_child(sb, p_ind+1)
		
		# give minimap icon
		var mmap = get_tree().get_nodes_in_group("minimap")[0]
		mmap._on_starbase_spawned(sb.get_child(0))

func spawn_friendly_drone(i, p_ind):
	var p = get_colonized_planet()
	if p:
		var sp = drone.instance()
		# random factor
		randomize()
		var offset = Vector2(rand_range(50, 150), rand_range(50, 150))
		sp.set_global_position(p.get_global_position() + offset)
		#print("Spawning @ : " + str(p.get_global_position() + offset))
		sp.get_child(0).set_position(Vector2(0,0))
		sp.set_name("friend_drone"+str(i))
		get_child(2).add_child(sp)
		get_child(2).move_child(sp, p_ind+1)
		# doesn't work for some reason
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
func spawn_enemy_starbase(system, p_ind):
	var p
	
	var sb = enemy_starbase.instance()
	
	if system == "Sol":
		p = get_tree().get_nodes_in_group("planets")[1] # Venus
	elif system == "proxima":
		p = get_tree().get_nodes_in_group("planets")[2]
	else:
		p = get_tree().get_nodes_in_group("planets")[3]

	# random factor
	randomize()
	var offset = Vector2(rand_range(200, 400), rand_range(200, 400))
	sb.set_global_position(p.get_global_position() + offset)
	
	sb.set_name("enemy_base")
	get_child(2).add_child(sb)
	get_child(2).move_child(sb, p_ind+1)
	
	# give minimap icon
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	mmap._on_enemy_starbase_spawned(sb.get_child(0))
	
	return sb.get_global_position()

func spawn_enemy(pos, p_ind):
	var sp = enemy.instance()
	# random factor
	randomize()
	var offset = Vector2(rand_range(50, 100), rand_range(50, 100))
	sp.set_global_position(pos + offset)
	print("Spawning enemy @ : " + str(pos + offset))
	sp.get_child(0).set_position(Vector2(0,0))
	sp.set_name("enemy") #+str(i))
	get_child(2).add_child(sp)
	get_child(2).move_child(sp, p_ind+1)
	
	# give minimap icon
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	mmap._on_enemy_ship_spawned(sp.get_child(0))

func spawn_wormhole(p_ind, planet_id):
	var wh = wormhole.instance()
	
	# fix for smaller systems
	if planet_id > get_tree().get_nodes_in_group("planets").size():
		return
	
	var p = get_tree().get_nodes_in_group("planets")[planet_id]
	
	# random factor
	randomize()
	var offset = Vector2(rand_range(250, 300), rand_range(250, 300))
	
	wh.set_global_position(p.get_global_position() + offset)
	
	wh.set_name("wormhole")
	get_child(2).add_child(wh)
	get_child(2).move_child(wh, p_ind+1)
	
	# give minimap icon
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	mmap._on_wormhole_spawned(wh)
	
	print("Spawned a wormhole at " + str(wh.get_global_position()))

	#return wh.get_global_position()

func move_player():
	# move player
	#var place = get_tree().get_nodes_in_group("planets")[1] 
	var place = get_tree().get_nodes_in_group("star")[0]
	print("Place: " + str(place.get_global_position()))
	game.player.get_parent().set_global_position(place.get_global_position())
	game.player.set_position(Vector2(0,0))

	#call_deferred("update_HUD")
	
func update_HUD():
	# force update minimap
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	#mmap._ready()
	mmap.get_system_bodies()
	mmap.add_system_bodies()
	mmap.move_player_sprite()
	
	# force update orrery
	var orr = mmap.get_parent().get_node("orrery")
	orr._ready()

	# force update planet listing
	game.player.HUD.planets = get_tree().get_nodes_in_group("planets")
	game.player.HUD.create_planet_listing()

func change_system(system="proxima"):
	# despawn current system
	get_child(2).queue_free()
	
	# clean minimap
	var mmap = get_tree().get_nodes_in_group("minimap")[0]
	for i in range(2, mmap.get_child_count()-1):
		if mmap.get_child(i).get_name() == "player":
			continue # skip player	
		mmap.get_child(i).queue_free()
	mmap.cleanup()
	
	# clean orrery
	var orr = mmap.get_parent().get_node("orrery")
	for i in range(1, orr.get_child_count()-1):
		orr.get_child(i).queue_free()
	orr.cleanup()
	
	# clear hud planet listing
	game.player.HUD.clear_planet_listing()
	
	# spawn new system
	var data = spawn_system(system)
	move_child(data[1], 2)
	
	# timer
	get_node("Timer").start()
	
	call_deferred("move_player")


func _on_Timer_timeout():
	update_HUD()
