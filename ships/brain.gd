extends "boid.gd"

# Declare member variables here. Examples:
var ship
# FSM
onready var state = InitialState.new(self)
onready var curr_state = 0 # debugging helper to see in-editor
var prev_state

const STATE_INITIAL = 0
const STATE_IDLE   = 1
const STATE_ORBIT  = 2
const STATE_ATTACK = 3
const STATE_REFIT = 4
const STATE_COLONIZE = 5 
const STATE_GO_PLANET = 6
const STATE_MINE = 7 # not in original Stellar Frontier

signal state_changed

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# is run as part of initial setup
func select_target():
	#target 
	#planet #1
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		if ship.get_colonized_planet() != null:
		#if ship.kind_id == ship.kind.friendly and ship.get_colonized_planet() != null:
			#target = ship.get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT, ship.get_colonized_planet())
			print("Set orbit state for " + ship.get_parent().get_name())
		else:
			target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
			set_state(STATE_IDLE)
	else:
		if ship.kind_id == ship.kind.friendly:
			#target = ship.get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT, ship.get_colonized_planet())
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

# ------------------------------------------------------------------
func _colonize(conquer_tg):
	var col_id = ship.get_colonize_target()
	if col_id != null or conquer_tg != null:
		if conquer_tg != null:
			col_id = conquer_tg
		print("Colonize target " + str(col_id))
		set_state(STATE_COLONIZE, col_id)
		# col_id is the real id+1 to avoid problems with state param being 0 (= null)
		var col_tg = get_tree().get_nodes_in_group("planets")[col_id-1]
		target = col_tg.get_global_position()
		print("We have a colony, leaving for... " + str(col_tg.get_node("Label").get_text()))
		return true
	else:
		return false
		
func _go_mine():
	var closest = ship.get_closest_asteroid()
	if closest:
		target = closest.get_global_position()
		set_state(STATE_MINE, closest)
		return true
	else:
		return false

func task_orbiting(conquer_tg):
	# if player-specified colony target is not colonized
	# or we have a colonize target (planet w/o colony)
	if conquer_tg != null or ship.get_colonize_target() != null:
		if ship.get_colony_in_dock() == null:
			if ship.kind_id == ship.kind.friendly:
				# pick up colony from planet
				if not ship.pick_colony():
					print("We can't pick colony now, go do something else...")
					ship.deorbit()
					var try_mine = _go_mine()
					if not try_mine:
						#if get_colonized_planet().has_moon():
							# random chance to head for a moon
							#randomize()
							#if randi() % 20 > 10:
							#	brain.target = get_colonized_planet().get_moon().get_global_position()
							#else:
							
						# orbit again
						set_state(STATE_ORBIT, ship.get_colonized_planet())
				else:
					# explicitly go colonize
					_colonize(conquer_tg)
			else:
				print("Blockading a planet")
		else:
			# deorbit
			ship.deorbit()		
			_colonize(conquer_tg)

	# if nowhere to colonize
	else:
		var try_mine = _go_mine()
		if try_mine:
			ship.deorbit()
		#_go_mine()

# timer count is governed by ship
func _on_task_timer_timeout(timer_count):
	var conquer_tg = get_tree().get_nodes_in_group("player")[0].get_child(0).conquer_target 
	if ship.orbiting:
		task_orbiting(conquer_tg)

	else:
		# if we somehow picked up a colony and aren't colonizing, offload it first
		if ship.get_colony_in_dock() != null and not (get_state() == STATE_COLONIZE):
			var try_col = _colonize(conquer_tg)
			# nothing more to colonize, go back to colonized planet
			if not try_col: 
				set_state(STATE_GO_PLANET, ship.get_colonized_planet())
			
		if not (get_state() in [STATE_MINE, STATE_REFIT, STATE_COLONIZE, STATE_ATTACK, STATE_GO_PLANET]):
			_go_mine()

		if not (get_state() == STATE_ATTACK) and not ship.docked:
			if ship.get_colony_in_dock() == null:
				if ship.kind_id == ship.kind.friendly:
					#print("We're friendlies without a colony in dock")
					# find closest colony
					var close_col = ship.get_closest_floating_colony()
					if close_col != null:
						var dist = (close_col.get_global_position() - ship.get_global_position()).length()
						print("We have a floating colony @ dist: " + str(dist))
						if dist < 500:
							target = close_col.get_global_position()
							set_state(STATE_IDLE)
							print("Floating colony close by")
					
		if get_state() == STATE_REFIT:
			if not ship.docked:
				return
			else:
				_go_mine()
