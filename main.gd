extends Control

# Declare member variables here. Examples:
var friendly = preload("res://ships/friendly_ship.tscn")
var starbase = preload("res://ships/starbase.tscn")
var drone = preload("res://ships//friendly_drone.tscn")

var enemy = preload("res://ships/enemy_ship.tscn")
var enemy_starbase = preload("res://ships/enemy_starbase.tscn")
var pirate_starbase = preload("res://ships/pirate_starbase.tscn")
var pirate_ship = preload("res://ships/pirate_ship.tscn")

var asteroid_processor = preload("res://ships/asteroid_processor.tscn")
var cycler = preload("res://ships/cycler.tscn")

var wormhole = preload("res://blackhole2D.tscn")

# star systems
var handmade_system = preload("res://systems/star system.tscn")
var proc_system = preload("res://systems//proc star system.tscn")
var sol = preload("res://systems/Sol system.tscn")
var trappist = preload("res://systems/Trappist system.tscn")
var proxima = preload("res://systems/Proxima Centauri system.tscn")
var alpha = preload("res://systems/Alpha Centauri system.tscn")
var barnards = preload("res://systems/Barnard's star system.tscn")
var uvceti = preload("res://systems/Luyten 726-8 system.tscn")
var tauceti = preload("res://systems/Tau Ceti system.tscn")
var wolf = preload("res://systems/Wolf 359 system.tscn")


# game core
var core = preload("res://game_core.tscn")

# how many higher ranks to assign to (friendly) AI
var rank_list = [1,1]

var curr_system = null
var mmap

func spawn_system(system="proc"):
	var sys = proc_system
	if system == "Sol":
		sys = sol
	elif system == "trappist":
		sys = trappist
	elif system == "proxima":
		sys = proxima
	elif system == "alphacen":
		sys = alpha
	elif system == "barnards":
		sys = barnards
	elif system == "wolf359":
		sys = wolf
	elif system == "luyten726-8":
		sys = uvceti
	elif system == "tauceti":
		sys = tauceti
		
	var system_inst = sys.instance()
	add_child(system_inst)
	
	return [system, system_inst]
	
func spawn_core():
	var cor = core.instance()
	add_child(cor)
	# spawn player
	get_tree().get_nodes_in_group("player")[0].get_child(0).spawn()
	# send position to parallax background
	get_node("ParallaxBackground").init_pos = get_tree().get_nodes_in_group("player")[0].get_global_position()
	#print("Init pos: ", get_node("ParallaxBackground").init_pos)



# Called when the node enters the scene tree for the first time.
func _ready():
	print("Main init")
	
	var syst = "trappist"
	
	if game.start != null:
		var lookup_system = {1: "Sol", 2: "trappist"}
		syst = lookup_system[game.start]
		
	var data = spawn_system(syst)
	
	# the system is always child #2 (#0 is parallax bg and #1 is a timer)
	curr_system = data[0]
	spawn_core() 
	
	var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
	print("Player index: " + str(p_ind))
	mmap = get_tree().get_nodes_in_group("minimap")[0]
	
	for i in range(4):
		spawn_friendly(i, p_ind, mmap)
	
	for i in range(4):
		spawn_friendly_drone(i, p_ind)
	
	spawn_starbase(curr_system, p_ind, mmap)
	var pos = spawn_enemy_starbase(curr_system, p_ind, mmap)
	# spawn related to enemy starbase
	for i in range(3):
		spawn_enemy(pos, i, p_ind, mmap)
	
	# wormhole
	if curr_system == "Sol":
		spawn_wormhole(p_ind, 11, mmap)
		# second wormhole to Barnard's
		spawn_wormhole(p_ind, 11, mmap, "barnards", Vector2(-1500,0))
		# some more...
		spawn_wormhole(p_ind, 11, mmap, "luyten726-8", Vector2(-1500, -750))
		spawn_wormhole(p_ind, 11, mmap, "wolf359", Vector2(-1500, 500))
	if curr_system == "proxima":
		spawn_wormhole(p_ind, 1, mmap)
		
	# UV Ceti has a manually added wormhole...
	
	spawn_asteroid_processor(p_ind, curr_system, mmap)
	spawn_cycler(p_ind, curr_system, mmap)
	
	var pirate = spawn_pirate_base(p_ind, curr_system, mmap)
	if pirate != null:
		for i in range(3):
			spawn_pirate(pirate, p_ind, mmap)
		
	mmap.move_player_sprite()
	
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

# all spawn functions spawn at node at system+1 index
func spawn_friendly(i, p_ind, m_map):
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
		get_child(3).add_child(sp)
		get_child(3).move_child(sp, p_ind+1)
		# doesn't work for some reason
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
		# give minimap icon
		#var mmap = get_tree().get_nodes_in_group("minimap")[0]
		m_map._on_friendly_ship_spawned(sp.get_child(0))
		
		# give higher ranks if any left
		if rank_list.size() > 0:
			sp.get_child(0).rank = rank_list.pop_front()
			print("Friendly " + sp.get_name() + " received rank " + str(sp.get_child(0).rank))
		
		print("Spawned friendly")
		# add to fleet census
		game.fleet1[1] += 1

