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

var docked = false
var bought = false
var cargo = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


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
	# paranoia
	if not orbiting:
		return 
		
	var rel_pos = orbiting.get_parent().get_global_transform().xform_inv(get_global_position())
	#print("Deorbiting, relative to planet " + str(rel_pos) + " " + str(rel_pos.length()))
	
	orbiting.get_parent().emit_signal("planet_deorbited", self)
	
	# remove from list of a planet's orbiters
	#orbiting.get_parent().remove_orbiter(self)
	
	orbiting = null
			
	#print("Deorbiting, " + str(get_global_position()) + str(get_parent().get_global_position()))
			
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
	
	if is_in_group("friendly"):	
	#	print(str(bases))
		for b in bases:
			#print(b.get_name())
			if not b.is_in_group("enemy"):
				#print(b.get_name() + " is not enemy")
				return b
	elif is_in_group("enemy"):
		for b in bases:
			#print(b.get_name())
			if b.is_in_group("enemy"):
				#print(b.get_name() + " is enemy")
				return b

func simple_dock(refit_target):
	# reparent			
	get_parent().get_parent().remove_child(get_parent())
	# refit target needs to be a node because here
	refit_target.add_child(get_parent())
	# set better z so that we don't overlap parent ship
	set_z_index(-1)
	
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	# drones are far away from starbase
	get_parent().set_position(Vector2(0,100))
	set_position(Vector2(0,0))
	pos = Vector2(0,0)


	docked = true
