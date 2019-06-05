extends "ship_basic.gd"

# class member variables go here, for example:
var shield_level = 1
var engine_level = 1
var power_level = 1
signal module_level_changed

var power = 100
var shoot_power_draw = 10
var warp_power_draw = 50
var power_recharge = 5
signal power_changed

onready var warp_effect = preload("res://warp_effect.tscn")

onready var recharge_timer = $"recharge_timer"

var target = null
var tractor = null
var heading = null
var warp_target = null
var warping = false

var tractored = false
var refit_target = false

var targeted_by = null

var HUD = null
signal officer_message

var cargo = {}
var credits = 0
var landed = false

# for AI orders
var conquer_target = null

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	game.player = self
	
	
	connect("shield_changed", self, "_on_shield_changed")
	
	# spawn somewhere interesting
	var planet = get_tree().get_nodes_in_group("planets")[2]
	print("Location of planet " + str(planet) + " : " + str(planet.get_global_position()))
	
	# fudge
	var offset = Vector2(0,0) #Vector2(50,50)
	get_parent().set_global_position(planet.get_global_position() + offset)
	set_position(Vector2(0,0))
	

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# redraw 
	update()

	spd = vel.length() / LIGHT_SPEED

	# shoot
	if Input.is_action_pressed("shoot"):
		if gun_timer.get_time_left() == 0:
			shoot()

	# tractor
	if tractor:
		var dist = get_global_position().distance_to(tractor.get_child(0).get_global_position())
		
		# too far away, deactivate
		if dist > 100:
			tractor.get_child(0).tractor = null
			tractor = null
			print("Deactivating tractor")
			
		else:
			#print("Tractor active on: " + str(tractor.get_name()) + " " + str(dist))
			tractor.get_child(0).tractor = self


	# rotations
	if Input.is_action_pressed("ui_left"):
		rot -= rot_speed*delta
	if Input.is_action_pressed("ui_right"):
		rot += rot_speed*delta
	# thrust
	if Input.is_action_pressed("ui_up"):
		# undock
		if docked:
			docked = false
		
		# deorbit
		if orbiting:
			deorbit()
		else:
			if warp_target == null:
				acc = Vector2(0, -thrust).rotated(rot)
				$"engine_flare".set_emitting(true)
	else:
		acc = Vector2(0,0)
		$"engine_flare".set_emitting(false)
	
	if not orbiting:
		# movement happens!
		# modify acc by friction dependent on vel
		acc += vel * -friction
		vel += acc *delta
		# prevent exceeding max speed
		vel = vel.clamped(max_vel)
		pos += vel * delta
		set_position(pos)
		#print("Setting position" + str(pos))
	
	# warp drive!
	if not heading and warp_target != null:
		if warping:
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
				# remove tint
				set_modulate(Color(1,1,1))
			
	# refit
	if not heading and refit_target:
		var desired = refit_target.get_global_position() - get_global_position()
		var dist = desired.length()
		
		desired = desired.normalized()
		if dist < 100:
			var m = range_lerp(dist, 0, 100, 0, max_vel) 
			desired = desired * m
		else:
			desired = desired * max_vel
			tractored = false
			
		vel = desired.clamped(max_vel)
		pos += vel*delta
		set_position(pos)
		
		if dist < 50:
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
			
			print("Adding player as tractoring ship's child")
			
			# arrived
			refit_target = null
			print("No refit target anymore")
			# disable tractor
			tractored = false
			docked = true
			# show refit screen
			self.HUD.switch_to_refit()
			
		elif dist < 80:
			tractored = true
			#print("We're being tractored in")
		
	# rotation
	# handling heading (usually the warp-drive)
	if heading:
		player_heading(heading, delta)
			
			
		
	set_rotation(rot)
	
	# fix jitter due to camera updating one frame late
	get_node("Camera2D").align()
	
	# overheat damage
	var star = get_tree().get_nodes_in_group("star")[0]
	var dist = star.get_global_position().distance_to(get_global_position())
	if dist < 550* star.star_radius_factor and not warping:
		print("distance to star: " + str(dist))
		if get_node("heat_timer").get_time_left() == 0:
			heat_damage()