#				if get_tree().get_nodes_in_group("asteroid").size() > 3:
#					brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
#					brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])


		if get_state() == STATE_MINE:
			# if task timeout happened and we're still mining, quit it
			if timer_count > 4:
				# ignore if we're far from target
				var dist = get_global_position().distance_to(target)
				if dist > 150:
					# ignore
					pass
				else:
					print("We got stuck mining @ dist: " + str(dist))
					# assume we got bored, look for something else to do../
					
					# do we have something to colonize?
					# if player-specified colony target is not colonized
					# or we have a colonize target (planet w/o colony)
					if conquer_tg or ship.get_colonize_target() != null: 
						if ship.get_colony_in_dock() == null:
							if ship.kind_id == ship.kind.friendly:
								if ship.get_colonized_planet().get_global_position().distance_to(ship.get_global_position()) > 500:
									#brain.target = get_colonized_planet().get_global_position() + Vector2(200,200) * get_colonized_planet().planet_rad_factor
									set_state(STATE_GO_PLANET, ship.get_colonized_planet())
					else:
						# add offset to target to "unstick" ourselves
						target = target + Vector2(50,50)
						set_state(STATE_IDLE)
					


# ------------------------------------------------------------------
# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	
	if get_state() in [STATE_MINE, STATE_ATTACK, STATE_REFIT, STATE_ORBIT, STATE_COLONIZE, STATE_GO_PLANET]:
		prev_state = [ get_state(), state.param ]
	else:
		prev_state = [ get_state(), null ]
	
	# paranoia
	if (new_state in [STATE_MINE, STATE_ATTACK, STATE_REFIT, STATE_ORBIT, STATE_COLONIZE, STATE_GO_PLANET] and param == null):
		print("We forgot a parameter for the state " + str(new_state))
	
	# set the debugging helper var
	curr_state = new_state
	
	if new_state == STATE_INITIAL:
		state = InitialState.new(self)
	elif new_state == STATE_IDLE:
		state = IdleState.new(self)
	elif new_state == STATE_ORBIT:
		state = OrbitState.new(self, param)
	elif new_state == STATE_MINE:
		state = MineState.new(self, param)
	elif new_state == STATE_ATTACK:
		state = AttackState.new(self, param)
	elif new_state == STATE_REFIT:
		state = RefitState.new(self, param)
	elif new_state == STATE_COLONIZE:
		state = ColonizeState.new(self, param)
	elif new_state == STATE_GO_PLANET:
		state = PlanetState.new(self, param)
	
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
	elif state is PlanetState:
		return STATE_GO_PLANET

func get_state_obj():
	return state


# -----------------------------
# states
class InitialState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(_delta):
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
		# deorbit
		if ship.ship.orbiting:
			ship.ship.deorbit()
		
		ship.move_generic(delta)
		
		# if we're on top of our target
		var t_dist = ship.get_global_position().distance_to(ship.target)
		if t_dist < 20:
			# tractor
			if not ship.ship.tractor:
				# if we have a floating colony
				if ship.ship.get_closest_floating_colony() != null:
					# check if ship target and floating colony position are roughly the same
					if ship.target.distance_to(ship.ship.get_closest_floating_colony().get_global_position()) < 20:
						print("Ship target is floating colony")
						ship.ship.tractor = ship.ship.get_closest_floating_colony()
						# mark the target as tractored
						ship.ship.tractor.get_child(0).tractor = ship.ship
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy and (not 'warping' in enemy or not enemy.warping): #starbases don't have warp/Q-drive capability
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 150:
				print("We are close to an enemy " + str(enemy.get_parent().get_name()) + " switching")
				ship.set_state(STATE_ATTACK, enemy)
				# signal player being attacked if it's the case
				if enemy.get_parent().is_in_group("player"):
					enemy.targeted_by.append(ship.ship)
					ship.ship.emit_signal("target_acquired_AI", ship.ship)
					print("AI ship acquired target")
		

