extends Area2D

# Declare member variables here. Examples:
const LIGHT_SPEED = 400 # original Stellar Frontier seems to have used 200 px/s

export var rot_speed = 2.6 #radians
export var thrust = 0.25 * LIGHT_SPEED
export var max_vel = 0.5 * LIGHT_SPEED
# IRL there's no friction in space, but
# it's there mostly to ensure the ship doesn't float too far beyond the system
# if the AI or the player gets stuck/forgets where he was going
export var friction = 0.25 

# motion
var rot = 0
var pos = Vector2()
var vel = Vector2()
var acc = Vector2()

var spd = 0

var orbiting = null
var warping = false

# shields
var shields = 100
signal shield_changed

var shield_recharge = 5

# power
var power = 100
var shield_power_draw = 5 # none in the original game, but that way it's more realistic
signal power_changed

# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"
onready var explosion = preload("res://explosion.tscn")
onready var debris = preload("res://debris_enemy.tscn")
var deb_chances = []
onready var colony = preload("res://colony.tscn")

var tractor = null

var docked = false
var cargo = {}

signal colony_picked

var rank = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	# randomizing is done here and not in debris because planet-spawned debris has the module pre-selected
	deb_chances.append(["engine", 50])
	deb_chances.append(["shields", 30])
	deb_chances.append(["power", 20])

# TODO: those are used at least in 3 spots (here and in asteroids and in proc star system, unify?
func get_chance_roll_table(chances, pad=false):
	var num = -1
	var chance_roll = []
	for chance in chances:
		#print(chance)
		var old_num = num + 1
		num += 1 + chance[1]
		# clip top number to 100
		if num > 100:
			num = 100
		chance_roll.append([chance[0], old_num, num])

	if pad:
		# pad out to 100
		print("Last number is " + str(num))
		# print "Last number is " + str(num)
		chance_roll.append(["None", num, 100])

	return chance_roll

# wants a table of chances [[name, low, upper]]
func random_choice_table(table):
	var roll = randi() % 101 # between 0 and 100
	print("Roll: " + str(roll))
	
	for row in table:
		if roll >= row[1] and roll <= row[2]:
			print("Random roll picked: " + str(row[0]))
			return row[0]

# random select from a table
func select_random_debris():
	var chance_roll_table = get_chance_roll_table(deb_chances)
	print(chance_roll_table)
	
	var res = random_choice_table(chance_roll_table)
	print("Debris res: " + str(res))
	return res
	
# ----------------------

func _on_shield_recharge_timer_timeout():
	# no recharging if landing
	if "landed" in self:
		if self.landed:
			print("We're landed, no recharging")
			return
	
	# draw the entirety of the power if shields are low
	if shields < 30 and power - shield_power_draw > 0:
		shields = shields + shield_recharge
		emit_signal("shield_changed", [shields, false])
		if self == game.player:
			# draw some power
			power = power - shield_power_draw
			emit_signal("power_changed", power)
	
	# if shields are good, don't drain the power recharging them
	var keep = power - shield_power_draw
	if "shoot_power_draw" in self:
		keep = power - shield_power_draw - self.shoot_power_draw
	if shields >= 30 and shields < 100 and keep > 5:
		shields = shields + shield_recharge
		emit_signal("shield_changed", [shields, false])
		if self == game.player:
			# draw some power
			power = power - shield_power_draw
			emit_signal("power_changed", power)
		
	get_node("shield_recharge_timer").start()
	#get_node("recharge_timer").start()

func orbit_planet(planet):
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)

	var _rel_pos = planet.get_node("orbit_holder").get_global_transform().xform_inv(get_global_position())
	var _dist = planet.get_global_position().distance_to(get_global_position())
#	print("Dist: " + str(dist))
#	print("Relative to planet: " + str(rel_pos) + " dist " + str(rel_pos.length()))
	
	planet.emit_signal("planet_orbited", self)			
	# reparent
	get_parent().get_parent().remove_child(get_parent())
	planet.get_node("orbit_holder").add_child(get_parent())
#	print("Reparented")
			
	orbiting = planet.get_node("orbit_holder")
			
	# placement is handled by the planet in the signal

