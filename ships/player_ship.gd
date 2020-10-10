extends "ship_basic.gd"

# class member variables go here, for example:
var shield_level = 1
var engine_level = 1
var power_level = 1
signal module_level_changed

var shoot_power_draw = 10
var warp_power_draw = 50
var power_recharge = 5

var engine = 1000 # in reality, it represents fuel, call it engine for simplicity
var engine_draw = 50 # how fast our engine wears out when boosting
signal engine_changed
var boost = false

var has_cloak = false
var cloaked = false
var has_tractor = true

onready var warp_effect = preload("res://warp_effect.tscn")
onready var warp_timer = $"warp_correct_timer"

onready var recharge_timer = $"recharge_timer"

var target = null
# warp drive
var heading = null
var warp_planet
var warp_target = null
var cruise = false

var auto_orbit = false
var planet_to_orbit = null

var tractored = false
var refit_target = false

var targeted_by = []

var HUD = null
signal officer_message

var credits = 0
var kills = 0
var points = 0
signal kill_gained
signal points_gained

var landed = false
var can_land = true
signal planet_landed

# for AI orders
var conquer_target = null

func welcome():
	# give start date
	var msg = "Welcome to the space frontier! The date is %02d-%02d-%d" % [game.start_date[0], game.start_date[1], game.start_date[2]]
	emit_signal("officer_message", msg, 5.0);

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	game.player = self
	#get_parent().set_z_index(game.PLAYER_Z)
	set_z_index(game.PLAYER_Z)
	
	var _conn = connect("shield_changed", self, "_on_shield_changed")
	
	# spawn somewhere interesting
	var planet = get_tree().get_nodes_in_group("planets")[0]
	
	if get_tree().get_nodes_in_group("planets").size() > 3: 
		planet = get_tree().get_nodes_in_group("planets")[2] #2 Earth # 11 Neptune
	print("Location of planet " + str(planet) + " : " + str(planet.get_global_position()))
	
	# fudge
	var offset = Vector2(0,0) #Vector2(50,50)
	get_parent().set_global_position(planet.get_global_position() + offset)
	set_position(Vector2(0,0))
	
	call_deferred("welcome")
	
#----------------------------------
# input (spread across process and fixed_process)
# using this instead of fixed_process because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
	# were we boosting last tick?
	var old_boost = boost 

	# redraw 
	update()

	spd = vel.length() / LIGHT_SPEED
	boost = false


	# shoot
	if Input.is_action_pressed("shoot"):
		if gun_timer.get_time_left() == 0 and not landed:
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
	if Input.is_action_pressed("move_left"):
		if warping == false:
			rot -= rot_speed*delta
	if Input.is_action_pressed("move_right"):
		if warping == false:
			rot += rot_speed*delta
	
	if Input.is_action_pressed("move_down"):
		if orbiting:
			deorbit()
		
		if auto_orbit:
			auto_orbit = false
			
		if cruise:
			warp_target = null
			cruise = false
	
	# thrust
	if Input.is_action_pressed("move_up"):
		if auto_orbit:
			auto_orbit = false
		
		
		boost = true
		# QoL feature - launch
		if landed:
			launch()
		
		# undock
		if docked:
			# restore original z
			#get_parent().set_z_index(game.PLAYER_Z)
			set_z_index(game.PLAYER_Z)
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
		
		# deorbit
		if orbiting:
			deorbit()
		else:
			if not warping: #warp_target == null:
				acc = Vector2(0, -thrust).rotated(rot)
				$"engine_flare".set_emitting(true)
				# use up engine only if we changed boost
				#print("boost: " + str(boost) + "old: " + str(old_boost))
				if boost != old_boost:
					if engine > 0:
						engine = engine - engine_draw
						emit_signal("engine_changed", engine)
	
	# i.e. switch the booster on and keep it that way without player intervention
	elif cruise:
		boost = true
		# deorbit
		if orbiting:
			deorbit()
		else:
			acc = Vector2(0, -thrust).rotated(rot)
			$"engine_flare".set_emitting(true)
			# use up engine only if we changed boost
			if boost != old_boost:
				if engine > 0:
					engine = engine - engine_draw
					emit_signal("engine_changed", engine)
	else:
		acc = Vector2(0,0)
		$"engine_flare".set_emitting(false)
	
	# NOTE: actual movement happens here!
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
			# update target because the planet is orbiting, after all...
			warp_target = warp_planet.get_global_position()
			
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
				cruise = false
				warp_timer.stop()
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
		
		if dist < 50 and not docked:
			# switch off cruise if any
			cruise = false
			
			# reparent			
			get_parent().get_parent().remove_child(get_parent())
			# refit target needs to be a node because here
			refit_target.add_child(get_parent())
			# set better z so that we don't overlap parent ship
			set_z_index(-1)
			#set_z_index(game.BASE_Z-1)
			
			# nuke any velocity left
			vel = Vector2(0,0)
			acc = Vector2(0,0)
			
			var friend_docked = false
			# 6 is the default, so only check if we have more
			if get_parent().get_parent().get_child_count() > 6:
				for ch in get_parent().get_parent().get_children():
					if ch is Node2D and ch.get_index() > 5:
						if ch.get_child_count() > 0 and ch.get_child(0).is_in_group("friendly"):