class OrbitState:
	var ship
	var param # for previous state
	
	func _init(shp, planet):
		ship = shp
		param = planet
		
	func update(delta):
		# update target location
		ship.target = param.get_global_position()
		
		ship.ship.move_orbit(delta)

class AttackState:
	var ship
	var param # for previous state
	var target
	
	func _init(shp, tg):
		ship = shp
		param = tg
		target = tg
	
	func update(delta):
		# deorbit
		if ship.ship.orbiting:
			ship.ship.deorbit()
		
		
		var steer = Vector2(0,0)
		# if no target, bail out
		if target == null:
			print("No target?!")
			# this way, we also pass the parameters
			ship.set_state(ship.prev_state[0], ship.prev_state[1])
			print("Set state to: " + str(ship.get_state()))
			return
		
		if is_instance_valid(target):
			# steering behavior
			steer = ship.set_heading(target.get_global_position())
		# if target was killed, bail out immediately
		else:
			#print("Prev state: " + str(ship.prev_state))
			# this way, we also pass the parameters
			ship.set_state(ship.prev_state[0], ship.prev_state[1])
			#print("Set state to: " + str(ship.get_state()))
			return
			
		# normal case
		ship.vel += steer
		
		ship.ship.move_AI(ship.vel, delta)
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy != null and enemy == target:
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 150:
				#print("Shooting" + str(enemy.get_parent().get_name()))
				ship.ship.shoot_wrapper()
			# don't attack if enemy is too far
			else:
				ship.set_state(ship.prev_state[0], ship.prev_state[1])
				#print("Set state to: " + str(ship.get_state()))
				return
		else:
			# this way, we also pass the parameters
			#print("Prev state: " + str(ship.prev_state))
			ship.set_state(ship.prev_state[0], ship.prev_state[1])
			#print("Set state to: " + str(ship.get_state()))
			return
			
class RefitState:
	var ship
	var param # for previous state
	var base
	
	func _init(shp, sb):
		ship = shp
		param = sb
		base = sb
	
	func update(delta):
		ship.move_generic(delta)
		
		# if close, do tractor effect
		if ship.get_global_position().distance_to(ship.target) < 50 and not ship.ship.docked:
			#print("Should be tractoring")
			ship.ship.refit_tractor(base)
			# dummy
			ship.target = ship.get_global_position()
		# sell cargo
		if ship.ship.docked:
			# prevent crash if nothing in cargo
			if ship.ship.cargo.size() < 1:
				return
			if ship.ship.cargo[ship.ship.cargo.keys()[0]] > 0:
				ship.ship.cargo[ship.ship.cargo.keys()[0]] -= 1
		
				# add cargo to starbase
				if not ship.ship.get_parent().get_parent().storage.has(ship.ship.cargo.keys()[0]):
					ship.ship.get_parent().get_parent().storage[ship.ship.cargo.keys()[0]] = 1
				else:
					ship.ship.get_parent().get_parent().storage[ship.ship.cargo.keys()[0]] += 1
			
			# start timer
			# task timer allows the AI to leave after some time passed
			#ship.ship.task_timer.start()

class ColonizeState:
	var ship
	var param # for previous state
	var planet_
	
	func _init(shp, planet):
		ship = shp
		param = planet
		planet_ = planet
		
	func update(delta):
		var id = 1
		if not planet_:
			print("No param given for colonize state")
			# default
			#id = 1
			id = ship.ship.get_colonize_target()
			# conquer target given by the player
			var conquer_target = ship.get_tree().get_nodes_in_group("player")[0].get_child(0).conquer_target
			if conquer_target != null:
				#print("[Brain] Conquer target " + str(conquer_target))
				id = conquer_target
		else:
			#print("Setting id to target " + str(param))
			id = planet_
		
		# did we lose the id somehow?
		if id == null:
			print("We want to orbit colonized planet")
			ship.set_state(STATE_GO_PLANET, ship.ship.get_colonized_planet())
			return
			
		# refresh target position
		# id is the real id+1 to avoid problems with state param being 0 (= null)
		ship.target = ship.get_tree().get_nodes_in_group("planets")[id-1].get_global_position()
		#print("ID" + str(id) + " tg: " + str(ship.target))
		# steering behavior
		var steer = ship.get_steering_seek(ship.target)	
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		# we somehow lost the colony?
		if ship.ship.get_colony_in_dock() == null:
			print("We want to orbit colonized planet")