func deorbit_reparent(root, gl):
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())
	
	orbiting = null
	
func deorbit():
	# paranoia
	if not orbiting:
		return 
		
	var _rel_pos = orbiting.get_parent().get_global_transform().xform_inv(get_global_position())
	#print("Deorbiting, relative to planet " + str(rel_pos) + " " + str(rel_pos.length()))
	
	orbiting.get_parent().emit_signal("planet_deorbited", self)
			
	#print("Deorbiting, " + str(get_global_position()) + str(get_parent().get_global_position()))
			
	# reparent
	# defer to avoid occasional "can't change state while flushing queries" error
	
	var root = get_node("/root/Control")
	var gl = get_global_position()
	
	call_deferred("deorbit_reparent", root, gl)


func is_overheating():
	var star = get_tree().get_nodes_in_group("star")[0]
	# paranoia
	if not 'star_radius_factor' in star:
		return false
	var dist = star.get_global_position().distance_to(get_global_position())
	# star textures are 1024x1024, and the star takes up roughly half of that
	# so 500-ish means we're on top of the graphic
	if dist < 550* star.star_radius_factor and not warping:
		return true
	else:
		return false

func close_to_sun():
	var star = get_tree().get_nodes_in_group("star")[0]
	# paranoia
	if not 'star_radius_factor' in star:
		return false
		
	var dist = star.get_global_position().distance_to(get_global_position())
	# some margin compared to is_overheating to have time to react
	if dist < 650* star.star_radius_factor and not warping:
		return true
	else:
		return false
		
func can_scoop():
	var star = get_tree().get_nodes_in_group("star")[0]
	# paranoia
	if not 'star_radius_factor' in star:
		return false
	
	var dist = star.get_global_position().distance_to(get_global_position())
	# some margin compared to is_overheating
	# fuel scoop scoops up plasma from the corona, which extends to roughly 11 solar radii out
	# but the further out, the thinner the plasma, the more wispy (at some point it becomes solar wind)
	# this is only around 2 visible radii out but remember that the visual distances aren't exactly to scale
	if dist < 750* star.star_radius_factor and not warping:
		return true
	else:
		return false	

# this is the color of plasma our engine emits
# as a nod to realism, low speed engines are ion (xenon) - the typical blue
# and high speed engines are fusion/plasma (hydrogen) - i.e. pink
func get_engine_exhaust_color():
	if spd < 0.1:
		return Color(0,1,1) # cyan
	else:
		return Color(1,0.35,1) # light pink

# ----------------------
func get_friendly_bases():
	var bases = get_tree().get_nodes_in_group("starbase")
	
	var friendly_bases = []
	if is_in_group("friendly") or get_parent().is_in_group("player"):
		for b in bases:
			if not b.is_in_group("enemy") and not b.is_in_group("pirate"):
				friendly_bases.append(b)
	elif is_in_group("enemy"):
		for b in bases:
			#print(b.get_name())
			if b.is_in_group("enemy"):
				#print(b.get_name() + " is enemy")
				friendly_bases.append(b)
	elif is_in_group("pirate"):
		for b in bases:
			if b.is_in_group("pirate"):
				friendly_bases.append(b)

	return friendly_bases
	
func get_friendly_base():
	#var bases = get_tree().get_nodes_in_group("starbase")
	
	var friendly_bases = get_friendly_bases()
	#print("Friendly bases: ", friendly_bases)
	
	if friendly_bases.size() < 2:
		if friendly_bases.size() == 0:
			return
			
		return friendly_bases[0]
	else:
		# sort by dist
		var dists = []
		var targs = []
	
		for t in friendly_bases:
			var dist = t.get_global_position().distance_to(get_global_position())
			dists.append(dist)
			targs.append([dist, t])
	
		dists.sort()
		#print("Dists sorted: " + str(dists))
		#print("Targets: " + str(targs))
		
		for t in targs:
			if t[0] == dists[0]:
				#print("Target is : " + t[1].get_parent().get_name())
				
				return t[1]
	