#							print(ch.get_child(0).get_name())
#							print(str(ch.get_child(0).is_in_group("friendly")))
							print("Friendly docked with the starbase")
							friend_docked = true
							break
			
			# all local positions relative to the immediate parent
			if friend_docked:
				get_parent().set_position(Vector2(-25,50))
			else:
				get_parent().set_position(Vector2(0,50))
			set_position(Vector2(0,0))
			pos = Vector2(0,0)
			
			#print("Adding player as tractoring ship's child")
			
			# arrived
			refit_target = null
			#print("No refit target anymore")
			# disable tractor
			tractored = false
			docked = true
			# officer message
			emit_signal("officer_message", "Docking successful")
			# show refit screen
			self.HUD.switch_to_refit()
			
		elif dist < 80:
			tractored = true
			#print("We're being tractored in")
	
	# approach to orbit
	if auto_orbit and warp_target == null:
		if not heading: #and cruise:
			var pl = get_closest_planet()
			
			# bug fix
			if pl[1] != planet_to_orbit:
				# abort if we approached something else!
				# stop warp timer
				warp_timer.stop()
				cruise = false
				heading = null
				auto_orbit = false
				planet_to_orbit = null
			
			if pl[0] > 200*pl[1].planet_rad_factor and pl[0] < 300*pl[1].planet_rad_factor:
				# stop warp timer
				warp_timer.stop()
				# auto-orbit
				player_orbit(pl)
			
	# rotation
	# handling heading (usually the warp-drive)
	if heading:
		player_heading(heading, delta)
			
			
		
	set_rotation(rot)
	
	# fix jitter due to camera updating one frame late
	get_node("Camera2D").align()
	
	# overheat damage
	if is_overheating():
		#print("distance to star: " + str(dist))
		if get_node("heat_timer").get_time_left() == 0:
			heat_damage()

	# target direction indicator
	if HUD.target != null and HUD.target != self:
		get_node("target_dir").show()
		var tg_rel_pos = get_global_transform().xform_inv(HUD.target.get_global_position())
		get_node("target_dir").set_position(tg_rel_pos.clamped(60))
		# point at the target
		#var a = atan2(tg_rel_pos.x, tg_rel_pos.y)
		var a = fix_atan(tg_rel_pos.x, tg_rel_pos.y)
		#var angle_to = (-a+3.141593)
		get_node("target_dir").set_rotation(-a)

	
