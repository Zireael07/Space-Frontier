extends "ship_basic.gd"

# class member variables go here, for example:
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

enum kind { enemy, friendly}

var ship_name = ""

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	get_parent().set_z_index(game.SHIP_Z)
	
	# slow down AI shield recharge
	shield_recharge = 2
	
	randomize()
	
	# slight randomization of the task timer
	var time = randf()
	$"task_timer".start(2.0+time)
	
	if kind_id == kind.enemy:
		var id = randi() % game.enemy_names.size() # return between 0 and size -1
		ship_name = game.enemy_names[id]
		$"Label".set_text(ship_name)
		# tint red
		$"Label".set_self_modulate(Color(1, 0, 0))
		add_to_group("enemy")
	elif kind_id == kind.friendly:
		var id = randi() % game.friendly_names.size() # return between 0 and size-1
		ship_name = game.friendly_names[id]
		# remove name that was already used
		game.friendly_names.remove(id)
		$"Label".set_text(ship_name)
		# tint cyan
		$"Label".set_self_modulate(Color(0, 1, 1))
		add_to_group("friendly")
		
#	print("Groups: " + str(get_groups()))
	
	connect("shield_changed", self, "_on_shield_changed")
	connect("AI_hit", self, "_on_AI_hit")
	
	connect("AI_targeted", game.player.HUD, "_on_AI_targeted")
	
	connect("target_killed", self, "_on_target_killed")
	
	connect("ship_killed", game.player.HUD, "_on_ship_killed")

	brain = get_node("brain")
	# register ourselves with brain
	brain.ship = self
	# register brain with move visualizer
	get_node("vis").source = brain
	#print(str(brain.ship.get_name()))
		
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
	if docked:
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
	
	# rotation
	set_rotation(-a)
	
	# straighten out labels
	$"Label".set_rotation(a)

func shoot_wrapper():
	if gun_timer.get_time_left() == 0:
		shoot()

func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())


# AI moves to orbit a planet
func move_orbit(delta):
	var rad_f = get_colonized_planet().planet_rad_factor
	
	# brain target is the planet we're orbiting
	if (brain.target - get_global_position()).length() < 200*rad_f:
		#print("Too close to orbit")
		if not orbiting:
			var tg_orbit = brain.get_state_obj().tg_orbit
			#print("Tg_orbit: " + str(tg_orbit))
			var steer = brain.get_steering_arrive(tg_orbit)
			# normal case
			vel += steer
	# 300 is experimentally picked
	elif (brain.target - get_global_position()).length() < 300*rad_f:
		if not orbiting:
			#print("In orbit range: " + str((brain.target - get_global_position()).length()) + " " + str((300*rad_f)))
			##orbit
			print("NPC wants to orbit: " + get_colonized_planet().get_node("Label").get_text()) 
			orbit_planet(get_colonized_planet())
			# nuke steer
			brain.steer = Vector2(0,0)
	# if too far away, go to planet
	else:
		if not orbiting:
			#pass
			brain.set_state(brain.STATE_GO_PLANET, get_colonized_planet())
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
	brain.steer = Vector2(0,0)
	brain.desired = Vector2(0,0)
	brain.target = planet.get_global_position()
	vel = Vector2(0,0) 
	acc = Vector2(0,0)
	
	# we're rotated compared to what look_at uses, so it handily makes the AI face the correct direction...
	look_at(planet.get_global_position())
	#vel = brain.set_heading(brain.target).clamped(2)
	
	# task timer allows the AI to deorbit after some time passed
	task_timer.start()

func deorbit():
	.deorbit()
	
	if not (brain.get_state() in [brain.STATE_ATTACK]):
		# force change state
		brain.set_state(brain.STATE_IDLE)
	
		_on_task_timer_timeout()
	
		# we should fire the task timer timeout, but since it goes to mining 90% of the time, just pretend it does so too...
#		if get_tree().get_nodes_in_group("asteroid").size() > 3:
#				brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
#				brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])

func random_point_on_orbit(rad_f):
	# randomize the point the AI aims for
	randomize()
	var rand1 = randf()
	#var rand2 = randf()
	var offset = Vector2(0, 1).normalized()*(250*rad_f)
	offset = offset.rotated(rand1)
	print("Offset: " + str(offset))
	var tg_orbit = brain.target + offset
	return tg_orbit
			
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
	
	# signal player being attacked if it's the case
	if attacker.is_in_group("player"):
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
	# 6 is the default, so only check if we have more
	if get_parent().get_parent().get_child_count() > 6:
		for ch in get_parent().get_parent().get_children():
			if ch is Node2D and ch.get_index() > 5:
				if ch.is_in_group("player"):
					#print("Player docked with the starbase")
					friend_docked = true
					break
				if ch.get_child_count() > 0 and ch.get_child(0).is_in_group("friendly"):
					#print("Friendly docked with the starbase")
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

func _on_shield_changed(data):
	#print(str(shield))
	var effect
	if data.size() > 1:
		effect = data[1]
	else:
		effect = true
	if effect:
		$"shield_effect".show()
		$"shield_timer".start()
	# if shield falls low, go away	
		
	if data[0] < 40:
		#print("Flee because of low shields")
		if orbiting:
			deorbit()
		# head to a friendly base for protection
		# get the base
		var base = get_friendly_base()
		if base != null:
			#print(base.get_name())
			#print("Fleeing to our base")
			brain.target = base.get_global_position()
			brain.set_state(brain.STATE_REFIT, base)
		
#		if get_tree().get_nodes_in_group("asteroid").size() > 3:
#			brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
#			brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])

func _on_shield_timer_timeout():
	$"shield_effect".hide()


func _on_task_timer_timeout():
	#print("Task timer timeout")
	timer_count += 1
	if timer_count == 1:
		$"task_timer".wait_time = 2.0
	
	brain._on_task_timer_timeout(timer_count)
	
func _on_target_killed(target):
	print("Killed target " + str(target.get_parent().get_name()))
	
	brain._on_target_killed(target)
