extends "boid.gd"

# Declare member variables here. Examples:
var ship
# FSM
onready var state = InitialState.new(self)
var prev_state

const STATE_INITIAL = 0
const STATE_IDLE   = 1
const STATE_ORBIT  = 2
const STATE_ATTACK = 3
const STATE_REFIT = 4
const STATE_COLONIZE = 5 
const STATE_MINE = 6 # not in original Stellar Frontier

signal state_changed

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func select_target():
	#target 
	#planet #1
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		if ship.kind_id == ship.kind.friendly and ship.get_colonized_planet() != null:
			target = ship.get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT)
			#target_type = "COLONY_PLANET"
		else:
			target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
			set_state(STATE_IDLE)
	else:
		if ship.kind_id == ship.kind.friendly:
			target = ship.get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT)
		else:
			target = get_tree().get_nodes_in_group("planets")[2].get_global_position()
			set_state(STATE_IDLE)

func move_generic(delta):
	# steering behavior
	var steer = get_steering_arrive(target)	
	# normal case
	vel += steer
	
	ship.move_AI(vel, delta)


# using this because we don't need physics
# generic
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# calculate speed in fraction of c
	ship.spd = ship.vel.length() / ship.LIGHT_SPEED

	# use states
	state.update(delta)



# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	prev_state = get_state()
	
	if new_state == STATE_INITIAL:
		state = InitialState.new(self)
	elif new_state == STATE_IDLE:
		state = IdleState.new(self)
	elif new_state == STATE_ORBIT:
		state = OrbitState.new(self)
	elif new_state == STATE_MINE:
		state = MineState.new(self)
	elif new_state == STATE_ATTACK:
		state = AttackState.new(self, param)
	elif new_state == STATE_REFIT:
		state = RefitState.new(self, param)
	elif new_state == STATE_COLONIZE:
		state = ColonizeState.new(self)
	
	emit_signal("state_changed", self)
	
	#print(get_name() + " setting state to " + str(new_state))

func get_state():
	if state is InitialState:
		return STATE_INITIAL
	elif state is IdleState:
		return STATE_IDLE
	elif state is OrbitState:
		return STATE_ORBIT
	elif state is MineState:
		return STATE_MINE
	elif state is AttackState:
		return STATE_ATTACK
	elif state is RefitState:
		return STATE_REFIT
	elif state is ColonizeState:
		return STATE_COLONIZE


# -----------------------------
# states
class InitialState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		if not ship.target:
			ship.select_target()
	

		ship.rel_pos = ship.get_global_transform().xform_inv(ship.target)
		#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))	
		
		#ship.set_state(STATE_IDLE)
		
		
class IdleState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.move_generic(delta)
		

class OrbitState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.ship.move_orbit(delta)

class AttackState:
	var ship
	var target
	
	func _init(shp, tg):
		ship = shp
		target = tg
	
	func update(delta):
		# steering behavior
		var steer = ship.set_heading(ship.target)	
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy != null and enemy == target:
			ship.ship.shoot_wrapper()
		else:
			ship.set_state(ship.prev_state)
			
class RefitState:
	var ship
	var base
	
	func _init(shp, sb):
		ship = shp
		base = sb
	
	func update(delta):
		ship.move_generic(delta)
		
		# if close, do tractor effect
		if ship.get_global_position().distance_to(ship.target) < 50 and not ship.ship.docked:
			print("Should be tractoring")
			ship.ship.refit_tractor(base)
			# dummy
			ship.target = ship.get_global_position()

class ColonizeState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		# default
		var id = 1
		# conquer target given by the player
		if ship.get_tree().get_nodes_in_group("player")[0].get_child(0).conquer_target != null:
			id = ship.get_tree().get_nodes_in_group("player")[0].get_child(0).conquer_target
		
		# refresh target position
		ship.target = ship.get_tree().get_nodes_in_group("planets")[id].get_global_position()
		# steering behavior
		var steer = ship.get_steering_seek(ship.target)	
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		if ship.get_global_position().distance_to(ship.target) < 50:
			if ship.ship.get_colony_in_dock() == null:
				ship.target = ship.ship.get_colonized_planet().get_global_position()
				ship.set_state(ship.STATE_ORBIT)


# completely original	
class MineState:
	var ship
	var shot = false
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.move_generic(delta)
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy:
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 100:
				print("We are close to an enemy, switching")
				#ship.target = enemy.get_global_position()
				ship.set_state(STATE_ATTACK, enemy)

		
		# if close to target, shoot it
		if ship.get_global_position().distance_to(ship.target) < 10 and not shot:
			print("Close to target")
			ship.ship.shoot_wrapper()
			
			var ress = ship.get_tree().get_nodes_in_group("resource")
			if ress.size() > 0:
				shot = true
				ship.target = ress[0].get_global_position()
				
				