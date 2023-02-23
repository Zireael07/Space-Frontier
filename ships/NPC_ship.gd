extends "ship_basic.gd"

# class member variables go here, for example:
var landed = false
# AI specific stuff
var brain
onready var task_timer = $"task_timer"
var timer_count = 0
var target_type = null

var targetted = false
# for player targeting the AI
signal AI_targeted
# for the AI targeting other ships
signal target_acquired_AI
signal target_lost_AI

signal AI_hit

# tells us we killed the target, whatever it was
signal target_killed

signal ship_killed

export(int) var kind_id = 0

enum kind { enemy, friendly, pirate, neutral }

var ship_name = ""
var labl_loc = Vector2()

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	get_parent().set_z_index(game.SHIP_Z)
	
	labl_loc = $"Label".get_position()
	
	# slow down AI shield recharge
	shield_recharge = 2
	
	randomize()
	
	# slight randomization of the task timer
	var time = randf()
	var t = 2.0+(time*2)
	#print(get_name() + " timer: " + str(t))
	$"task_timer".start(t)
	
	# enemies and pirates share name lists
	if kind_id == kind.enemy or kind_id == kind.pirate:
		var id = randi() % game.enemy_names.size() # return between 0 and size -1
		ship_name = game.enemy_names[id]
		# remove name that was already used
		game.enemy_names.remove(id)
		$"Label".set_text(ship_name)
		# tint red
		$"Label".set_self_modulate(Color(1, 0, 0))
	if kind_id == kind.enemy:
		add_to_group("enemy")
	elif kind_id == kind.pirate:
		add_to_group("pirate")
	elif kind_id == kind.friendly and has_node("Label"):
		var id = randi() % game.friendly_names.size() # return between 0 and size-1
		ship_name = game.friendly_names[id]
		# remove name that was already used
		game.friendly_names.remove(id)
		$"Label".set_text(ship_name)
		# tint cyan
		$"Label".set_self_modulate(Color(0, 1, 1))
		add_to_group("friendly")
	elif kind_id == kind.neutral:
		var id = randi() % game.neutral_names.size() # return between 0 and size -1
		ship_name = game.neutral_names[id]
		# remove name that was already used
		game.neutral_names.remove(id)
		$"Label".set_text(ship_name)
		$"Label".set_self_modulate(Color(1,0.8, 0))
		add_to_group("neutral")
		
#	print("Groups: " + str(get_groups()))
	var _conn
	
	_conn = connect("shield_changed", self, "_on_shield_changed")
	_conn = connect("AI_hit", self, "_on_AI_hit")
	
	_conn = connect("AI_targeted", game.player.HUD, "_on_AI_targeted")
	
	_conn = connect("target_killed", self, "_on_target_killed")
	
	_conn = connect("ship_killed", game.player.HUD, "_on_ship_killed")
	
	_conn = connect("colony_picked", game.player.HUD, "_on_colony_picked")
	
	# targeting signals (for status light)
	_conn = connect("target_acquired_AI", game.player.HUD, "_on_target_acquired_by_AI")
	_conn = connect("target_lost_AI", game.player.HUD, "_on_target_lost_by_AI")

	brain = get_node("brain")
	# register ourselves with brain
	brain.ship = self
	# register brain with move visualizer
	get_node("vis").source = brain
	#print(str(brain.ship.get_name()))

func _process(_delta):
	# fix label rotation when orbiting
	if orbiting:
		# label rotation
		$"Label".set_rotation(-get_global_rotation())
		
	# get the label to stay in one place from player POV
	# this is the same as in planet.gd line 386
	# TODO: is there a better solution (less calls)?
	var angle = -get_global_rotation() + deg2rad(45) # because the label is located at 45 deg angle...
	# effectively inverse of atan2()
	var angle_loc = Vector2(cos(angle), sin(angle))
	#Controls don't have transforms so we have to manually set position
	$"Label"._set_position(angle_loc*labl_loc.length())

#--------------------------------		

func get_colonized_planet():
	var ps = []
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		# is it colonized?
		var col = p.has_colony()
		if col and col == "colony":
			ps.append(p)

	var dists = []
	var targs = []
	
	for t in ps:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	# get the closest
	for t in targs:
		if t[0] == dists[0]:
			#print("Target is : " + t[1].get_parent().get_name())
			
			return t[1]
	