func player_heading(target, delta):
	var rel_pos = get_global_transform().xform_inv(target)
	
	var a = atan2(rel_pos.x, rel_pos.y)
	
	# we've turned to face the target
	if abs(rad2deg(a)) > 179:
		# emit signal
		if heading == warp_target:
			on_warping()
		
		heading = null
		
	
	if a < 0:
		rot -= rot_speed*delta
	else:
		rot += rot_speed*delta
	

func _input(event):
	if Input.is_action_pressed("closest_target"):
		get_closest_target()
	
	if Input.is_action_pressed("join"):
		if not orbiting:
			print("Not orbiting")
		else:
			var col = pick_colony()
			if col:
				emit_signal("officer_message", "We have picked up a colony. Transport it to a planet and press / to drop it.")
				
			else:
				print("Planet has too little pop to create colony")
			
	
	if Input.is_action_pressed("orbit"):
		#print("Try to orbit")
		var pl = get_closest_planet()
		# values are eyeballed for current planets (scale 1, sprite 720*0.5=360 px)
		if pl[0] > 300*pl[1].planet_rad_factor:
			print("Too far away to orbit")
		elif pl[0] < 200*pl[1].planet_rad_factor:
			print("Too close to orbit")
		else:
			print("Can orbit")
			if pl[1].has_node("orbit_holder"):
				orbit_planet(pl[1])
				
				emit_signal("officer_message", "Orbit established. Press J to request a colony")
	
	if Input.is_action_pressed("refit"):
		print("Want to refit")
		
		var base = get_friendly_base()
		heading = base.get_global_position()
		refit_target = base
	
	# tractor
	if Input.is_action_pressed("tractor"):
		# toggle
		if not tractor:
		#tractor = true
			# TODO: closest colony
			tractor = get_tree().get_nodes_in_group("colony")[1]
		else:
			tractor = null

	if Input.is_action_pressed("undock_tractor"):
		print("Undock pressed")
		
		tractor = null
	
		var col = get_colony_in_dock()
		if col:
			# undock
			remove_child(col)
			get_parent().get_parent().add_child(col)
			
			# restore original z
			col.set_z_index(0)
			
			col.set_global_position(get_node("dock").get_global_position() + Vector2(0, 20))
			
			print("Undocked")
			
	if Input.is_action_pressed("nav"):
		self.HUD.switch_to_navi()

	if Input.is_action_pressed("landing"):
		if not landed:
			var pl = get_closest_planet()
			# values are eyeballed for current planets
			if pl[0] < 200:
				#print("Can land")
				print("Landing...")
				$"shield_indicator".hide()
				get_parent().get_node("AnimationPlayer").play("landing")
				landed = true
			else:
				print("Too far away to land")
		else:
			get_parent().get_node("AnimationPlayer").play_backwards("landing")
			$"shield_indicator".show()
			landed = false
		


func _on_AnimationPlayer_animation_finished(anim_name):
	print("Animation finished")
#	#var hide = not $"shield_indicator".is_visible()
#	if not $"shield_indicator".is_visible():
#		$"shield_indicator".show()

func shoot():
	if power <= shoot_power_draw:
		return
		
	power -= shoot_power_draw
	emit_signal("power_changed", power)
	recharge_timer.start()
	
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())

func get_closest_planet():
	var planets = get_tree().get_nodes_in_group("planets")
	
	var dists = []
	var targs = [] # otherwise we have no way of knowing which planet the dist refers to
	
	for p in planets:
		var dist = p.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, p])
		
	dists.sort()
	
	for t in targs:
		if t[0] == dists[0]:
			print("Closest planet is: " + t[1].get_name() + " at " + str(t[0]))
			return t

