extends "ship_basic.gd"

# class member variables go here, for example:
# AI specific stuff
var brain
onready var task_timer = $"task_timer"
var target_type = null

var targetted = false
# for player targeting the AI
signal AI_targeted
# for the AI targeting other ships
signal target_acquired_AI
signal target_lost_AI

signal AI_hit

export(int) var kind_id = 0

enum kind { enemy, friendly}

var ship_name = ""


func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	randomize()
	
	var friendly_names = ["Victorious", "Notorious"]
	var enemy_names = ["Slasher", "Gnasher"]
	
	if kind_id == kind.enemy:
		var id = randi() % enemy_names.size() # return between 0 and size -1
		ship_name = enemy_names[id]
		$"Label".set_text(ship_name)
		# tint red
		$"Label".set_self_modulate(Color(1, 0, 0))
		add_to_group("enemy")
	elif kind_id == kind.friendly:
		var id = randi() % friendly_names.size() # return between 0 and size-1
		ship_name = friendly_names[id]
		$"Label".set_text(ship_name)
		# tint cyan
		$"Label".set_self_modulate(Color(0, 1, 1))
		add_to_group("friendly")
		
#	print("Groups: " + str(get_groups()))
	
	connect("shield_changed", self, "_on_shield_changed")
	connect("AI_hit", self, "_on_AI_hit")

	brain = get_node("brain")
	# register ourselves with brain
	brain.ship = self
	# register brain with move visualizer
	get_node("vis").source = brain
	#print(str(brain.ship.get_name()))
		
#--------------------------------		

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
		get_parent().set_z_index(0)
		docked = false
	
	if not orbiting:
		# movement happens!
		#acc += vel * -friction
		#vel += acc *delta
		# prevent exceeding max speed
		vel = vel.clamped(max_vel)
		pos += vel * delta
		set_position(pos)
	
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


func orbit_planet(planet):
	.orbit_planet(planet)
	
	# AI specific
	vel = brain.set_heading(brain.target)
	
	# task timer allows the AI to deorbit after some time passed
	task_timer.start()

func deorbit():
	.deorbit()

	# AI switch to other target
	#if get_tree().get_nodes_in_group("asteroid").size() > 3:
	#	brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
	#	brain.set_state(brain.STATE_MINE)
			
func resource_picked():
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

func move_orbit(delta):
	# orbiting temporarily limited to friendlies
	#if kind_id == kind.friendly:
	if (brain.target - get_global_position()).length() < 300 and not orbiting:
		##orbit
		print("NPC wants to orbit: " + get_colonized_planet().get_name()) 
		orbit_planet(get_colonized_planet())
	elif not orbiting:
		var steer = brain.get_steering_arrive(brain.target)
		# normal case
		vel += steer
	#else:
	#	var steer = brain.get_steering_arrive(brain.target)	
		# normal case
	#	vel += steer
	
	move_AI(vel, delta)	

func refit_tractor(refit_target):
	# reparent			
	get_parent().get_parent().remove_child(get_parent())
	# refit target needs to be a node because here
	refit_target.add_child(get_parent())
	# set better z so that we don't overlap parent ship
	get_parent().set_z_index(-1)
	
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	# all local positions relative to the immediate parent
	get_parent().set_position(Vector2(0,50))
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
	
	print("Adding ship as tractoring ship's child")

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
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		#if not targetted:
		#targetted = true
		emit_signal("AI_targeted", self)
		#else:
		#	targetted = false
		
		# redraw 
		update()

func _on_shield_changed(shield):
	$"shield_effect".show()
	$"shield_timer".start()

func _on_shield_timer_timeout():
	$"shield_effect".hide()

#TODO: maybe move to brain.gd?
func _on_task_timer_timeout():
	print("Task timer timeout")
	if orbiting:
		if not get_tree().get_nodes_in_group("planets")[1].has_colony():
			if get_colony_in_dock() == null:
				if kind_id == kind.friendly:
					# pick up colony from planet
					pick_colony()
				else:
					print("Blockading a planet")
			else:
				# deorbit
				deorbit()		
				brain.target = get_tree().get_nodes_in_group("planets")[1].get_global_position()
				brain.set_state(brain.STATE_COLONIZE)
				#if get_tree().get_nodes_in_group("asteroid").size() > 3:
				#	brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
				#brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])
		else:
			deorbit()
			if get_tree().get_nodes_in_group("asteroid").size() > 3:
				brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
			brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])
	else:
		if not (brain.get_state() in [brain.STATE_MINE, brain.STATE_REFIT, brain.STATE_COLONIZE, brain.STATE_ATTACK]):
			if get_tree().get_nodes_in_group("asteroid").size() > 3:
				brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
			brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])
		if brain.get_state() == brain.STATE_REFIT:
			if not docked:
				return
			else:
				if get_tree().get_nodes_in_group("asteroid").size() > 3:
					brain.target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
				brain.set_state(brain.STATE_MINE, get_tree().get_nodes_in_group("asteroid")[2])