func spawn_starbase(system, p_ind, m_map):
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
		get_child(3).add_child(sb)
		get_child(3).move_child(sb, p_ind+1)
		
		# give minimap icon
		#var mmap = get_tree().get_nodes_in_group("minimap")[0]
		m_map._on_starbase_spawned(sb.get_child(0))

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
		get_child(3).add_child(sp)
		get_child(3).move_child(sp, p_ind+1)
		# doesn't work for some reason
		#add_child_below_node(get_tree().get_nodes_in_group("player")[0], sp)
		
		# drones don't have minimap icons
		
func spawn_enemy_starbase(system, p_ind, m_map):
	var p
	
	var sb = enemy_starbase.instance()
	
	if system == "Sol":
		p = get_tree().get_nodes_in_group("planets")[1] # Venus # TODO: should be Saturn instead
	elif system == "proxima":
		p = get_tree().get_nodes_in_group("planets")[2]
	elif system == "trappist":
		p = get_tree().get_nodes_in_group("planets")[3]	
	else:
		p = get_tree().get_nodes_in_group("planets")[0]

	# random factor
	randomize()
	var offset = Vector2(rand_range(200, 400), rand_range(200, 400))
	sb.set_global_position(p.get_global_position() + offset)
	
	sb.set_name("enemy_base")
	get_child(3).add_child(sb)
	get_child(3).move_child(sb, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_enemy_starbase_spawned(sb.get_child(0))
	
	return sb.get_global_position()

func spawn_enemy(pos, i, p_ind, m_map):
	var sp = enemy.instance()
	# random factor
	randomize()
	var offset = Vector2(rand_range(50, 100), rand_range(50, 100))
	sp.set_global_position(pos + offset)
	print("Spawning enemy @ : " + str(pos + offset))
	sp.get_child(0).set_position(Vector2(0,0))
	sp.set_name("enemy"+str(i))
	get_child(3).add_child(sp)
	get_child(3).move_child(sp, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_enemy_ship_spawned(sp.get_child(0))
	
	# add to fleet census
	game.fleet2[1] += 1

func spawn_cycler(p_ind, system, m_map):
	if system != "Sol":
		return
	
	var e = get_tree().get_nodes_in_group("planets")[2]
	var m = get_tree().get_nodes_in_group("planets")[3]
	
	# B-A = A->B
	var offset = m.get_global_position()-e.get_global_position()
	
	var castle = cycler.instance()
	castle.set_global_position(e.get_global_position()+(offset/2))
	castle.set_name("cycler")
	get_child(3).add_child(castle)
	get_child(3).move_child(castle, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_starbase_spawned(castle.get_child(0))


func spawn_asteroid_processor(p_ind, system, m_map):
	if system != "Sol":
		return
		
	var p = get_tree().get_nodes_in_group("aster_belt")[0]
	
	var ap = asteroid_processor.instance()
	# random factor
	randomize()
	var offset = Vector2(rand_range(200, 400), rand_range(200, 400))
	# asteroid belt's position is 0,0 so we have to add radius
	ap.set_global_position(p.get_global_position()+Vector2(0,p.radius*game.AU) + offset)
	
	ap.set_name("friendly_processor")
	get_child(3).add_child(ap)
	get_child(3).move_child(ap, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_starbase_spawned(ap.get_child(0))

func spawn_pirate_base(p_ind, system, m_map):
	if system != "Sol":
		return
		
	var p = get_tree().get_nodes_in_group("aster_belt")[0]
	
	var ap = pirate_starbase.instance()
	# random factor
	randomize()
	var offset = Vector2(rand_range(800, 1600), rand_range(200, 400))
	# asteroid belt's position is 0,0 so we have to add radius
	var pos = p.get_global_position()+Vector2(0,p.radius*game.AU) + offset
	ap.set_global_position(pos)
	
	ap.set_name("pirate_base")
	get_child(3).add_child(ap)
	get_child(3).move_child(ap, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_pirate_starbase_spawned(ap.get_child(0))
	
	return pos

func spawn_pirate(pos, p_ind, m_map):
	var sp = pirate_ship.instance()
	# random factor
	randomize()
	var offset = Vector2(rand_range(50, 100), rand_range(50, 100))
	sp.set_global_position(pos + offset)
	print("Spawning pirate @ : " + str(pos + offset))
	sp.get_child(0).set_position(Vector2(0,0))
	sp.set_name("pirate") #+str(i))
	get_child(3).add_child(sp)
	get_child(3).move_child(sp, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	m_map._on_pirate_ship_spawned(sp.get_child(0))

func spawn_wormhole(p_ind, planet_id, m_map, target_system=null, offset=Vector2(0,0), need_icon=true):
	var wh = wormhole.instance()
	
	# fix for smaller systems
	if planet_id > get_tree().get_nodes_in_group("planets").size():
		return
	
	var p = get_tree().get_nodes_in_group("planets")[planet_id]
	
	# random factor
	randomize()
	var r_offset = Vector2(rand_range(250, 300), rand_range(250, 300))
	
	wh.set_global_position(p.get_global_position() + offset + r_offset)
	
	wh.set_name("wormhole")
	if target_system != null:
		wh.target_system = target_system
	
	get_child(2).add_child(wh)
	get_child(2).move_child(wh, p_ind+1)
	
	# give minimap icon
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	if need_icon:
		m_map._on_wormhole_spawned(wh)
	
	if target_system != null:
		print("Spawned a wormhole to " + str(target_system) + " at " + str(wh.get_global_position()))
	else:
		print("Spawned a wormhole at " + str(wh.get_global_position()))

	#return wh.get_global_position()

# -------------------------------------
func move_player(system, travel=0.0):
	var place = null
	# move player
	var first_star = ["proxima", "Sol", "barnards", "wolf359", "luyten726-8", "tauceti"]
	# FIXME: doesn't really place correctly?
	if system in first_star:
	#var place = get_tree().get_nodes_in_group("planets")[1] 
		place = get_tree().get_nodes_in_group("star")[0]
	if system == "alphacen":
		place = get_tree().get_nodes_in_group("star")[1]
	print("Place: " + str(place.get_global_position()))
	game.player.get_parent().set_global_position(place.get_global_position())
	game.player.set_position(Vector2(0,0))

	#call_deferred("update_HUD")
	
	# officer message
	# get actual system name
	var system_name = get_child(2).get_name()
	
	var travel_months = int(floor(travel))
	# for convenience, assume a month has 30 days
	var days = (travel-travel_months)*30
	var format_travel = "%d months %d days" % [travel_months, days]
	# add them to date
	game.increment_date(int(floor(days)), travel_months)
	#game.date = [game.date[0]+int(floor(days)), game.date[1]+travel_months, game.date[2]]
	var format_date = "%02d-%02d-%d" % [game.date[0], game.date[1], game.date[2]]
	var msg = str("Welcome to ", system_name, " we arrived: ", format_travel, " after departure. The current date is: ", format_date);
	print(str(travel) + " months, " + str(days) + " days ")
	game.player.emit_signal("officer_message", msg)
	
func update_HUD():
	# force update orrery
	var orr = mmap.get_parent().get_node("orrery")
	orr.setup()
	# show the panel again
	orr.get_node("Panel").show()
	
	# force update minimap
	#mmap._ready()
	mmap.get_system_bodies()
	mmap.add_system_bodies()
	mmap.move_player_sprite()

	# force update planet listing
	game.player.HUD.planets = get_tree().get_nodes_in_group("planets")
	game.player.HUD.get_node("Control2").planets = get_tree().get_nodes_in_group("planets")
	game.player.HUD.create_planet_listing()
	# force update direction labels
	game.player.HUD.create_direction_labels()
	
	# connect planet signals
	game.player.HUD.connect_planet_signals(get_tree().get_nodes_in_group("planets"))
	

func change_system(system="proxima", time=0.0):
	# despawn current system
	get_child(2).queue_free()
	
	# close starmap
	game.player.HUD.hide_starmap()
	
	# clean minimap
	#var mmap = get_tree().get_nodes_in_group("minimap")[0]
	for i in range(2, mmap.get_child_count()-1):
		if mmap.get_child(i).get_name() == "player":
			continue # skip player	
		mmap.get_child(i).queue_free()
	mmap.cleanup()
	
	# clean direction labels
	# 0 and 1 are used for officer messages
	for i in range(2, game.player.HUD.get_node("Control3").get_child_count()):
		game.player.HUD.get_node("Control3").get_child(i).queue_free()
	game.player.HUD.dir_labels = []
	
	# despawn all ships and starbases
	var sb = get_tree().get_nodes_in_group("starbase")
	for s in sb:
		s.get_parent().queue_free()

	var f = get_tree().get_nodes_in_group("friendly")
	for s in f:
		s.get_parent().queue_free()

	var e = get_tree().get_nodes_in_group("enemy")
	for s in e:
		s.get_parent().queue_free()
	
	# clean orrery
	var orr = mmap.get_parent().get_node("orrery")
	for i in range(1, orr.get_child_count()):
		orr.get_child(i).queue_free()
	orr.cleanup()
	# hide the orrery panel temporarily (preventing drawing of orbits)
	orr.get_node("Panel").hide()
	
	# close planet view/listing
	if game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
		game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").hide()
	if game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
		game.player.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").hide()
		
	# clear hud planet listing
	game.player.HUD.clear_planet_listing()
	
	# spawn new system
	var data = spawn_system(system)
	curr_system = data[0]
	move_child(data[1], 2)
	print("System after change: ", curr_system)
	
	var p_ind = get_tree().get_nodes_in_group("player")[0].get_index()
	print("Player index: " + str(p_ind))
	
	# wormhole
	if system == "proxima":
		spawn_wormhole(p_ind, 1, mmap, null, Vector2(0,0), false)
		spawn_wormhole(p_ind, 0, mmap, "Sol", Vector2(0,0), false)
	
	# timer
	get_node("Timer").start()
	
	call_deferred("move_player", system, time)


func _on_Timer_timeout():
	update_HUD()