func get_closest_target():
	var t = get_closest_enemy()
	#t[1].targetted = true
	t.emit_signal("AI_targeted", t)
	# redraw 
	t.update()


func _draw():
	# distance indicator at a distance of 100 from the nosetip
	draw_line(Vector2(10, -100), Vector2(-10, -100), Color(1,1,0), 4.0, true)
	
	
	# draw a red rectangle around the target
	if target == self:
		var rect = Rect2(Vector2(-35, -25),	Vector2(112*0.6, 75*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)
	else:
		pass
	
	if tractored:
		var tr = get_child(0)
		var rc_h = tr.get_texture().get_height() * tr.get_scale().x
		var rc_w = tr.get_texture().get_height() * tr.get_scale().y
		#var rect = Rect2(Vector2(-rc_w/2, -rc_h/2), Vector2(rc_w, rc_h))
		#draw_rect(rect, Color(1,1,0), false)
		
		# better looking effect
		var rel_pos = get_global_transform().xform_inv(refit_target.get_global_position())
		draw_line(rel_pos, Vector2(-rc_w/2, -rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(rc_w/2, rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(rc_w/2, -rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(-rc_w/2, rc_h/2), Color(1,1,0))
		
	else:
		pass

func _on_shield_changed(data):
	var effect
	if data.size() > 1:
		effect = data[1]
	else:
		effect = true
	if effect:
		# generic effect
		$"shield_effect".show()
		$"shield_timer".start()
	
	# player-specific indicator
	if shields < 0.2 * 100:
		$"shield_indicator".set_modulate(Color(0.35, 0.0, 0.0)) #dark red
	elif shields < 0.5 * 100:
		$"shield_indicator".set_modulate(Color(1.0, 0.0, 0.0))
	elif shields < 0.7* 100: #current max
		$"shield_indicator".set_modulate(Color(1.0, 1.0, 0.0))


func _on_shield_timer_timeout():
	$"shield_effect".hide()



func heat_damage():
	shields = shields - 5
	emit_signal("shield_changed", [shields, false])
	get_node("heat_timer").start()


# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton and event.pressed:
		#target = self
		# redraw 
		update()

func _on_goto_pressed(id):
	print("Want to go to planet " + str(id))
	warp_target = get_tree().get_nodes_in_group("planets")[id].get_global_position()
	heading = warp_target
	
func on_warping():
	if power < warp_power_draw:
		emit_signal("officer_message", "Insufficient power for Q-drive")
		return
		
	# are we far enough away?
	var desired = warp_target - get_global_position()
	var dist = desired.length()
			
	if dist < LIGHT_SPEED:
		emit_signal("officer_message", "Too close to target to engage Q-drive")
		return
		
		
	power -= warp_power_draw
	emit_signal("power_changed", power)
	recharge_timer.start()
	
	# effect
	var warp = warp_effect.instance()
	add_child(warp)
	warp.set_position(Vector2(0,0))
	warp.play()
	
	# tint a matching orange color
	set_modulate(Color(1, 0.73, 0))


func _on_recharge_timer_timeout():
	# recharge
	if power < 100:
		power += power_recharge
		emit_signal("power_changed", power)

func _on_conquer_pressed(id):
	conquer_target = id


func sell_cargo(id):
	if not docked:
		print("We cannot sell if we're not docked")
		return
	
	if not cargo.keys().size() > 0:
		return
	
	
	if cargo[cargo.keys()[0]] > 0:
		cargo[cargo.keys()[0]] -= 1
		# update listing
		HUD.set_cargo_listing(str(cargo).replace("(", "").replace(")", "").replace(", ", "\n"))
		credits += 50
		

# atan2(0,-1) returns 180 degrees in 3.0, we want 0
# this counts in radians
func fix_atan(x,y):
	var ret = 0
	var at = atan2(x,y)

	if at > 0:
		ret = at - PI
	else:
		ret= at + PI
	
	return ret