#			if ship.ship.get_colonized_planet().get_global_position().distance_to(ship.get_global_position()) > 500:
#				ship.target = ship.ship.get_colonized_planet().get_global_position()
#				ship.set_state(STATE_ORBIT, ship.ship.get_colonized_planet())
#			else:
			#ship.target = ship.ship.get_colonized_planet().get_global_position() + Vector2(200,200) * ship.ship.get_colonized_planet().planet_rad_factor
			ship.set_state(STATE_GO_PLANET, ship.ship.get_colonized_planet())
		
		if ship.get_global_position().distance_to(ship.target) < 50:
			if ship.ship.get_colony_in_dock() == null:
				print("We colonized it, want to orbit colonized planet")
#				if ship.ship.get_colonized_planet().get_global_position().distance_to(ship.get_global_position()) > 500:
#					ship.target = ship.ship.get_colonized_planet().get_global_position()
#					ship.set_state(STATE_ORBIT, ship.ship.get_colonized_planet())
#				else:
				#ship.target = ship.ship.get_colonized_planet().get_global_position() + Vector2(200,200) * ship.ship.get_colonized_planet().planet_rad_factor
				ship.set_state(STATE_GO_PLANET, ship.ship.get_colonized_planet())


class PlanetState:
	var ship
	var param # for previous state
	var id
	
	func _init(shp, planet):
		ship = shp
		param = planet
		
		var planets = ship.get_tree().get_nodes_in_group("planets")
		id = planets.find(planet)
		
	func update(delta):
		# refresh target position
		ship.target = ship.get_tree().get_nodes_in_group("planets")[id].get_global_position()
		#print("ID" + str(id) + " tg: " + str(ship.target))
		# steering behavior
		var steer = ship.get_steering_seek(ship.target)	
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		# if close, orbit
		# 300 is experimentally picked
		var rad_f = param.planet_rad_factor
		if (ship.target - ship.get_global_position()).length() < 300*rad_f:
			ship.set_state(STATE_ORBIT, param)

# completely original	
class MineState:
	var ship
	var shot = false
	var param # for previous state
	var object
	var cnt = 0
	var target_num = 0
	
	func _init(shp,obj):
		ship = shp
		object = obj
		param = obj
		cnt = 0
		target_num = 2
		
		# reset ship's timer count
		ship.ship.timer_count = 0
		
	func update(delta):
		var steer = Vector2(0,0)
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy:
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 100:
				print("We are close to an enemy, switching")
				#ship.target = enemy.get_global_position()
				ship.set_state(STATE_ATTACK, enemy)

		# aim towards the target
		if ship.get_global_position().distance_to(ship.target) < 100:
			if object == null and not shot:
				print("Bug, object shouldn't be null!")
				ship.set_state(STATE_IDLE)
			elif shot:
				# do nothing
				pass
			else:
				# update target location
				ship.target = object.get_global_position()
			
			#print("Heading towards " + str(ship.target))
			# steering behavior
			steer = ship.set_heading(ship.target)
			#if ship.get_global_position().distance_to(ship.target) > 50:
			steer += ship.get_steering_arrive(ship.target)
		else:
			steer = ship.get_steering_arrive(ship.target)
			
		# normal case
		ship.vel += steer
		
		ship.ship.move_AI(ship.vel, delta)
			
		# if close to target, shoot it
		if ship.get_global_position().distance_to(ship.target) < 80 and not shot:
			#print("Close to target")
			ship.ship.shoot_wrapper()
			
		var ress = ship.get_tree().get_nodes_in_group("resource")
		if ress.size() > 0 and ress[0].get_global_position().distance_to(ship.get_global_position()) < 200:
			if not shot:
				shot = true
			ship.target = ress[0].get_global_position()
		else:
			# if shot and no resource (e.g. because someone else picked it up)
			if shot:
				print("Someone picked our resource")
				# reset
				shot = false
				# force update target location
				ship.target = object.get_global_position()
#
				
		# NPC ship resource_picked handles the switch to refit