# those functions that need physics
func _input(_event):
	if Input.is_action_pressed("closest_target"):
		get_closest_target()
	
	if Input.is_action_pressed("closest_friendly_target"):
		get_closest_friendly_target()
	
	if Input.is_action_pressed("join"):
		# can't pick up colonies if we don't have the tractor/dock module
		if not has_tractor:
			return
		
		if not orbiting:
			print("Not orbiting")
		else:
			if get_colony_in_dock() == null:
				var col = pick_colony()
				if col:
					emit_signal("officer_message", "We have picked up a colony. Transport it to a planet and press / to drop it.")
				else:
					print("Planet has too little pop to create colony")
			else:
				var added = add_to_colony()
				if added:
					emit_signal("officer_message", "We have picked up additional colonists.")
				
				
				
	if Input.is_action_pressed("orbit"):
		#print("Try to orbit")
		var pl = get_closest_planet()
		
		# does the planet have moons?
		if pl[1].has_moon():
			for m in pl[1].get_moons():
				# ignore moonlets (e.g. Phobos and Deimos)
				if m.mass < 0.00001 * game.MOON_MASS:
					continue
					
				var m_dist = m.get_global_position().distance_to(get_global_position())
				print("Moon distance " + str(m_dist))
				if m_dist < 50:
					print("Too close to orbit the moon")
				elif m_dist > 150:
					print("Too far away to orbit the moon")
				else:
					player_orbit([m_dist, m])
					return

		# values are eyeballed for current planets (scale 1, sprite 720*0.5=360 px)
		if pl[0] > 300*pl[1].planet_rad_factor:
			print("Too far away to orbit")
			# approach
			auto_orbit = true
			heading = pl[1].get_global_position()
			planet_to_orbit = pl[1] # remember what we want to orbit
			# if we are too close, don't fire the engines
			if pl[0] > 150:
				cruise = true
			# reuse the 1s warp timer
			warp_timer.start()
			
		elif pl[0] < 200*pl[1].planet_rad_factor:
			print("Too close to orbit")
			# TODO: head away from planet
		else:
			player_orbit(pl)
	
	if Input.is_action_pressed("refit"):
		print("Want to refit")
		
		var base = get_friendly_base()
		if not base:
			emit_signal("officer_message", "No friendly base found in system!")
			return
			
		heading = base.get_global_position()
		refit_target = base
	
	# tractor
	if Input.is_action_pressed("tractor"):
		# if no tractor module, abort
		if has_tractor == false:
			return
			
		# toggle
		if not tractor:
			var col = get_closest_floating_colony()
			if col != null:
				tractor = col
		else:
			tractor = null

	if Input.is_action_pressed("undock_tractor"):
		print("Undock pressed")
		
		tractor = null
	
		var col = get_colony_in_dock()
		if col:
			# set flag naming us as to be rewarded for colonizing
			col.get_child(0).to_reward = self
			print("[COLONY] To reward: " + str(col.get_child(0).to_reward))
			
			# undock
			remove_child(col)
			get_parent().get_parent().add_child(col)
			
			# restore original z
			col.set_z_index(0)
			
			col.set_global_position(get_node("dock").get_global_position() + Vector2(0, 20))
			
			#print("Undocked")
			
	if Input.is_action_pressed("nav"):
		self.HUD.get_node("Control2").switch_to_navi()
		
	if Input.is_action_pressed("go_planet"):
		# no warping if we are hauling a colony
		# the check is in on_warping()
		# if already warping, abort
		if warping:
			print("Aborting q-drive...")
			warping = false
			warp_target = null
			heading = null
			warp_timer.stop()
			# remove tint
			set_modulate(Color(1,1,1))
			return
		# if we have a planet view open, just act as a hotkey for "Go to"
		if self.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			# extract planet name from planet view
			var planet_name = self.HUD.planet_name_from_view()
			warp_planet = self.HUD.get_named_planet(planet_name)
			warp_target = warp_planet.get_global_position()
			heading = warp_target
			on_warping()
			return
		# if we have a warp planet already set, go to it
		if warp_planet and not warping:
			warp_target = warp_planet.get_global_position()
			heading = warp_target
			on_warping()
			return

	if Input.is_action_pressed("landing"):
		if not can_land:
			return
		if not landed:
			var pl = get_closest_planet()
			# values are eyeballed for current planets
			if pl[0] < 200:
				#print("Can land")
				print("Landing...")
				$"shield_indicator".hide()
				get_parent().get_node("AnimationPlayer").play("landing")
				# landing happens only when the animation is done
				# prevents too fast landings
				can_land = false
				# reparent
				get_parent().get_parent().remove_child(get_parent())
				pl[1].get_node("orbit_holder").add_child(get_parent())
				get_parent().set_position(Vector2(0,0))
				set_position(Vector2(0,0))
				pos = Vector2(0,0)
				# nuke velocities
				acc = Vector2(0,0)
				vel = Vector2(0,0)
				# start the timer
				$landing_timeout.start()
			else:
				print("Too far away to land")
		else:
			launch()
	
	if Input.is_action_pressed("cloak"):
		if has_cloak:
			# toggle
			cloaked = not cloaked
			if cloaked:
				# sprite only!
				get_child(0).set_modulate(Color(0.3, 0.3, 0.3))
			else:
				get_child(0).set_modulate(Color(1,1,1))	