#	if is_in_group("friendly") or get_parent().is_in_group("player"):	
#	#	print(str(bases))
#		for b in bases:
#			#print(b.get_name())
#			if not b.is_in_group("enemy"):
#				#print(b.get_name() + " is not enemy")
#				return b
#	elif is_in_group("enemy"):
#		for b in bases:
#			#print(b.get_name())
#			if b.is_in_group("enemy"):
#				#print(b.get_name() + " is enemy")
#				return b
#	elif is_in_group("pirate"):
#		for b in bases:
#			if b.is_in_group("pirate"):
#				return b

func get_enemy_bases():
	var bases = get_tree().get_nodes_in_group("starbase")
	
	var enemy_bases = []
	if is_in_group("friendly") or get_parent().is_in_group("player"):
		for b in bases:
			if b.is_in_group("enemy") or b.is_in_group("pirate"):
				enemy_bases.append(b)
	elif is_in_group("enemy"):
		for b in bases:
			#print(b.get_name())
			if b.is_in_group("friendly"):
				#print(b.get_name() + " is enemy")
				enemy_bases.append(b)
	elif is_in_group("pirate"):
		for b in bases:
			if b.is_in_group("friendly"):
				enemy_bases.append(b)

	return enemy_bases
	
func get_enemy_base():
	#var bases = get_tree().get_nodes_in_group("starbase")
	
	var enemy_bases = get_enemy_bases()
	#print("Enemy bases: ", enemy_bases)
	
	if enemy_bases.size() < 2:
		if enemy_bases.size() == 0:
			return
			
		return enemy_bases[0]
	else:
		# sort by dist
		var dists = []
		var targs = []
	
		for t in enemy_bases:
			var dist = t.get_global_position().distance_to(get_global_position())
			dists.append(dist)
			targs.append([dist, t])
	
		dists.sort()
		#print("Dists sorted: " + str(dists))
		#print("Targets: " + str(targs))
		
		for t in targs:
			if t[0] == dists[0]:
				#print("Target is : " + t[1].get_parent().get_name())
				
				return t[1]

# we need to filter out drones
func get_friendlies():
	var nodes = get_tree().get_nodes_in_group("friendly")
		
	# more foolproof removing
	var to_rem = []
	for n in nodes:
		if n.is_in_group("drone"):
			to_rem.append(n)
			#nodes.remove(nodes.find(n))
	
	for r in to_rem:
		nodes.remove(nodes.find(r))
		
	return nodes

func get_enemies():
	var nodes = []

	if is_in_group("enemy"):
		nodes = get_friendlies()
#		nodes = get_tree().get_nodes_in_group("friendly")
#
#		# more foolproof removing
#		var to_rem = []
#		for n in nodes:
#			if n.is_in_group("drone"):
#				to_rem.append(n)
#				#nodes.remove(nodes.find(n))
#
#		for r in to_rem:
#			nodes.remove(nodes.find(r))
		
		var player = get_tree().get_nodes_in_group("player")[0].get_child(0)
		if not player.cloaked and not player.dead:
			# add player
			nodes.append(player)
	else:	
		nodes = get_tree().get_nodes_in_group("enemy")
		
	return nodes

func get_closest_enemy():
	var nodes = get_enemies()
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			#print("Target is : " + t[1].get_parent().get_name())
			
			return t[1]

func get_closest_friendly():
	var nodes = []
	if is_in_group("enemy"):
		nodes = get_tree().get_nodes_in_group("enemy")
	else:	
		#nodes = get_tree().get_nodes_in_group("friendly")
		nodes = get_friendlies()
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			#print("Target is : " + t[1].get_parent().get_name())
			
			return t[1]

func get_enemies_in_range(rad=300):
	var nodes = get_enemies()
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])
	
	# remove those who are far away
	var to_rem = []
	for t in targs:
		# for comparison, most planets are 300 px across
		# and AI shoot range is 150
		if t[0] > rad: 
			to_rem.append(t[1]) 
		
	for r in to_rem:
		nodes.remove(nodes.find(r))
		
	return nodes
	
func get_friendlies_in_range():
	var nodes = get_friendlies()
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])
	
	# remove those who are far away
	var to_rem = []
	for t in targs:
		# for comparison, most planets are 300 px across
		# and AI shoot range is 150
		if t[0] > 300: 
			to_rem.append(t[1]) 
		
	for r in to_rem:
		nodes.remove(nodes.find(r))
		
	return nodes

