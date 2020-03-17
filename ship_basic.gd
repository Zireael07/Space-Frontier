extends Area2D

# Declare member variables here. Examples:
const LIGHT_SPEED = 400 # original Stellar Frontier seems to have used 200 px/s

export var rot_speed = 2.6 #radians
export var thrust = 0.25 * LIGHT_SPEED
export var max_vel = 0.5 * LIGHT_SPEED
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


func orbit_planet(planet):
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
				
	#var rel_pos = get_global_transform().xform_inv(pl[1].get_global_position())
	var rel_pos = planet.get_node("orbit_holder").get_global_transform().xform_inv(get_global_position())
	var dist = planet.get_global_position().distance_to(get_global_position())
#	print("Dist: " + str(dist))
#	print("Relative to planet: " + str(rel_pos) + " dist " + str(rel_pos.length()))
	
	planet.emit_signal("planet_orbited", self)			
	# reparent
	get_parent().get_parent().remove_child(get_parent())
	planet.get_node("orbit_holder").add_child(get_parent())
#	print("Reparented")
			
	orbiting = planet.get_node("orbit_holder")
			
	# placement is handled by the planet in the signal
	
func deorbit():
	var rel_pos = orbiting.get_parent().get_global_transform().xform_inv(get_global_position())
	print("Deorbiting, relative to planet " + str(rel_pos) + " " + str(rel_pos.length()))
	
	# remove from list of planet orbiters
	orbiting.get_parent().remove_orbiter(self)
	
	orbiting = null
			
	print("Deorbiting, " + str(get_global_position()) + str(get_parent().get_global_position()))
			
	# reparent
	var root = get_node("/root/Control")
	var gl = get_global_position()
			
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())
	
func get_friendly_base():
	var bases = get_tree().get_nodes_in_group("starbase")
	
	if is_in_group("friendly") or get_parent().is_in_group("player"):	
	#	print(str(bases))
		for b in bases:
			print(b.get_name())
			if not b.is_in_group("enemy"):
				print(b.get_name() + " is not enemy")
				return b
	elif is_in_group("enemy"):
		for b in bases:
			print(b.get_name())
			if b.is_in_group("enemy"):
				print(b.get_name() + " is enemy")
				return b

func get_closest_enemy():
	var nodes = []
	if is_in_group("enemy"):
		nodes = get_tree().get_nodes_in_group("friendly")
		var player = get_tree().get_nodes_in_group("player")[0].get_child(0)
		if not player.cloaked:
			# add player
			nodes.append(player)
	else:	
		nodes = get_tree().get_nodes_in_group("enemy")
	
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


func get_closest_floating_colony():
	var colonies = []
	var nodes = []
	colonies = get_tree().get_nodes_in_group("colony")
	# exlude those colonies that are tractored
	for c in colonies:
		if not c.get_child(0).tractor and not c.get_parent().is_in_group("friendly") and not c.get_parent().is_in_group("planets") and not c.get_parent().get_parent().is_in_group("player"):
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

func get_colony_in_dock():
	var last = get_child(get_child_count()-1)
	if last.is_in_group("colony"):
		#print("We have a colony in dock")
		return last
	else:
		return null

func pick_colony():
	var pl = orbiting.get_parent()
	print("Orbiting planet: " + pl.get_name())
	# decrease planet pop
	if pl.population > 51/1000.0: # don't bring it to 0K!
		pl.population -= 50/1000.0
		# update planet HUD
		if pl.population < 51/1000.0:
			pl.update_HUD_colony_pop(pl, false)
		
		print("Creating colony...")
		# create colony
		var co = colony.instance()
		add_child(co)
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
