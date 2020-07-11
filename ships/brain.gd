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
# not in original Stellar Frontier
const STATE_MINE = 7 
const STATE_LAND = 8

signal state_changed

# human-readable tasks(states)
var tasks = {
	0 : "initializing",
	1 : "idling",
	2 : "orbiting",
	3 : "attacking",
	4 : "refitting",
	5 : "colonizing",
	6 : "heading to a planet",
	7 : "mining",
	8 : "landing on a planet"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# is run as part of initial setup
func select_initial_target():
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		if ship.get_colonized_planet() != null:
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

func handle_enemy():
	# paranoia
	if not ship.has_method("get_closest_enemy"):
		return
	
	var enemy = ship.get_closest_enemy()
	if enemy and (not 'warping' in enemy or not enemy.warping): #starbases don't have warp/Q-drive capability
		var dist = get_global_position().distance_to(enemy.get_global_position())
		#print(str(dist))
		if dist < 150:
			#print("We are close to an enemy " + str(enemy.get_parent().get_name()) + " switching")
			set_state(STATE_ATTACK, enemy)
			# signal player being attacked if it's the case
			if enemy.get_parent().is_in_group("player"):
				enemy.targeted_by.append(ship)
				ship.emit_signal("target_acquired_AI", ship)
				print("AI ship acquired target")


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
# 'src_planet' is just for the officer msg
func _colonize(conquer_tg, src_planet=null):
	var col_id = ship.get_colonize_target()
	if col_id != null or conquer_tg != null:
		if conquer_tg != null:
			col_id = conquer_tg
		#print("Colonize target " + str(col_id))
		set_state(STATE_COLONIZE, col_id)
		# col_id is the real id+1 to avoid problems with state param being 0 (= null)
		var col_tg = get_tree().get_nodes_in_group("planets")[col_id-1]
		target = col_tg.get_global_position()
		#print("We have a colony, leaving for... " + str(col_tg.get_node("Label").get_text()))
		if src_planet != null:
			game.player.emit_signal("officer_message", 
			"Colony departing " + str(src_planet.get_node("Label").get_text()) + " for " + str(col_tg.get_node("Label").get_text()))
		return true
	else:
		return false
		
func _go_mine():
	var closest = ship.get_closest_asteroid()
	if closest:
		# default amount we return at
		var amt = 4
		target = closest.get_global_position()
		# get the base
		var base = ship.get_friendly_base()
		if base != null:
			var dist = target.distance_to(base.get_global_position())
			#print("Dist: " + str(dist))
			amt = int(round(dist/400))
			print("Calculated amount to return at " + str(amt))
			
		# deorbit
		if ship.orbiting:
			ship.deorbit()
			
		set_state(STATE_MINE, [closest, amt, 0])
		return true
	else:
		return false

func task_orbiting(timer_count, conquer_tg):
	# check for enemies orbiting
	#var hostile = null
	if timer_count > 1:
		if ship.kind_id == ship.kind.friendly:
			var hostile = ship.get_colonized_planet().get_hostile_orbiter()
			if hostile:
				# deorbit
				ship.deorbit()
				set_state(STATE_ATTACK, hostile)
		else:
			pass
			
	
	# prevent too short orbiting
	if timer_count > 2:
		# if not drone
		if ship.is_in_group("drone"):
			print("Drone should be deorbiting")
			# deorbit
			ship.deorbit()
			# base
			var base = ship.get_friendly_base()
			target = base.get_global_position()
			set_state(STATE_REFIT, base)
		else:
			# if player-specified colony target is not colonized
			# or we have a colonize target (planet w/o colony)
			if conquer_tg != null or ship.get_colonize_target() != null:
				if ship.get_colony_in_dock() == null:
					if ship.kind_id == ship.kind.friendly:
						# are we of high enough rank to be tasked with colonizing?
						if ship.rank > 0: 
							# pick up colony from planet
							if not ship.pick_colony():
								print("We can't pick colony now, go do something else...")
								var colony_pick = ship.get_planet_colony_available()
								if colony_pick:
									ship.deorbit()
									set_state(STATE_GO_PLANET, colony_pick)
								else:
									var try_mine = _go_mine()
									# moon test
#									#if not try_mine:
#									if ship.get_colonized_planet().has_moon():
#										var moon = ship.get_colonized_planet().get_moons()[0]
#										ship.deorbit()
#										set_state(STATE_GO_PLANET, moon)
											# random chance to head for a moon
											#randomize()
											#if randi() % 20 > 10:
											#	brain.target = get_colonized_planet().get_moon().get_global_position()
											#else:
											
									# orbit again
								#	set_state(STATE_ORBIT, ship.get_colonized_planet())
							else:
								var src_planet = ship.orbiting.get_parent()
								# deorbit
								ship.deorbit()	
								# explicitly go colonize
								_colonize(conquer_tg, src_planet)
						# AI cadet
						else:
							#var try_mine = _go_mine()
							# moon test
							#if not try_mine:
							if ship.get_colonized_planet().has_moon():
								var moon = ship.get_colonized_planet().get_moons()[0]
								ship.deorbit()
								set_state(STATE_GO_PLANET, moon)
									# random chance to head for a moon
									#randomize()
									#if randi() % 20 > 10:
									#	brain.target = get_colonized_planet().get_moon().get_global_position()
									#else:
									
								# orbit again
							#	set_state(STATE_ORBIT, ship.get_colonized_planet())
					
					# if we're an enemy
					else:
						#print("Blockading a planet")
						pass
				else:
					var src_planet = ship.orbiting.get_parent()
					# deorbit
					ship.deorbit()		
					_colonize(conquer_tg, src_planet)
		
			# if nowhere to colonize
			else:
				var try_mine = _go_mine()


# timer count is governed by ship
func _on_task_timer_timeout(timer_count):
	var conquer_tg = get_tree().get_nodes_in_group("player")[0].get_child(0).conquer_target 
	if ship.orbiting:
		task_orbiting(timer_count, conquer_tg)

	else:
		if ship.is_in_group("drone"):
			print("Drone task timeout")
			if get_state() == STATE_REFIT:
				if not ship.docked:
					return
				# if we're docked
				else:
					print("Drone is docked")
					
					if timer_count > 2:
						# go back to planet
						set_state(STATE_GO_PLANET, ship.get_colonized_planet())
						
		else:
			# if we somehow picked up a colony and aren't colonizing, offload it first
			if ship.get_colony_in_dock() != null and not (get_state() == STATE_COLONIZE):
				var try_col = _colonize(conquer_tg, null)
				# nothing more to colonize, go back to colonized planet
				if not try_col: 
					set_state(STATE_GO_PLANET, ship.get_colonized_planet())
				
			if not (get_state() in [STATE_IDLE, STATE_MINE, STATE_REFIT, STATE_COLONIZE, STATE_ATTACK, STATE_GO_PLANET, STATE_ORBIT]):
				_go_mine()
	
			if not (get_state() == STATE_ATTACK) and not ship.docked:
				if ship.get_colony_in_dock() == null:
					if ship.kind_id == ship.kind.friendly:
						#print("We're friendlies without a colony in dock")
						# find closest colony
						var close_col = ship.get_closest_floating_colony()
						if close_col != null:
							var dist = (close_col.get_global_position() - ship.get_global_position()).length()
							#print("We have a floating colony @ dist: " + str(dist))
							if dist < 500:
								target = close_col.get_global_position()
								set_state(STATE_IDLE)
								print("Floating colony close by")
						
			if get_state() == STATE_REFIT:
				if not ship.docked:
					return
				# if we're docked
				else:
					# undock if we regenerated enough shields
					if ship.shields > 75:
						# if player-specified colony target is not colonized
						# or we have a colonize target (planet w/o colony)
						if conquer_tg != null or ship.get_colonize_target() != null:
							if ship.get_colony_in_dock() == null:
								if ship.kind_id == ship.kind.friendly:
									# are we of high enough rank to be tasked with colonizing?
									if ship.rank > 0: 
										print("Going to a planet after refit")
										# go to a planet
										set_state(STATE_GO_PLANET, ship.get_colonized_planet())
									else:
										var try_mine = _go_mine()
										if not try_mine:		
											# go to a planet
											set_state(STATE_GO_PLANET, ship.get_colonized_planet())
						else:			
							var try_mine = _go_mine()
							if not try_mine:		
								# go to a planet
								set_state(STATE_GO_PLANET, ship.get_colonized_planet())
	
	
			if get_state() == STATE_MINE:
				var dist = get_global_position().distance_to(target)
				# ignore timer count if far away
				if dist > 150:
					ship.timer_count = 0
				else:
					# if task timeout happened and we're still mining, quit it
					var tg_count = 4
					if timer_count > tg_count:
						#print("We got stuck mining @ dist: " + str(dist))
						# assume we got bored, look for something else to do../
						
						# do we have something to colonize?
						# if player-specified colony target is not colonized
						# or we have a colonize target (planet w/o colony)
	#					if conquer_tg or ship.get_colonize_target() != null: 
	#						if ship.get_colony_in_dock() == null:
	#							if ship.kind_id == ship.kind.friendly:
	#								if ship.get_colonized_planet().get_global_position().distance_to(ship.get_global_position()) > 500:
	#									#brain.target = get_colonized_planet().get_global_position() + Vector2(200,200) * get_colonized_planet().planet_rad_factor
	#									set_state(STATE_GO_PLANET, ship.get_colonized_planet())
	#
	#					else:
	
						# add offset to target to "unstick" ourselves
						target = target + Vector2(50,50)
						set_state(STATE_IDLE)
			
			if get_state() == STATE_IDLE:
				# if we were mining, keep doing it (and incrementing old counters)
				if prev_state[0] == STATE_MINE:
					if timer_count > 1:
						# this way, we also pass the parameters
						#print("Prev state params: " + str(prev_state[1]))
						set_state(prev_state[0], prev_state[1])
				# if task timeout happened and we're still idling, quit it
				if timer_count > 3:
					# target NOT a floating colony
					if not ship.is_target_floating_colony(target):
						# if we're on top of our target
						if ship.get_global_position().distance_to(target) < 20:
							# go back to a planet
							set_state(STATE_GO_PLANET, ship.get_colonized_planet())
					

func _on_target_killed(target):
	print("State is: " + str(get_state()))
	
	if get_state() == STATE_ATTACK:
		# go back to previous state
		set_state(prev_state[0], prev_state[1])
		
	if get_state() == STATE_IDLE:
		# harass
		set_state(STATE_GO_PLANET, ship.get_colonized_planet())
		
	


# ------------------------------------------------------------------
# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	
	if get_state() in [STATE_ATTACK, STATE_REFIT, STATE_ORBIT, STATE_COLONIZE, STATE_GO_PLANET]:
		prev_state = [ get_state(), state.param ]
	# make sure we remember the correct count
	elif get_state() == STATE_MINE:
		print("Setting prev state for mining, cnt: " + str(state.cnt))
		prev_state = [ get_state(), [state.param[0], state.param[1], state.cnt] ]
	else:
		prev_state = [ get_state(), null ]
	
	# paranoia
	if (new_state in [STATE_MINE, STATE_ATTACK, STATE_REFIT, STATE_ORBIT, STATE_COLONIZE, STATE_GO_PLANET, STATE_LAND] and param == null):
		print("We forgot a parameter for the state " + str(new_state))
	
	# reset ship's timer count
	self.ship.timer_count = 0
	
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
	elif new_state == STATE_LAND:
		state = LandState.new(self, param)
	
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
	elif state is LandState:
		return STATE_LAND

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
			ship.select_initial_target()
	

		ship.rel_pos = ship.get_global_transform().xform_inv(ship.target)
		#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))	
		
		#ship.set_state(STATE_IDLE)
		
		
class IdleState:
	var ship
	
	func _init(shp):
		ship = shp
		
		# reset ship's timer count
		ship.ship.timer_count = 0
		
	func update(delta):
		# deorbit
		if ship.ship.orbiting:
			ship.ship.deorbit()
		
		#ship.move_generic(delta)
		
		# handle floating colonies
		if ship.ship.is_target_floating_colony(ship.target):
			if ship.ship.kind_id == ship.ship.kind.friendly:
				
				ship.move_generic(delta)
				
				# if we're on top of our target
				var t_dist = ship.get_global_position().distance_to(ship.target)
				if t_dist < 20:
					# tractor
					if not ship.ship.tractor: 
						ship.ship.tractor = ship.ship.get_closest_floating_colony()
						# mark the target as tractored
						ship.ship.tractor.get_child(0).tractor = ship.ship
						
			# if enemy AI, shoot it instead
			else:
				# steering behavior
				var steer = ship.get_steering_arrive(ship.target)	
				var t_dist = ship.get_global_position().distance_to(ship.target)
				if t_dist < 150:
					# steering behavior
					steer = ship.set_heading(ship.target)
					ship.ship.shoot_wrapper()
					
				# normal case
				ship.vel += steer
				
				ship.ship.move_AI(ship.vel, delta)
		# if target isn't a colony...
		else:
			ship.move_generic(delta)
		
		# handle enemies
		ship.handle_enemy()
		

class OrbitState:
	var ship
	var param # for previous state
	var planet_
	var tg_orbit
	
	func _init(shp, planet):
		ship = shp
		param = planet
		planet_ = planet
		tg_orbit = ship.ship.random_point_on_orbit(planet_.planet_rad_factor)
		
	func update(delta):
		# update target location
		ship.target = planet_.get_global_position()
		ship.rel_pos = ship.get_global_transform().xform_inv(ship.target)
		
		ship.ship.move_orbit(delta, planet_)
		
		# handle enemies
		ship.handle_enemy()

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
		
		# target is a Node here
		if is_instance_valid(target):
			#print("Tg pos: " + str(target.get_global_position()))
			var rel_pos = ship.get_global_transform().xform_inv(target.get_global_position())
			#print("Rel pos: " + str(rel_pos))
			var dist = ship.get_global_position().distance_to(target.get_global_position())
			if dist < 150:
				# steering behavior
				steer = ship.set_heading(target.get_global_position())
			else:
				steer = ship.get_steering_seek(target.get_global_position())
				
		# if target was killed, bail out immediately
		else:
			#print("[Target killed] Prev state: " + str(ship.prev_state))
			if ship.prev_state[0] != STATE_IDLE:
				# this way, we also pass the parameters
				ship.set_state(ship.prev_state[0], ship.prev_state[1])
				#print("Set state to: " + str(ship.get_state()))
			else:
				ship.set_state(STATE_GO_PLANET, ship.ship.get_colonized_planet())
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
			else:
				# approach any orbiting or enemies close to our planet
				var rad_f = ship.ship.get_colonized_planet().planet_rad_factor
				if (('orbiting' in enemy and enemy.orbiting) or enemy.get_global_position().distance_to(ship.ship.get_colonized_planet().get_global_position()) < 350*rad_f):
					pass
				# don't attack if enemy is too far
				else:
					if ship.prev_state[0] != STATE_IDLE:
						# this way, we also pass the parameters
						ship.set_state(ship.prev_state[0], ship.prev_state[1])
						#print("Set state to: " + str(ship.get_state()))
					else:
						# print("Go planet")
						# this will be true e.g. after deorbiting, as deorbiting sets state to IDLE!
						ship.set_state(STATE_GO_PLANET, ship.ship.get_colonized_planet())
	
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
			if ship.ship.is_in_group("drone"):
				ship.ship.simple_dock(base)
			else:
				ship.ship.refit_tractor(base)
			
			# dummy
			ship.target = ship.get_global_position()
			
				
				# pretend it's docked immediately
				#ship.ship.docked = true
		
		# ship is docked
		if ship.ship.docked:
			
			# buy from starbase
			if ship.ship.is_in_group("drone"):

				var sb = ship.ship.get_parent().get_parent()
				if not sb.storage.keys().size() > 0:
					return
				if ship.ship.bought:
					return
				
				# buy one random thing from starbase
				var id = randi() % sb.storage.keys().size()-1
				ship.ship.bought = true
				if sb.storage[sb.storage.keys()[id]] > 0:
					sb.storage[sb.storage.keys()[id]] -= 1
					# add cargo to player
					if not ship.ship.cargo.has(sb.storage.keys()[id]):
						ship.ship.cargo[sb.storage.keys()[id]] = 1
					else:
						ship.ship.cargo[sb.storage.keys()[id]] += 1
						
					print("Bought something from starbase")
				
			# sell cargo	
			else:
				# prevent crash if nothing in cargo
				if ship.ship.cargo.size() < 1:
					return
					
				for id in ship.ship.cargo.keys():
					if ship.ship.cargo[id] > 0:
						ship.ship.cargo[id] -= 1
				
						# add cargo to starbase
						if not ship.ship.get_parent().get_parent().storage.has(id):
							ship.ship.get_parent().get_parent().storage[id] = 1
						else:
							ship.ship.get_parent().get_parent().storage[id] += 1
			
			# start timer
			# task timer allows the AI to leave after some time passed
			#ship.ship.task_timer.start()
			
		# refit state is exited by timer_timeout

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
		# avoid the sun
		if ship.ship.close_to_sun():
			var sun = ship.get_tree().get_nodes_in_group("star")[0].get_global_position()
			# TODO: this should be weighted to avoid negating the seek completely
			steer = steer + ship.get_steering_avoid(sun, ship.ship.get_rotation())
			
			
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
	var id # store it instead of the whole node, for memory optimization purposes
	var moon = false
	
	func _init(shp, planet):
		ship = shp
		param = planet
		
		var data = planet.convert_planetnode_to_id()
		id = data[0]
		moon = data[1]
#		var planets = ship.get_tree().get_nodes_in_group("planets")
#
#		if planet.is_in_group("moon"):
#			#var parent = planet.get_parent().get_parent()
#			#var moons = parent.get_moons()
#			var moons = ship.get_tree().get_nodes_in_group("moon")
#			id = moons.find(planet)
#			moon = true
#			#id = planets.find(parent)
#		else:
#			id = planets.find(planet)
		
	func update(delta):
		
		# refresh target position
		var group = ship.get_tree().get_nodes_in_group("planets")
		if moon:
			group = ship.get_tree().get_nodes_in_group("moon")
		#else:
		
		ship.target = group[id].get_global_position()
		#print("ID" + str(id) + " tg: " + str(ship.target))
		ship.rel_pos = ship.get_global_transform().xform_inv(ship.target)
		# steering behavior
		var steer = ship.get_steering_seek(ship.target)
		
		# avoid the sun
		if ship.ship.has_method("close_to_sun") and ship.ship.close_to_sun():
			var sun = ship.get_tree().get_nodes_in_group("star")[0].get_global_position()
			# TODO: this should be weighted to avoid negating the seek completely
			steer = steer + ship.get_steering_avoid(sun, ship.ship.get_rotation())
		#else:
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		# if close, orbit
		# distances are experimentally picked
		var rad_f = param.planet_rad_factor
		var dist = 300*rad_f
		if moon:
			dist = 150*rad_f
			
		if (ship.target - ship.get_global_position()).length() < dist:
			ship.set_state(STATE_ORBIT, param)

# completely original	
class MineState:
	var ship
	var shot = false
	var param # for previous state
	var object
	var cnt = 0
	var target_num = 0
	
	# params is a list [obj, target_num, cnt]
	func _init(shp,params):
		ship = shp
		# reset ship's timer count
		ship.ship.timer_count = 0
		
		object = params[0]
		target_num = params[1]
		cnt = params[2]
		
		# paranoia
		ship.target = object.get_global_position()
		
		param = params
#		if cnt > 0:
#			print("Init Mine state with cnt " + str(cnt))
		
		
	func update(delta):
		
		var steer = Vector2(0,0)
		
		var enemy = ship.ship.get_closest_enemy()
		if enemy:
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 100:
				#print("We are close to an enemy, switching")
				#ship.target = enemy.get_global_position()
				ship.set_state(STATE_ATTACK, enemy)

		# aim towards the target
		var dist = ship.get_global_position().distance_to(ship.target)
		# we're too close~
		if dist < 30:
			# pick it up!
			if shot:
				# update position of any pickups
				var ress = ship.get_tree().get_nodes_in_group("resource")
				if ress.size() > 0 and ress[0].get_global_position().distance_to(ship.get_global_position()) < 200:
					ship.target = ress[0].get_global_position()
				#ship.target = object.get_global_position()
				# steering behavior
				steer = ship.set_heading(ship.target)
				#if ship.get_global_position().distance_to(ship.target) > 50:
				steer += ship.get_steering_arrive(ship.target)
			else:
				# gotta unstick
				ship.set_state(STATE_IDLE)
				# unstick vector
				ship.target = object.get_global_position() + Vector2(50,50)
				
		elif dist < 100:
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
		#var dist = ship.get_global_position().distance_to(ship.target)
		if dist < 80 and dist > 20 and not shot:
			#print("Close to target")
			ship.ship.shoot_wrapper()
		
		var ress = ship.get_tree().get_nodes_in_group("resource")	
		if ress.size() > 0 and ress[0].get_global_position().distance_to(ship.get_global_position()) < 200:
			# "shot", i.e. should we be picking sth up?
			if not shot:
				shot = true
			ship.target = ress[0].get_global_position()
		else:
			# if shot and no resource (e.g. because someone else picked it up)
			if shot:
				#print("Someone picked our resource")
				# not enough dist to fire a 2nd shot
				if ship.get_global_position().distance_to(ship.target) < 80:
					#print("Unstick...")
					ship.set_state(STATE_IDLE)
					# unstick vector
					ship.target = object.get_global_position() + Vector2(50,50)
				
				else:
					# reset
					shot = false
					# force update target location
					ship.target = object.get_global_position()
				
		# NPC ship resource_picked handles the switch to refit

# more originals
class LandState:
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
			print("No param given for land state")
			# default
			# should probably go for colonized planet
			#ship.ship.get_colonized_planet() is a node, not id
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
		# avoid the sun
		if 'close_to_sun' in ship.ship:
			if ship.ship.close_to_sun():
				var sun = ship.get_tree().get_nodes_in_group("star")[0].get_global_position()
				# TODO: this should be weighted to avoid negating the seek completely
				steer = steer + ship.get_steering_avoid(sun, ship.ship.get_rotation())
			
			
		# normal case
		ship.vel += steer
	
		ship.ship.move_AI(ship.vel, delta)
		
		
		if ship.get_global_position().distance_to(ship.target) < 50:
			# land
			print("We're on top of the target, landing...")