func is_enemy_a_starbase(enemies):
	var ret = false
	for e in enemies:
		if e.is_in_group("starbase"):
			ret = true
			break

	return ret

func get_closest_asteroid():
	var nodes = get_tree().get_nodes_in_group("asteroid")
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			#print("Target is : " + t[1].get_parent().get_name())
			
			return t[1]

# ------------------------------------
func get_closest_floating_colony():
	var colonies = []
	var nodes = []
	colonies = get_tree().get_nodes_in_group("colony")
	# exlude those colonies that are tractored
	for c in colonies:
		#if not c.get_child(0).tractor and not c.get_parent().is_in_group("friendly") and not c.get_parent().is_in_group("planets") and not c.get_parent().get_parent().is_in_group("player"):
		if c.get_child(0).is_floating():
			nodes.append(c)
			
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			#print("Target colony is : " + t[1].get_name())
			
			return t[1]

func is_target_floating_colony(target):
	var ret = false
	# if we have a floating colony
	if get_closest_floating_colony() != null:
		# check if ship target and floating colony position are roughly the same
		if target.distance_to(get_closest_floating_colony().get_global_position()) < 20:
			#print("Ship target is floating colony")
			ret = true
	return ret

func get_colony_in_dock():
	var last = get_child(get_child_count()-1)
	if last.is_in_group("colony"):
		#print("We have a colony in dock")
		return last
	else:
		return null

func send_pop_from_planet(planet):
	# if planet has too few pop to begin with
	if planet.population < 51/1000.0:
		planet.update_HUD_colony_pop(planet, false)
		return null

	# check for resources (sulfur? lunarcrete?)
	# amount eyeballed
	if not "SULFUR" in planet.storage or planet.storage["SULFUR"] < 5:
		return null

	var pop = 1.0

	# decrease planet pop
	# if more than 4B, pick up 1B at a time for ease of playing
	if planet.population > 4000.0:
		pop = 1000.0
	elif planet.population > 51/1000.0: # don't bring it to 0K!
		pop = 50/1000.0
		
	# update planet and HUD
	planet.population -= pop
	if planet.population < 51/1000.0:
		#print("Should update HUD for planet: " + str(planet.get_node("Label").get_text()))
		planet.update_HUD_colony_pop(planet, false)
		
	return pop

func pick_colony():
	# paranoia
	if not orbiting:
		return
	
	var pl = orbiting.get_parent()
	print("Orbiting planet: " + pl.get_name())
	
	var pop = send_pop_from_planet(pl)
	
	if pop != null:
		print("Creating colony...")
		# create colony
		var co = colony.instance()
		add_child(co)
		# actual colony node
		var col = co.get_child(0)
		# set its pop
		col.population = pop
		# formatting
		var format_pop = "%.2fK" % (col.population * 1000)
		if col.population >= 1.0:
			format_pop = "%.2fM" % (col.population)
		if col.population >= 1000.0:
			format_pop = "%.2fB" % (col.population/1000.0)
		# show pop label
		col.get_node("Label").set_text(str(format_pop))
		
		# place colony in dock
		co.set_position(get_node("dock").get_position())
		# don't overlap
		co.set_z_index(-1)
		# emit signal
		emit_signal("colony_picked", co)
		# connect signals
		# "colony" is a group of the parent of colony itself
		co.get_child(0).connect("colony_colonized", game.player.HUD, "_on_colony_colonized")
		return true
	else:
		return false

func add_to_colony():
	var pl = orbiting.get_parent()
	print("Orbiting planet: " + pl.get_name())
	
	var pop = send_pop_from_planet(pl)
	
	if pop != null:
		var col = get_colony_in_dock().get_child(0)
		#print("Adding " + str(pop) + " to colony of " + str(col.population))
		# set its pop
		col.population = col.population + pop
		# formatting
		var format_pop = "%.2fK" % (col.population * 1000)
		if col.population >= 1.0:
			format_pop = "%.2fM" % (col.population)
		if col.population >= 1000.0:
			format_pop = "%.2fB" % (col.population/1000.0)
		# show pop label
		col.get_node("Label").set_text(str(format_pop))
		return true
	else:
		return false
