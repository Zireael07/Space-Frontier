extends "drone_basic.gd"

# Declare member variables here. Examples:
var landed = false
# AI specific stuff
var brain
onready var task_timer = $"task_timer"
var timer_count = 0

export(int) var kind_id = 0

enum kind { enemy, friendly}


# Called when the node enters the scene tree for the first time.
func _ready():
	get_parent().set_z_index(game.SHIP_Z)
	
	randomize()
	
	# slight randomization of the task timer
	var time = randf()
	$"task_timer".start(0.5+time)
	
	
	brain = get_node("brain")
	# register ourselves with brain
	brain.ship = self
	# register brain with move visualizer
	get_node("vis").source = brain

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


#--------------------------------		

# this version needs the planet NOT to be blockaded
func get_colonized_planet():
	var ps = []
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		# is it colonized?
		var col = p.has_colony()
		# is NOT blockaded
		if col and col == "colony" and p.get_hostile_orbiter() == null:
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

# -------------------------------

# AI moves to orbit a planet
func move_orbit(delta, planet, system):
	if not planet:
		planet = get_colonized_planet()
	var rad_f = planet.planet_rad_factor
	
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
			#print("NPC wants to orbit: " + get_colonized_planet().get_node("Label").get_text()) 
			orbit_planet(planet)
			# nuke steer
			brain.steer = Vector2(0,0)
	# if too far away, go to planet
	else:
		if not orbiting:
			#pass
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

func random_point_on_orbit(rad_f):
	# randomize the point the AI aims for
	randomize()
	var rand1 = randf()
	#var rand2 = randf()
	var offset = Vector2(0, 1).normalized()*(250*rad_f)
	offset = offset.rotated(rand1)
	#print("Offset: " + str(offset))
	var tg_orbit = brain.target + offset
	return tg_orbit

func _on_task_timer_timeout():
	#print("Task timer timeout")
	timer_count += 1
	if timer_count == 1:
		$"task_timer".wait_time = 2.0
	
	brain._on_task_timer_timeout(timer_count)

func land(pl):
	#print("Landing...")
	get_parent().get_node("AnimationPlayer").play("landing")
	# landing happens only when the animation is done

	# reparent
	get_parent().get_parent().remove_child(get_parent())
	pl.get_node("orbit_holder").add_child(get_parent())
	get_parent().set_position(Vector2(0,0))
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
	# nuke velocities
	acc = Vector2(0,0)
	vel = Vector2(0,0)

func _on_AnimationPlayer_animation_finished(_anim_name):
	#print("Animation finished")
	# toggle the landing state
	if not landed:
		landed = true
	else:
		landed = false
		
	# set AI timeout
	timer_count = 0

func launch():
	get_parent().get_node("AnimationPlayer").play_backwards("landing")

	# reparent
	var root = get_node("/root/Control")
	var gl = get_global_position()
			
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())

func dodge_effect():
	self.modulate = Color(1,1,1, 0.5) # semi-transparent
	$"shield_effect".show()
	# fix occasional problem
	if $"shield_timer".is_inside_tree():
		$"shield_timer".start()
	else:
		$"shield_timer".call_deferred("start")
		
func _on_shield_timer_timeout():
	$"shield_effect".hide()
	self.modulate = Color(1,1,1,1)