#	else:
#		print("No colonized planet found")
#		return null

func get_planet_colony_available():
	var ps = []
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		# is it colonized?
		var col = p.has_colony()
		if col and col == "colony":
			ps.append(p)

	var pops = []
	var targs = []
	
	for p in ps:
		var pop = p.population
		pops.append(pop)
		targs.append([pop, p])

	# sorts by population, ascending
	pops.sort()
	#print("Pops sorted: " + str(pops))

	
	# get the one with the biggest pop
	for t in targs:
		if t[0] == pops[pops.size()-1]:
			print("Colony pickup target is : " + t[1].get_node("Label").get_text())
			
			return t[1]

func get_colonize_moon():
	var moon_list = []
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		if p.has_colony():
			var moons = p.get_moons()
			for m in moons:
				var col = m.has_colony()
				if !col:
					moon_list.append(m)
		
		# gas giant moons
#		if not p.has_solid_surface():
#			var moons = p.get_moons()
#			for m in moons:
#				var col = m.has_colony()
#				if !col:
#					moon_list.append(m)

	var dists = []
	var targs = []

	for p in moon_list:
		#var pop = p.population
		var dist = p.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, p])

	# sorts by distance, ascending
	dists.sort()
	#print("Pops sorted: " + str(pops))
	
	for t in targs:
		if t[0] == dists[0]:
			print("Colonize target moon is : " + t[1].get_node("Label").get_text())
			
			# get id in planets list
			var parent = t[1].get_parent().get_parent()
			var id = planets.find(parent)
			
			# +1 to avoid problems with state's param being 0 (=null)
			return id+1 

func get_colonize_target():
	var ps = []
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		# exclude those with colony
		var col = p.has_colony()
		# ignore planets with no solid surface (i.e. we're only interested in rocky ones)
		if !col and p.has_solid_surface():
			ps.append(p)
		#if col and col == "colony":
		#	ps.append(p)
	
	var pops = []
	var targs = []

	for p in ps:
		var pop = p.population
		pops.append(pop)
		targs.append([pop, p])

	# sorts by population, ascending
	pops.sort()
	#print("Pops sorted: " + str(pops))
	
	for t in targs:
		if t[0] == pops[0]:
			#print("Colonize target planet is : " + t[1].get_node("Label").get_text())
			
			# get id in planets list (it's guaranteed to be in it because of step #1 of our search
			var id = planets.find(t[1])
			
			# +1 to avoid problems with state's param being 0 (=null)
			return id+1 

# --------------------

func move_AI(vel, delta):
	var a = brain.fix_atan(vel.x,vel.y)
	
	# effects
	if vel.length() > 40:
		$"engine_flare".set_emitting(true)
	else:
		$"engine_flare".set_emitting(false)
	
	# undock
	if docked and vel != Vector2(0,0):
		print("Undocking... " + get_parent().get_name())
		# restore original z
		set_z_index(0)
		docked = false
		# reparent
		var root = get_node("/root/Control")
		var gl = get_global_position()
				
		get_parent().get_parent().remove_child(get_parent())
		root.add_child(get_parent())
				
		get_parent().set_global_position(gl)
		set_position(Vector2(0,0))
		pos = Vector2(0,0)
				
		set_global_rotation(get_global_rotation())
	
	if not orbiting:
		# movement happens!
		#acc += vel * -friction
		#vel += acc *delta
		# prevent exceeding max speed
		vel = vel.clamped(max_vel)
		pos += vel * delta
		set_position(pos)
	else:
		vel = Vector2(0,0)
	
	# warp drive!
	#if not heading and warp_target != null:
	if warp_target != null:
		# abort abort!
		if brain.get_state() != brain.STATE_REFIT:
			print("Aborting because of wrong state")
			warping = false
			warp_target = null
			return
		
		if warping:
			# paranoia
			if get_colony_in_dock() != null:
				warping = false
				warp_target = null
				return
			
			print(get_parent().get_name(), " warping...")
			# update target because the planet is orbiting, after all...
			#warp_target = warp_target.get_global_position()
			
			var desired = warp_target - get_global_position()
			var dist = desired.length()
			
			if dist > LIGHT_SPEED:
				vel = Vector2(0, -LIGHT_SPEED).rotated(rot)
				pos += vel* delta
				# prevent accumulating
				vel = vel.clamped(LIGHT_SPEED)
				set_position(pos)
			else:
				# we've arrived, return to normal space
				warp_target = null
				warping = false
				#cruise = false
				warp_timer.stop()
				# remove tint
				set_modulate(Color(1,1,1))
	
	
	# rotation
	set_rotation(-a)
	
	# straighten out labels
	#if has_node("Label"):
	$"Label".set_rotation(a)