# -------------------------
func _on_AnimationPlayer_animation_finished(_anim_name):
	print("Animation finished")
	# toggle the landing state
	if not landed:
		landed = true
		emit_signal("planet_landed")
		emit_signal("officer_message", "Landed on a planet. Fuel replenished")
		# fill up the engine/fuel
		engine = 1000 
	else:
		landed = false

#	#var hide = not $"shield_indicator".is_visible()
#	if not $"shield_indicator".is_visible():
#		$"shield_indicator".show()

func launch():
	get_parent().get_node("AnimationPlayer").play_backwards("landing")
	$"shield_indicator".show()
	# prevent too fast landings
	can_land = false
	# reparent
	var root = get_node("/root/Control")
	var gl = get_global_position()
			
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())
	

func _on_landing_timeout_timeout():
	can_land = true

func player_heading(target, delta):
	var rel_pos = get_global_transform().xform_inv(target)
	
	var a = atan2(rel_pos.x, rel_pos.y)
	
#	# disable cruise if any
#	if cruise:
#		cruise = false
	
	# we've turned to face the target
	if abs(rad2deg(a)) > 179:
		#on_heading()
		#print("Achieved target heading")
		heading = null
		# reset cruise
		cruise = true
		# disable cruise if too close, to avoid overshooting close targets
		if rel_pos.length() < 150 and spd > 0.15:
			cruise = false
	
	if a < 0:
		rot -= rot_speed*delta
	else:
		rot += rot_speed*delta

func player_orbit(pl):
	print("Can orbit")
	# cancel cruise if any
	if cruise:
		cruise = false
		
	if auto_orbit:
		auto_orbit = false
	
	if pl[1].has_node("orbit_holder"):
		orbit_planet(pl[1])
		
		var txt = "Orbit established."
		if pl[1].has_colony():
			txt += " Fuel replenished. Press J to request a colony"
			# fill up the engine/fuel
			engine = 1000 
			# restore power
			power = 100
			# restore some shields
			if shields < 50:
				shields = 50
		
		emit_signal("officer_message", txt)
			
func shoot():
	if warping:
		return
	
	if power <= shoot_power_draw:
		emit_signal("officer_message", "Weapons systems offline!")
		return
		
	power -= shoot_power_draw
	emit_signal("power_changed", power)
	recharge_timer.start()
	
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_global_rotation(), $"muzzle".get_global_position())

# ---------------------
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
	# paranoia
	if t != null:
		#t[1].targetted = true
		t.emit_signal("AI_targeted", t)
		# redraw 
		t.update()
		# redraw minimap
		self.HUD._minimap_update_outline(t)

func get_closest_friendly_target():
	var t = get_closest_friendly()
	# paranoia
	if t != null:
		t.emit_signal("AI_targeted", t)
		# redraw 
		t.update()
		# redraw minimap
		self.HUD._minimap_update_outline(t)

func _draw():
	if not warping:
		# distance indicator at a distance of 100 from the nosetip
		draw_line(Vector2(10, -100), Vector2(-10, -100), Color(1,1,0), 4.0, true)
		
		# weapon range indicator
		var rang = 1000 * 0.25 # 1000 is the bullet's speed, 0.25 is the bullet's lifetime
		draw_line(Vector2(10, -rang) , Vector2(-10, -rang), Color(1,0,0), 4.0, true)
	
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
	
	# player-specific shield indicator
	if shields < 0.2 * 100:
		$"shield_indicator".set_modulate(Color(0.35, 0.0, 0.0)) #dark red
	elif shields < 0.5 * 100:
		$"shield_indicator".set_modulate(Color(1.0, 0.0, 0.0))
	elif shields < 0.7* 100: #current max
		$"shield_indicator".set_modulate(Color(1.0, 1.0, 0.0))
	else:
		$"shield_indicator".set_modulate(Color(0.0, 1.0, 0.0))

func _on_shield_timer_timeout():
	$"shield_effect".hide()



