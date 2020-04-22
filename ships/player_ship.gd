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
var engine_draw = 2 # how fast our engine wears out
signal engine_changed

var has_cloak = false
var cloaked = false

onready var warp_effect = preload("res://warp_effect.tscn")
onready var warp_timer = $"warp_correct_timer"

onready var recharge_timer = $"recharge_timer"

var target = null
# warp drive
var heading = null
var warp_planet
var warp_target = null

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
signal planet_landed

# for AI orders
var conquer_target = null

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	game.player = self
	set_z_index(game.PLAYER_Z)
	
	connect("shield_changed", self, "_on_shield_changed")
	
	# spawn somewhere interesting
	var planet = get_tree().get_nodes_in_group("planets")[2]
	print("Location of planet " + str(planet) + " : " + str(planet.get_global_position()))
	
	# fudge
	var offset = Vector2(0,0) #Vector2(50,50)
	get_parent().set_global_position(planet.get_global_position() + offset)
	set_position(Vector2(0,0))
	

# using this instead of fixed_process because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# redraw 
	update()

	spd = vel.length() / LIGHT_SPEED

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
	# thrust
	if Input.is_action_pressed("move_up"):
		# QoL feature - launch
		if landed:
			launch()
		
		# undock
		if docked:
			# restore original z
			get_parent().set_z_index(game.PLAYER_Z)
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
			if warp_target == null:
				acc = Vector2(0, -thrust).rotated(rot)
				$"engine_flare".set_emitting(true)
				# use up engine
				if engine > 0:
					engine = engine - engine_draw
					emit_signal("engine_changed", engine)
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
			# update target and heading because the planet is orbiting, after all...
			#warp_target = warp_planet.get_global_position()
			#heading = warp_target
			
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
		
		if dist < 50 and not docked:
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

func player_heading(target, delta):
	var rel_pos = get_global_transform().xform_inv(target)
	
	var a = atan2(rel_pos.x, rel_pos.y)
	
	# we've turned to face the target
	if abs(rad2deg(a)) > 179:
		# emit signal
#		if heading == warp_target:
#			on_warping()
		
		heading = null
		
	
	if a < 0:
		rot -= rot_speed*delta
	else:
		rot += rot_speed*delta
	
# those functions that need physics
func _input(_event):
	if Input.is_action_pressed("closest_target"):
		get_closest_target()
	
	if Input.is_action_pressed("join"):
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
		# values are eyeballed for current planets (scale 1, sprite 720*0.5=360 px)
		if pl[0] > 300*pl[1].planet_rad_factor:
			print("Too far away to orbit")
		elif pl[0] < 200*pl[1].planet_rad_factor:
			print("Too close to orbit")
		else:
			print("Can orbit")
			if pl[1].has_node("orbit_holder"):
				orbit_planet(pl[1])
				
				var txt = "Orbit established."
				if pl[1].has_colony():
					txt += " Press J to request a colony"
				
				emit_signal("officer_message", txt)
	
	if Input.is_action_pressed("refit"):
		print("Want to refit")
		
		var base = get_friendly_base()
		heading = base.get_global_position()
		refit_target = base
	
	# tractor
	if Input.is_action_pressed("tractor"):
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
		self.HUD.switch_to_navi()
		
	if Input.is_action_pressed("go_planet"):
		# no warping if we are hauling a colony
		if get_colony_in_dock() != null:
			emit_signal("officer_message", "Too heavy to engage Q-drive")
			return
		# if already warping, abort
		if warping:
			print("Aborting q-drive...")
			warping = false
			warp_target = null
			heading = null
			# remove tint
			set_modulate(Color(1,1,1))
			return
		# if we have a planet view open
		if self.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			# extract planet name from planet view
			var label = self.HUD.get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/LabelName")
			var txt = label.get_text()
			var nm = txt.split(":")
			var planet_name = nm[1].strip_edges()
			print("planet: " + planet_name)
			warp_planet = get_named_planet(planet_name)
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
		if not landed:
			var pl = get_closest_planet()
			# values are eyeballed for current planets
			if pl[0] < 200:
				#print("Can land")
				print("Landing...")
				$"shield_indicator".hide()
				get_parent().get_node("AnimationPlayer").play("landing")
				landed = true
				emit_signal("planet_landed")
				# reparent
				get_parent().get_parent().remove_child(get_parent())
				pl[1].get_node("orbit_holder").add_child(get_parent())
				get_parent().set_position(Vector2(0,0))
				set_position(Vector2(0,0))
				pos = Vector2(0,0)
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


func get_named_planet(planet_name):
	var ret = null
	# convert planet name to planet node ref
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		if p.has_node("Label"):
			var nam = p.get_node("Label").get_text()
			if planet_name == nam:
				ret = p
				break
				
	return ret

func _on_AnimationPlayer_animation_finished(_anim_name):
	print("Animation finished")
#	#var hide = not $"shield_indicator".is_visible()
#	if not $"shield_indicator".is_visible():
#		$"shield_indicator".show()

func launch():
	get_parent().get_node("AnimationPlayer").play_backwards("landing")
	$"shield_indicator".show()
	landed = false
	# reparent
	var root = get_node("/root/Control")
	var gl = get_global_position()
			
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())
			
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
	
	# player-specific indicator
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
	
	# no warping if we are hauling a colony
		if get_colony_in_dock() != null:
			emit_signal("officer_message", "Too heavy to engage Q-drive")
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


func _on_recharge_timer_timeout():
	#print("Power recharge...")
	# recharge
	if power < 100:
		power += power_recharge
		emit_signal("power_changed", power)

func _on_engine_timer_timeout():
	# give back a small amount of engine when we're not boosting it
	if engine < 1000:
		engine += 1
		emit_signal("engine_changed", engine)

	


func _on_conquer_pressed(id):
	print("Setting conquer target to: " + get_tree().get_nodes_in_group("planets")[id].get_node("Label").get_text())
	conquer_target = id+1 # to avoid problems with state's parameter being 0 (= null)

func update_cargo_listing(cargo, base_storage=null):
	# update listing
	var list = []
	#print(str(cargo.keys()))
	for i in range(0, cargo.keys().size()):
		list.append(str(cargo.keys()[i]) + ": " + str(cargo[cargo.keys()[i]]))
	
		if base_storage != null:
		#print(str(base_storage))
			if cargo.keys()[i] in base_storage:
				list[i] = list[i] + "/ base: " + str(base_storage[cargo.keys()[i]])
	
	var listing = str(list).lstrip("[").rstrip("]").replace(", ", "\n")
	# this would end up in a different orders than the ids
	#var listing = str(cargo).lstrip("{").rstrip("}").replace("(", "").replace(")", "").replace(", ", "\n")
	HUD.set_cargo_listing(str(listing))

func refresh_cargo():
	if 'storage' in get_parent().get_parent():
		update_cargo_listing(cargo, get_parent().get_parent().storage)
	else:
		update_cargo_listing(cargo)

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
		update_cargo_listing(cargo, get_parent().get_parent().storage)

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