func shoot_wrapper():
	if gun_timer.get_time_left() == 0:
		shoot()

func shoot():
	# TODO: implement power draw for AI ships
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_global_rotation(), $"muzzle".get_global_position())


# AI moves to orbit a planet
func move_orbit(delta, planet, system):
	# paranoia
	if not planet:
		planet = get_colonized_planet()
	
	var rad_f = planet.planet_rad_factor
	
	# distances are experimentally picked
	var min_dist = 200*rad_f
	var orbit_dist = 300*rad_f
	if planet.is_in_group("moon"):
		min_dist = 50*rad_f
		orbit_dist = 150*rad_f
		
	
	# brain target is the planet we're orbiting
	if (brain.target - get_global_position()).length() < min_dist:
		#print("Too close to orbit")
		if not orbiting:
			var tg_orbit = brain.get_state_obj().tg_orbit
			#print("Tg_orbit: " + str(tg_orbit))
			var steer = brain.get_steering_arrive(tg_orbit)
			brain.steer = steer
			# normal case
			vel += steer
			brain.vel = vel
	# 300 is experimentally picked
	elif (brain.target - get_global_position()).length() < orbit_dist:
		if not orbiting:
			#print("In orbit range: " + str((brain.target - get_global_position()).length()) + " " + str((300*rad_f)))
			##orbit
			if not is_in_group("drone"):
				print("NPC " + get_parent().get_name() + " wants to orbit: " + planet.get_node("Label").get_text()) 
			orbit_planet(planet)
			# nuke steer
			brain.steer = Vector2(0,0)
	# if too far away, go to planet
	else:
		if not orbiting:
			if (brain.target - get_global_position()).length() < orbit_dist*2:
				var tg_orbit = brain.get_state_obj().tg_orbit
				# recalculate for trappist as it orbits very fast
				if system == "trappist":
					tg_orbit = random_point_on_orbit(planet.planet_rad_factor)
				#print("Rel pos: ", brain.rel_pos)
				#print("Tg_orbit: " + str(tg_orbit))
				
				var steer = brain.get_steering_arrive(tg_orbit)
				#var steer = brain.set_heading(tg_orbit)
				brain.steer = steer
				# normal case
				vel += steer
				brain.vel = vel
				#pass
			else:
				brain.set_state(brain.STATE_GO_PLANET, planet)
		else:
			pass
	
	# orbiting itself is handled in ship_base.gd and in planet.gd
			
	# dummy
#	if not orbiting:
#		var steer = brain.get_steering_arrive(brain.target)
#		# normal case
#		vel += steer
	#else:
	#	var steer = brain.get_steering_arrive(brain.target)	
		# normal case
	#	vel += steer
	
	if not orbiting:
		move_AI(vel, delta)
	else:
		# nuke any velocities existing
		vel = Vector2(0,0)
		acc = Vector2(0,0)

	# heading is taken care of below


func orbit_planet(planet):
	.orbit_planet(planet)
	
	# AI specific
	# reset everything just to be super safe
	brain.vel = Vector2(0,0)
	brain.steer = Vector2(0,0)
	brain.desired = Vector2(0,0)
	brain.target = planet.get_global_position()
	vel = Vector2(0,0) 
	acc = Vector2(0,0)
	
	# we're rotated compared to what look_at uses, so it handily makes the AI face the correct direction...
	look_at(planet.get_global_position())
	#vel = brain.set_heading(brain.target).clamped(2)
	
	# label rotation
	$"Label".set_rotation(-get_global_rotation())
	
	# task timer allows the AI to deorbit after some time passed
	task_timer.start()