func heat_damage():
	shields = shields - 5
	emit_signal("shield_changed", [shields, false])
	get_node("heat_timer").start()


	

# click to target functionality
func _on_Area2D_input_event(_viewport, event, _shape_idx):
	# any mouse click
	if event is InputEventMouseButton and event.pressed:
		#target = self
		# redraw 
		update()

func _on_goto_pressed(planet):
	print("Want to go to planet " + str(planet.get_name()))
	warp_planet = planet
	warp_target = planet.get_global_position()
	heading = warp_target
	on_warping()
	
	
func on_warping():
	if orbiting:
		deorbit()
	# if we somehow are flagged as cruising already, disable it
	if cruise:
		cruise = false
	
	# no warping if we are hauling a colony
	if get_colony_in_dock() != null:
		emit_signal("officer_message", "Too heavy to engage Q-drive, engaging cruise mode instead")
		cruise = true
		return
	
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
	warp_timer.start()
	
	# effect
	var warp = warp_effect.instance()
	add_child(warp)
	warp.set_position(Vector2(0,0))
	warp.play()
	
	# tint a matching orange color
	set_modulate(Color(1, 0.73, 0))

# update target and heading because the planet is orbiting, after all...
func _on_warp_correct_timer_timeout():
	if warping:
		warp_target = warp_planet.get_global_position()
		heading = warp_target
		warp_timer.start()
	# reuse the timer for approaching the closest planet
	elif auto_orbit:
		var pl = get_closest_planet()
		heading = pl[1].get_global_position()
		if not orbiting:
			warp_timer.start()

func _on_recharge_timer_timeout():
	#print("Power recharge...")
	# recharge
	if power < 100:
		power += power_recharge
		emit_signal("power_changed", power)

func _on_engine_timer_timeout():
	# give back a small amount of engine when we're not boosting it
	if engine < 1000:
		if can_scoop():
			print("Scooping...")
			engine += 20
		else:
			engine += 5
		emit_signal("engine_changed", engine)

	


func _on_conquer_pressed(id):
	print("Setting conquer target to: " + get_tree().get_nodes_in_group("planets")[id].get_node("Label").get_text())
	conquer_target = id+1 # to avoid problems with state's parameter being 0 (= null)


# ----------------------------
func refresh_cargo():
	if 'storage' in get_parent().get_parent():
		HUD.update_cargo_listing(cargo, get_parent().get_parent().storage)
	elif 'storage' in get_parent().get_parent().get_parent(): # planet
		HUD.update_cargo_listing(cargo, get_parent().get_parent().get_parent().storage)
	
	else:
		HUD.update_cargo_listing(cargo)

func cargo_empty(cargo):
	var ret = false
	if cargo.size() < 1:
		ret = true
	else:
		ret = true
		for i in range(0, cargo.keys().size()):
			if cargo[cargo.keys()[i]] > 0:
				ret = false
	
	return ret

func sell_cargo(id):
	if not docked:
		print("We cannot sell if we're not docked")
		return
	
	if not cargo.keys().size() > 0:
		return
	
	
	if cargo[cargo.keys()[id]] > 0:
		cargo[cargo.keys()[id]] -= 1
		credits += 50
		# add cargo to starbase
		if not get_parent().get_parent().storage.has(cargo.keys()[id]):
			get_parent().get_parent().storage[cargo.keys()[id]] = 1
		else:
			get_parent().get_parent().storage[cargo.keys()[id]] += 1
		HUD.update_cargo_listing(cargo, get_parent().get_parent().storage)

func buy_cargo(id):
	if not docked:
		print("We cannot buy if we're not docked")
		return
	
	if not get_parent().get_parent().storage.keys().size() > 0:
		return
	
	
	if get_parent().get_parent().storage[get_parent().get_parent().storage.keys()[id]] > 0:
		get_parent().get_parent().storage[get_parent().get_parent().storage.keys()[id]] -= 1
		credits -= 50
		# add cargo to player
		if not cargo.has(get_parent().get_parent().storage.keys()[id]):
			cargo[get_parent().get_parent().storage.keys()[id]] = 1
		else:
			cargo[get_parent().get_parent().storage.keys()[id]] += 1
		HUD.update_cargo_listing(cargo, get_parent().get_parent().storage)	


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