func deorbit():
	.deorbit()
	
	if not (brain.get_state() in [brain.STATE_ATTACK]):
		# force change state
		brain.set_state(brain.STATE_IDLE)

		_timer_stuff(true)
	
		# we should fire the task timer timeout, but since it goes to mining 90% of the time, just pretend it does so too...
#		if get_tree().get_nodes_in_group("asteroid").size() > 3:
#				brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
#				brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])

func random_point_on_orbit(rad_f):
	# randomize the point the AI aims for
	return random_point_at_dist_from_tg(250*rad_f)
			
func random_point_at_dist_from_tg(dist):
	# randomize the point the AI aims for
	randomize()
	var rand1 = randf()
	#var rand2 = randf()
	var offset = Vector2(0, 1).normalized()*(dist)
	offset = offset.rotated(rand1)
	#print("Offset: " + str(offset))
	var point = brain.target + offset
	return point
			
func get_asteroid_processor():
	var processors = get_tree().get_nodes_in_group("processor")
	if processors.size() > 0:
		return processors[0]
	return null
			
func resource_picked():
	# paranoia
	if not 'cnt' in brain.state:
#		print("Refit either way!")
#		# go refit either way
#		# get the base
#		var base = get_friendly_base()
#		# refit
#		if base != null:
#			print("Resources picked, refit")
#			brain.target = base.get_global_position()
#			brain.set_state(brain.STATE_REFIT, base)
		return
	# increment the counter
	brain.state.cnt += 1
	print("Counter: " + str(brain.state.cnt))

	# reset just in case
	brain.state.shot = false

	# get the base
	var base = get_friendly_base()
	# refit
	if base != null and brain.state.cnt == brain.state.target_num:
		print("Resources picked, refit")
		brain.target = base.get_global_position()
		brain.set_state(brain.STATE_REFIT, base)

func _on_AI_hit(attacker):
	print("AI hit by " + str(attacker.get_name()))
	# switch to attack
	if brain.get_state() != brain.STATE_ATTACK:
		brain.set_state(brain.STATE_ATTACK, attacker)
	else:
		# is current attacker closer than previous one?
		var cur_att = brain.get_state_obj().target.get_global_position()
		var att = attacker.get_global_position()
		var cur_att_dist = get_global_position().distance_to(cur_att)
		var att_dist = get_global_position().distance_to(att)
		if att_dist < cur_att_dist:
			# hack to prevent AI immediately going after previous target upon kill
			#brain.set_state(brain.STATE_IDLE)
			brain.set_state(brain.STATE_ATTACK, attacker)
		#pass
	
	# signal player being attacked if it's the case
	if attacker.is_in_group("player"):
		if self in attacker.targeted_by:
			pass
		else:
			attacker.targeted_by.append(self)
			emit_signal("target_acquired_AI", self)
			print("AI ship acquired target")

func refit_tractor(refit_target):
	# reparent			
	get_parent().get_parent().remove_child(get_parent())
	# refit target needs to be a node because here
	refit_target.add_child(get_parent())
	# set better z so that we don't overlap parent ship
	set_z_index(-1)
	
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	var friend_docked = false
	# 7 is the default, so only check if we have more
	if get_parent().get_parent().get_child_count() > 7:
		for ch in get_parent().get_parent().get_children():
			if ch is Node2D and ch.get_index() > 6:
				if ch.is_in_group("player"):
					#print("Player docked with the starbase")
					friend_docked = true
					break
				if ch.get_child_count() > 0 and ch.get_child(0).is_in_group("friendly") and not ch.get_child(0).is_in_group("drone"):
					#print("Friendly docked with the starbase")
					friend_docked = true
					break
				if ch.get_child_count() > 0 and ch.get_child(0).is_in_group("enemy") and ch.get_child(0).docked and ch != get_parent() and self.is_in_group("enemy"):
					#print("Other ship docked with the starbase.. " + ch.get_name())
					friend_docked = true
					break
	
	# all local positions relative to the immediate parent
	if friend_docked:
		get_parent().set_position(Vector2(-25,50))
	else:
		get_parent().set_position(Vector2(0,50))
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
	
	#print("Adding ship as tractoring ship's child")

	docked = true
	
	#fix visuals
	var a = brain.fix_atan(vel.x,vel.y)
	$"engine_flare".set_emitting(false)
	# rotation
	set_rotation(-a)
	
	# straighten out labels
	#if has_node("Label"):
	$"Label".set_rotation(a)
	
	brain.vel = Vector2(0,0)
	brain.desired = Vector2(0,0)
	brain.steer = Vector2(0,0)

# draw a red rectangle around the target
func _draw():
	if game.player.HUD.target == self:
	#if targetted:
		var rect = Rect2(Vector2(-28, -25),	Vector2(97*0.6, 84*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)
	else:
		pass

# click to target functionality
func _on_Area2D_input_event(_viewport, event, _shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		#if not targetted:
		#targetted = true
		emit_signal("AI_targeted", self)
		#else:
		#	targetted = false
		
		# redraw 
		update()

func on_warping():
	# no warping if we are hauling a colony
	if get_colony_in_dock() != null:
		warping = false
		return
	
	# effect
	var warp = warp_effect.instance()
	add_child(warp)
	warp.set_position(Vector2(0,0))
	warp.play()
	
	# tint a matching orange color
	set_modulate(Color(1, 0.73, 0))

func _on_shield_changed(data):
	#print(str(shield))
	var effect
	if data.size() > 1:
		effect = data[1]
	else:
		effect = true
	if effect:
		$"shield_effect".show()
		# fix occasional problem
		if $"shield_timer".is_inside_tree():
			$"shield_timer".start()
		else:
			$"shield_timer".call_deferred("start")
				
	# how many enemies around?
	var enemies = get_enemies_in_range()
	#print("Enemies around: " + str(enemies.size()))
	
	var flee_threshold = 40
	if enemies.size() > 2 or is_enemy_a_starbase(enemies):
		flee_threshold = 60
		#print("Many enemies or starbase enemy detected!")
	# if we're carrying a colony, flee earlier (if we get destroyed so does the colony)
	if get_colony_in_dock() != null:
		flee_threshold = 60
	
	# if shield falls low, go away
	if data[0] < flee_threshold and effect:
		#print("Flee because of low shields")
		if orbiting:
			deorbit()
		
		# TODO: cloak if we have it
			
		# TODO: flee first, then head to a base	
		
		# early return
		if brain.get_state() == brain.STATE_REFIT:
			return
		
		# head to a friendly base for protection
		# get the base
		var base = get_friendly_base()
		if base != null:
			#print(base.get_name())
			#print("Fleeing to our base")
			
			brain.steer = brain.set_heading(base.get_global_position())
			warp_target = base.get_global_position()
			
			brain.target = base.get_global_position()
			brain.set_state(brain.STATE_REFIT, base)
			
			
			# don't unnecessarily flee if already close by
#			if get_global_position().distance_to(base.get_global_position()) < 150:
#				return
#			else:
#				brain.target = base.get_global_position()
#				brain.set_state(brain.STATE_REFIT, base)
		
		# update player status light if needed
		if self in game.player.targeted_by:
			var find = game.player.targeted_by.find(self)
			if find != -1:
				game.player.targeted_by.remove(find)
			if game.player.targeted_by.size() < 1:
				emit_signal("target_lost_AI", self)
		
#		if get_tree().get_nodes_in_group("asteroid").size() > 3:
#			brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
#			brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])

func _on_shield_timer_timeout():
	$"shield_effect".hide()

func _on_warp_correct_timer_timeout():
	if warping:
		# fix heading
		look_at(warp_target)

func _timer_stuff(forced=false):
	if forced:
		print("Forced timer stuff")
		# fake for refit on shields hit to work
		orbiting = false
		
	
	# paranoia
	if !self.is_inside_tree():
		call_deferred("_on_task_timer_timeout")
		return
	
	#print("Task timer timeout")
	timer_count += 1
	if timer_count == 1:
		$"task_timer".wait_time = 2.0
	
	brain._on_task_timer_timeout(timer_count)
	
func _on_task_timer_timeout():
	_timer_stuff()
	
func _on_target_killed(target):
	print("Killed target " + str(target.get_parent().get_name()))
	
	brain._on_target_killed(target)
