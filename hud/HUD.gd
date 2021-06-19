extends Control

# class member variables go here, for example:
var paused = false
var player = null
var target = null
# for direction indicators
var dir_labels = []
var planets = null
var center = Vector2(450,450)
# orders mode
var orders = false
var ship_to_control = {}

# for orders mode
onready var orders_control = preload("res://hud/OrdersControl.tscn")

func _ready():
	player = game.player
	#player = get_tree().get_nodes_in_group("player")[0].get_child(0)
	player.HUD = self

	planets = get_tree().get_nodes_in_group("planets")

	connect_planet_signals(planets)

	for c in get_tree().get_nodes_in_group("colony"):
		# "colony" is a group of the parent of colony itself
		c.get_child(0).connect("colony_colonized", self, "_on_colony_colonized")
		# because colonies don't have HUD info yet
		c.get_child(0).connect("colony_targeted", self, "_on_planet_targeted")

	connect_player_signals(player)
	
	# hide armor label if needed
	if not player.has_armor:
		get_node("Control/Panel/Label_arm").hide()

#	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed")

	# populate nav menu
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	
	# scroll container scrollbar
	nav_list.scroll_to_line(0)
	nav_list.get_v_scroll().set_scale(Vector2(2, 1))
	#nav_list.set_v_scroll(0)
	# fix for max being stuck at 100
	nav_list.get_child(0).max_value = 300
	# hack fix
	nav_list.get_child(0).set_allow_greater(true)
	#nav_list.get_node("_v_scroll").set_max(300)
	# prevent any off values for scrolling
	nav_list.get_child(0).set_step(15)
	#nav_list.get_node("_v_scroll").set_step(15)


	nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control"
	nav_list._set_size(Vector2(get_size().x, 300))

	# headers
	var label = Label.new()
	label.set_name("Headers")
	label.set_text("name       type")
	label.set_position(Vector2(10,0))
	nav_list.add_child(label)
	
	# explanatory tooltip
	var tooltip = """ * - habitable planets
	^ - enough pop for a colony"""
	tooltip += " \n" + '" - has ice or water content'
	
	# didn't want to show up when attached to header, so it's attached to the whole listing instead
	nav_list.set_tooltip(tooltip)
	
	create_planet_listing()
	
	create_direction_labels()
		
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	cursor.set_position(Vector2(0, 15))

	# force modulate the initial color
	$"Control/Panel/ProgressBar_en".set_modulate(Color(0.41, 0.98, 0.02))
	$"Control/Panel/ProgressBar_sh".set_modulate(Color(0.41, 0.98, 0.02))
	$"Control/Panel/ProgressBar_po".set_modulate(Color(0.41, 0.98, 0.02))

func connect_planet_signals(planets):
	# connect the signals
	for p in planets:
		p.connect("planet_targeted", self, "_on_planet_targeted")
		p.connect("planet_colonized", self, "_on_planet_colonized")

func connect_player_signals(player):
	player.connect("shield_changed", self, "_on_shield_changed")
	player.connect("module_level_changed", self, "_on_module_level_changed")
	player.connect("power_changed", self, "_on_power_changed")
	player.connect("engine_changed", self, "_on_engine_changed")
	player.connect("armor_changed", self, "_on_armor_changed")

	player.connect("officer_message", self, "_on_officer_messaged")
	player.connect("kill_gained", self, "_on_kill_gained")
	player.connect("points_gained", self, "_on_points_gained")

	player.connect("planet_landed", self, "_on_planet_landed")

	player.connect("colony_picked", self, "_on_colony_picked")

func toggle_armor_label():
	# hide armor label if needed
	if not player.has_armor:
		get_node("Control/Panel/Label_arm").hide()
	else:
		get_node("Control/Panel/Label_arm").show()

func create_direction_labels():
	var dir_label
	for i in range (planets.size()):
		var p = planets[i]
		# direction labels
		dir_label = Label.new()
		dir_label.set_text(p.get_node("Label").get_text())
		dir_label.set_position(Vector2(20, 100))
		# tint for asteroids
		if p.is_in_group("aster_named"):
			dir_label.set_self_modulate(Color(0.75,0.75, 0.75))
		$"Control3".add_child(dir_label)
		dir_labels.append(dir_label)

func create_planet_listing():
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control"
	# stars
	var y = 15
	var stars = get_tree().get_nodes_in_group("star")
	for s in stars:	
	#var s = get_tree().get_nodes_in_group("star")[0]
		var label = Label.new()
		var s_type = ""
		if "star_type" in s:
			s_type = str(s.get_star_type(s.star_type))
		label.set_text(s.get_node("Label").get_text() + " " + s_type)
		label.set_position(Vector2(10,y))
		nav_list.add_child(label)
		# tint gray
		label.set_self_modulate(Color(0.5,0.5, 0.5))
		y += 15

	# planets
	y = 15 * (stars.size()+1)
	for i in range (planets.size()):
		var p = planets[i]
		# labels for right panel
		var label = Label.new()
		var txt = p.get_node("Label").get_text()
		# mark habitable planets
		if p.is_habitable():
			txt = txt + " * "
		# mark those with water or ice content
		if p.is_interesting():
			txt = txt + ' " '
		# does it have enough pop for a colony?
		if p.population > 51/1000.0: # in milions
			txt = txt + " ^ "
		# write down type
		var type = "planet"
		if p.is_in_group("aster_named"):
			type = "asteroid"
		txt = txt + "     " + " " + str(type)
		
		label.set_text(txt)
		label.set_position(Vector2(10,y))
		nav_list.add_child(label)
		# is it a colonized planet?
		#var last = p.get_child(p.get_child_count()-1)
		var col = p.has_colony()
		#print(p.get_name() + " has colony " + str(col))
		if col and col == "colony":
			# tint cyan
			label.set_self_modulate(Color(0, 1, 1))
		elif col and col == "enemy_col":
			# tint red
			label.set_self_modulate(Color(1, 0, 0))
		
		# tint light gray for asteroids
		elif p.is_in_group("aster_named"):
			label.set_self_modulate(Color(0.75,0.75, 0.75))
			
		y += 15
		if p.has_moon():
			var x = 15 # indent moons
			for m in p.get_moons():
				# moon label
				label = Label.new()
				
				#var moon = p.get_moon()
				txt = m.get_node("Label").get_text()
				# mark moons with water or ice content
				if m.is_interesting():
					txt = txt + ' " '
				label.set_text(txt)
				label.set_position(Vector2(10+x, y))
				nav_list.add_child(label)
				# is it a colonized planet?
				col = m.has_colony()
				#print(p.get_name() + " has colony " + str(col))
				if col and col == "colony":
					# tint cyan
					label.set_self_modulate(Color(0, 1, 1))
				elif col and col == "enemy_col":
					# tint red
					label.set_self_modulate(Color(1, 0, 0))
				y += 15

		#nav_list.get_v_scroll().set_max(y)

func clear_planet_listing():
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control"
	
	for i in range(1, nav_list.get_child_count()):
		if nav_list.get_child(i).get_name() == "Headers":
			continue # skip headers
		nav_list.get_child(i).queue_free()


func handle_direction_labels():
	for i in range(planets.size()):
		var planet = planets[i]
		# paranoia
		if not planet or planet == null:
			#print("Null planet")
			return
		if not is_instance_valid(planet):
			#print("Invalid planet")
			return
			
		var rel_loc = planet.get_global_position() - player.get_child(0).get_global_position()
		#print(planet.get_node("Label").get_text() + " : " + str(rel_loc))
		
		# if planets are very far away, hide
		if abs(rel_loc.y) > 300000 or abs(rel_loc.x) > 300000:
			dir_labels[i].hide()
		# hide even earlier for asteroids
		elif planet.is_in_group("aster_named") and abs(rel_loc.y) > 10000 or abs(rel_loc.x) > 10000:
			dir_labels[i].hide()
		else:
			#print(planet.get_node("Label").get_text() + " : " + str(rel_loc))
			
			# show labels if planets are offscreen
			# numbers hardcoded for 1024x600 screen
			if abs(rel_loc.x) > 400 or abs(rel_loc.y) > 375:
	
				# calculate clamped positions that "stick" labels to screen edges
				var clamp_x = rel_loc.x
				var clamp_y = 575
				if abs(rel_loc.x) > 400:
					clamp_x = clamp(rel_loc.x, 0, 300)
					if rel_loc.x < 0:
						clamp_x = clamp(rel_loc.x, -400, 0)
	
				if abs(rel_loc.y) > 375:
					clamp_y = clamp(rel_loc.y, 0, 575)
					if rel_loc.y < 0:
						clamp_y = 0
	
				var clamped = Vector2(center.x+clamp_x, clamp_y)
	
				dir_labels[i].set_position(clamped)
				if not dir_labels[i].is_visible():
					dir_labels[i].show()
			else:
				dir_labels[i].hide()

#----------------------------------
func _process(_delta):
	# show player speed
	if player != null and player.is_inside_tree():
		var format = "0.0"		
		if not player.dead:
			format = "%0.2f" % player.spd
		get_node("Control/Panel/Label").set_text(format + " c")
		
		get_node("Control/Panel/Label_rank").set_text(game.ranks.keys()[player.rank])

	# move direction labels to proper places
	handle_direction_labels()

func _input(_event):
	# map panel
	if Input.is_action_pressed("open_map"):
		# pause, as a kindness to the player
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"Control4/map view/Panel".set_cntr(Vector2(805/2, 525/2))
			$"Control4/map view".show() #(not paused)
			$"Control4/map view".update_ship_pos()
			
		else:
			$"Control4/map view".hide()
	
	# move markers by keyboard
	if Input.is_action_pressed("arrow_up"):
		# planet list open
		if get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
			_on_ButtonUp2_pressed()
		# if we have a planet view open
		if get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			var planet_name = planet_name_from_view()
			var planet = get_named_planet(planet_name)
			#var planets = get_tree().get_nodes_in_group("planets")
			if planet:
				var id = planets.find(planet)
				if id == -1:
	#				var moons = get_tree().get_nodes_in_group("moon")
	#				var moon = moons.find(planet)
					var parent = planet.get_parent().get_parent()
					var parent_id = planets.find(parent)
					var m_id = parent.get_moons().find(planet)
					get_node("Control2")._on_prev_pressed(m_id, parent_id)
				else:
					get_node("Control2")._on_prev_pressed(id, -1)
			else:
				# if we're in a multiple star system
				var stars = get_tree().get_nodes_in_group("star")
				if stars.size() > 1:
					var star = get_named_star(planet_name)
					var id = stars.find(star)
					if id > 0:
						var n_star = stars[id-1]
						get_node("Control2").make_star_view(n_star, id-1)
				
		# cargo panel
		if $"Control2/Panel_rightHUD/PanelInfo/CargoInfo".is_visible():
			_on_ButtonUp3_pressed()
	if Input.is_action_pressed("arrow_down"):
		# planet list open
		if get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
			_on_ButtonDown2_pressed()
		# if we have a planet view open
		if get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			var planet_name = planet_name_from_view()
			var planet = get_named_planet(planet_name)
			#var planets = get_tree().get_nodes_in_group("planets")
			if planet:
				var id = planets.find(planet)
				if id == -1:
	#				var moons = get_tree().get_nodes_in_group("moon")
	#				var moon = moons.find(planet)
					var parent = planet.get_parent().get_parent()
					var parent_id = planets.find(parent)
					var m_id = parent.get_moons().find(planet)
					get_node("Control2")._on_next_pressed(m_id, parent_id)
				else:
					get_node("Control2")._on_next_pressed(id, -1)
			else:
				# if we're in a multiple star system
				var stars = get_tree().get_nodes_in_group("star")
				if stars.size() > 1:
					var star = get_named_star(planet_name)
					var id = stars.find(star)
					if id < stars.size()-1:
						var n_star = stars[id+1]
						get_node("Control2").make_star_view(n_star, id+1)
				
		# cargo panel
		if $"Control2/Panel_rightHUD/PanelInfo/CargoInfo".is_visible():
			_on_ButtonDown3_pressed()
	# accept/back keybinds
	if Input.is_action_pressed("ui_accept"):
		# planet list open
		if get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
			_on_ButtonView_pressed()
		# cargo panel
		if $"Control2/Panel_rightHUD/PanelInfo/CargoInfo".is_visible():
			_on_ButtonSell_pressed()
	if Input.is_action_pressed("ui_back"):
		# if we have a planet view open
		if get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			_on_BackButton_pressed()
	
	# pausing/orders
	if Input.is_action_pressed("ui_cancel"):
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"pause_panel".show() #(not paused)
		else:
			$"pause_panel".hide()
			# switch off orders mode
			orders = false
			$"pause_panel/Label".set_text("PAUSED")
			remove_orders_controls()
	
	if Input.is_action_pressed("orders"):
		if not paused:
			return
		else:
			if not orders:
				orders = true
				$"pause_panel/Label".set_text("ORDERS MODE")
	
				# player and camera positions are the same, soo....
	
				# center of the viewport, i.e. half of display/window/size settings
				# this is where the player ship is, see comment three lines up
#				var cntr = Vector2(1024/2, 300)
#				# ship is roughly 50x x 70y and we need to block clicks
#				var off = Vector2(-35,-25)
#				# test
#				var pos = cntr + off + Vector2(0,0)
#				spawn_orders_control(pos)
				# AI
				spawn_AI_orders_controls()

			else:
				orders = false
				$"pause_panel/Label".set_text("PAUSED")
				remove_orders_controls()

# -----------------------------
func spawn_orders_control(pos, ship):
	var clicky = orders_control.instance() #TextureButton.new()
	clicky.set_position(pos)
	#clicky.set_normal_texture(load("res://assets/hud/grey_panel.png"))
	#clicky.set_pause_mode(PAUSE_MODE_PROCESS) # the clou of this whole thing
	$"pause_panel".add_child(clicky)
	# map controls to ships
	ship_to_control[clicky] = ship
	
	
func spawn_AI_orders_controls():
	# this is where the player ship is, see comment line 337
	var cntr = Vector2(1024/2, 300)
	# ship is roughly 50x x 70y and we need to block clicks
	var off = Vector2(-35,-25)
	for f in game.player.get_friendlies_in_range():
		var rel_pos = f.get_global_position() - player.get_child(0).get_global_position()
		var pos = cntr + off + rel_pos
		spawn_orders_control(pos, f)

func remove_orders_controls():
	for n in get_tree().get_nodes_in_group("orders_control"):
		#print("Removing..." + n.get_name())
		n.free()
	ship_to_control.clear()

# --------------------
func show_starmap():
	$"Control4/star map".show()
	
	# update marker position
	var marker = get_tree().get_nodes_in_group("starmap_marker")[0]
	$"Control4/star map".update_marker(marker)
	marker.set_position(Vector2(0,0))

func hide_starmap():
	$"Control4/star map".hide() 

# --------------------------
# signals
func _on_shield_changed(data):
	var shield = data[0]
	#print("Shields from signal is " + str(shield))

	# original max is 100
	# avoid truncation
	var maxx = 100.0
	var perc = shield/maxx * 100

	#print("Perc: " + str(perc))
	
	# matches the player-specific indicator in player_ship.gd l560
	if perc > 70:
		$"Control/Panel/ProgressBar_sh".set_modulate(Color(0.41, 0.98, 0.02))
	elif perc > 50:
		$"Control/Panel/ProgressBar_sh".set_modulate(Color(1.0, 1.0, 0))
	elif perc > 25:
		$"Control/Panel/ProgressBar_sh".set_modulate(Color(1.0, 0, 0))
	else:
		$"Control/Panel/ProgressBar_sh".set_modulate(Color(0.35, 0, 0)) # dark red

	if perc >= 0:
		$"Control/Panel/ProgressBar_sh".value = perc
	else:
		$"Control/Panel/ProgressBar_sh".value = 0

func _on_power_changed(power):
	# original max is 100
	# avoid truncation
	var maxx = 100.0
	var perc = power/maxx * 100

	#print("Perc: " + str(perc))
	
	if perc > 70:
		$"Control/Panel/ProgressBar_po".set_modulate(Color(0.41, 0.98, 0.02))
	elif perc > 40:
		$"Control/Panel/ProgressBar_po".set_modulate(Color(1.0, 1.0, 0))
	else:
		$"Control/Panel/ProgressBar_po".set_modulate(Color(1.0, 0, 0))

	if perc >= 0:
		$"Control/Panel/ProgressBar_po".value = perc
	else:
		$"Control/Panel/ProgressBar_po".value = 0

func _on_engine_changed(engine):
	# original max is 1000
	# avoid truncation
	var maxx = 1000.0
	var perc = engine/maxx * 100

	#print("Perc: " + str(perc))
	
	if perc > 70:
		$"Control/Panel/ProgressBar_en".set_modulate(Color(0.41, 0.98, 0.02))
	elif perc > 40:
		$"Control/Panel/ProgressBar_en".set_modulate(Color(1.0, 1.0, 0))
	else:
		$"Control/Panel/ProgressBar_en".set_modulate(Color(1.0, 0, 0))

	if perc >= 0:
		$"Control/Panel/ProgressBar_en".value = perc
	else:
		$"Control/Panel/ProgressBar_en".value = 0

func _on_armor_changed(armor):
	if armor >= 0:
		$"Control/Panel/Label_arm".set_text("Armor: " + str(armor))
	else:
		$"Control/Panel/Label_arm".set_text("Armor: " + str(armor))	

func _on_module_level_changed(module, level):
	var info = $"Control2/Panel_rightHUD/PanelInfo/ShipInfo/"
	var refit = $"Control2/Panel_rightHUD/PanelInfo/RefitInfo/"

	player.emit_signal("officer_message", "Our " + str(module) + " system has been upgraded to level " + str(level))

	if module == "engine":
		info.get_node("Engine").set_text("Engine: " + str(level))
		refit.get_node("Engine").set_text("Engine: " + str(level))
		#$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".set_text("Engine: " + str(level))

func _on_officer_messaged(message, time=3.0):
	$"Control3/Officer".show()
	$"Control3/Officer".set_text("1st Officer>: " + str(message))
	# start the hide timer
	$"Control3/officer_timer".wait_time = time
	$"Control3/officer_timer".start()

func _on_kill_gained(num):
	$"Control/Panel/Label_kill".set_text("Kills: " + str(num))

func _on_points_gained(num):
	$"Control/Panel/Label_points".set_text("Points: " + str(num))

# called when a player target an AI ship
func _on_AI_targeted(AI):
	var prev_target = null
	if target != null:
		prev_target = target

	# draw the red outline
	target = AI

	if prev_target != null:
		if 'targetted' in prev_target:
			prev_target.targetted = false
		prev_target.update()
		prev_target.disconnect("shield_changed", self, "_on_target_shield_changed")
		if 'armor' in prev_target:
			prev_target.disconnect("armor_changed", self, "_on_target_armor_changed")

	# assume sprite is always the first child of the ship
	$"Control/Panel2/target_outline".set_texture(AI.get_child(0).get_texture())

	# bottom panel
	for n in $"Control/Panel2".get_children():
		n.show()
		if not 'armor' in AI:
			$"Control/Panel2/Label_arm".hide()


	target.connect("shield_changed", self, "_on_target_shield_changed")
	# force update but without showing the effect
	target.emit_signal("shield_changed", [target.shields, false])
	if 'armor' in AI:
		target.connect("armor_changed", self, "_on_target_armor_changed")
		# force update
		target.emit_signal("armor_changed", target.armor)
		
	# ship info
	if target.is_in_group("enemy"):
		$"Control/Panel2/target_outline".flip_v = false #set_rotation_degrees(180)
	else:
		$"Control/Panel2/target_outline".flip_v = true #set_rotation_degrees(0)
	
	# assume sprite is always the first child of the ship
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/TextureRect2".set_texture(AI.get_child(0).get_texture())
	# switch to ship panel
	_on_ButtonShip_pressed()

func hide_target_panel():
	# hide panel info if any
	for n in $"Control/Panel2".get_children():
		n.hide()
	# default ship panel back to player sprite
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/TextureRect2".set_texture(player.get_child(0).get_texture())
	
	if $"Control2/Panel_rightHUD/PanelInfo/ShipInfo".is_visible():
		# switch away from ship panel
		_on_ButtonPlanet_pressed()

func _on_target_shield_changed(shield):
	#print("Shields from signal is " + str(shield))

	# original max is 100
	# avoid truncation
	var maxx = 100.0
	var perc = shield[0]/maxx * 100

	#print("Perc: " + str(perc))
	
	if perc > 70:
		$"Control/Panel2/ProgressBar_sh2".set_modulate(Color(0.41, 0.98, 0.02))
	elif perc > 40:
		$"Control/Panel2/ProgressBar_sh2".set_modulate(Color(1.0, 1.0, 0))
	else:
		$"Control/Panel2/ProgressBar_sh2".set_modulate(Color(1.0, 0, 0))

	if perc >= 0:
		$"Control/Panel2/ProgressBar_sh2".value = perc
	else:
		$"Control/Panel2/ProgressBar_sh2".value = 0

func _on_target_armor_changed(armor):
	if armor >= 0:
		$"Control/Panel2/Label_arm".set_text("Armor: " + str(armor))
	else:
		$"Control/Panel2/Label_arm".set_text("Armor: " + str(armor))

func is_planet_view_open():
	return $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".is_visible()

func update_planet_view(planet):
	if is_planet_view_open():
		var id = planets.find(planet)
		get_node("Control2").make_planet_view(planet, id)
		get_node("Control2").scan_off()

func _on_planet_targeted(planet):
	var prev_target = null
	
	if target != null:
		prev_target = target

	if prev_target == planet:
		print("Early exit")
		return # exit early because we're the same

	# paranoia
	if planet.get_parent().is_in_group("colony"):
		print("We're a colony, elevate the signal to actual planet")
		planet = planet.get_parent().get_parent()

	if prev_target:
		prev_target.targetted = false
		prev_target.update()

	# draw the red outline
	planet.targetted = true
	planet.update()
	target = planet
	
	# hide panel info if any
	for n in $"Control/Panel2".get_children():
		n.hide()

	print("Planet targeted: ", planet.get_node("Label").get_text())
	
	# hide any other HUD panel
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/HelpInfo".hide()
	
	# show the planet in right hud
	var id = planets.find(planet)
	get_node("Control2").make_planet_view(planet, id)
	get_node("Control2").scan_toggle(planet)

func _on_planet_colonized(planet):
	$"Control2"._on_planet_colonized(planet)

# minimap
func _on_colony_picked(colony):
	print("Colony picked HUD")
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap"._on_colony_picked(colony)

func _on_colony_colonized(colony, planet):
	print("Colony colonized HUD")
	
	# update census
	game.fleet1[0] += 1
	
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap"._on_colony_colonized(colony, planet)
	
func _minimap_update_outline(pl_target):
	#print("Target to update for: " + str(target.get_name()))
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap".update_outline(pl_target)

# those signals fire only for player and are only for the status light
func _on_target_acquired_by_AI(_AI):
	$"Control2/status_light".set_modulate(Color(1,0,0))
	print("On target_acquired, pausing...")
	# pause on player being targeted
	paused = true
	get_tree().set_pause(paused)
	$"pause_panel".show()


func _on_target_lost_by_AI(_AI):
	$"Control2/status_light".set_modulate(Color(0,1,0))
	print("On target_lost")
	
func _on_ship_spawned():
	pass
	
func _on_ship_killed(ship):
	if ship.kind_id == ship.kind.friendly:
		game.fleet1[1] -= 1
		var flt1 = "Fleet 1	" + str(game.fleet1[0]) + "		" + str(game.fleet1[1]) + "	" + str(game.fleet1[2])
		$"Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label1".set_text(flt1)
	else:
		game.fleet2[1] -= 1
		var flt2 = "Fleet 2	" + str(game.fleet2[0]) + "		" + str(game.fleet2[1]) + "	" + str(game.fleet2[2])
		$"Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label2".set_text(flt2)

# -------------
func update_panel_sprite():
	$"Control/Panel/player_outline".set_texture(player.get_child(0).get_texture())


#----------------------------------------------------------------------------
# operate the right HUD
func _on_ButtonPlanet_pressed():
	get_node("Control2").switch_to_navi()

func _on_ButtonCensus_pressed():
	get_node("Control2")._onButtonCensus_pressed()

# those two are called from starbase.gd and brain.gd, not just HUD
func display_task(target_AI):
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".show()
	var task = "Task: " + str(target_AI.brain.tasks[target_AI.brain.curr_state])
	if target_AI.brain.curr_state == 2:
		var p = target_AI.brain.get_state_obj().planet_
		task += " " + str(p.get_node("Label").get_text() )
	if target_AI.brain.curr_state == 5:
		var id = target_AI.brain.get_state_obj().planet_
		var p = get_tree().get_nodes_in_group("planets")[id-1]
		task += " " + str(p.get_node("Label").get_text() ) 
	if target_AI.brain.curr_state == 6:
		var id = target_AI.brain.get_state_obj().id
		var moon = target_AI.brain.get_state_obj().moon
		var p = get_tree().get_nodes_in_group("planets")[id-1]
		if moon:
			p = get_tree().get_nodes_in_group("moon")[id-1]
			
		task += " " + str(p.get_node("Label").get_text()) 
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".set_text(task)

func starbase_update_status(target_sb):
	var status = "status: idle"
	if target_sb.shoot_target != null:
		status = "status: attacking " + target_sb.shoot_target.get_parent().get_name()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".set_text(status)

func _on_ButtonShip_pressed():
	get_node("Control2")._onButtonShip_pressed(target)
	

func is_ship_view_open():
	return $"Control2/Panel_rightHUD/PanelInfo/ShipInfo".is_visible()
	

func switch_to_refit():
	get_node("Control2").switch_to_refit()

func switch_to_cargo():
	get_node("Control2").switch_to_cargo()

func _on_ButtonCargo_pressed():
	get_node("Control2")._onButtonCargo_pressed()

func _on_planet_landed():
	_on_ButtonCargo_pressed()


func _on_ButtonRefit_pressed():
	switch_to_refit()

func _on_ButtonDown_pressed():
	get_node("Control2")._onButtonDown_pressed()

func _on_ButtonUp_pressed():
	get_node("Control2")._onButtonUp_pressed()

func _on_ButtonUpgrade_pressed():
	get_node("Control2")._onButtonUpgrade_pressed()

# show planet/star descriptions
func _on_ButtonView_pressed():
	get_node("Control2")._on_ButtonView_pressed()


# extract planet name from planet view
func planet_name_from_view():
	var label = get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/LabelName")
	var txt = label.get_text()
	var nm = txt.split(":")
	var planet_name = nm[1].strip_edges()
	#print("planet: " + planet_name)
	return planet_name

func get_named_planet(planet_name):
	var ret = null
	# convert planet name to planet node ref
	#var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		if p.has_node("Label"):
			var nam = p.get_node("Label").get_text()
			if planet_name == nam:
				ret = p
				break
	
	if ret:
		pass
	else:	
		# no planet found, try moons next
		var moons = get_tree().get_nodes_in_group("moon")
		for m in moons:
			if m.has_node("Label"):
				var nam = m.get_node("Label").get_text()
				if planet_name == nam:
					ret = m
					break
	return ret

func get_named_star(star_name):
	# convert star name to planet node ref
	var ret = null
	var stars = get_tree().get_nodes_in_group("star")
	for s in stars:
		if s.has_node("Label"):
			var nam = s.get_node("Label").get_text()
			if star_name == nam:
				ret = s
				break
				
	return ret

func _on_ButtonUp2_pressed():
	get_node("Control2")._onButtonUp2_pressed()


func _on_ButtonDown2_pressed():
	get_node("Control2")._onButtonDown2_pressed()

func _on_BackButton_pressed():
	get_node("Control2")._onBackButton_pressed()

func _on_ConquerButton_pressed():
	pass # Replace with function body.

func update_cargo_heading(heading):
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/Heading".set_text(heading)

func update_cargo_listing(cargo, base_storage=null):
	# update listing
	var list = []
		
		
	# if we have nothing in cargo, just show full base listing
	#if cargo.size() < 1:
	if player.cargo_empty(cargo):
		if base_storage != null:
			for i in range(0, base_storage.keys().size()):
				list.append(" base: " + str(base_storage.keys()[i]).replace("_", " ") + ": " + str(base_storage[base_storage.keys()[i]]))
		else:
			return
		
	else:
		# if we're docked, keep showing base storage
		if base_storage != null:
			for i in range(0, base_storage.keys().size()):
				var entry = " base: " + str(base_storage.keys()[i]).replace("_", " ") + ": " + str(base_storage[base_storage.keys()[i]])
				# show the amount we have in cargo
				for j in range(0, cargo.keys().size()):
					if cargo.keys()[j] == base_storage.keys()[i]:
						entry = str(cargo.keys()[j]).replace("_", " ") + ": " + str(cargo[cargo.keys()[j]]) + entry
				list.append(entry)
		else:
			#print(str(cargo.keys()))
			# no base, just show our cargo
			for i in range(0, cargo.keys().size()):
				list.append(str(cargo.keys()[i]).replace("_", " ") + ": " + str(cargo[cargo.keys()[i]]))
		
			#if base_storage != null:
			#print(str(base_storage))			
			#	if cargo.keys()[i] in base_storage:
			#		list[i] = list[i] + "/ base: " + str(base_storage[cargo.keys()[i]]).replace("_", " ")

				
				
	var listing = str(list).lstrip("[").rstrip("]").replace(", ", "\n")
	# this would end up in a different orders than the ids
	#var listing = str(cargo).lstrip("{").rstrip("}").replace("(", "").replace(")", "").replace(", ", "\n")

	set_cargo_listing(str(listing))

func set_cargo_listing(text):
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".set_text(text)
	# make scrollbar visible
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".scroll_to_line(0)
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_v_scroll().set_scale(Vector2(2, 1))

func _on_ButtonSell_pressed():
	get_node("Control2")._onButtonSell_pressed()


func _on_ButtonBuy_pressed():
	get_node("Control2")._onButtonBuy_pressed()

func _on_ButtonUp3_pressed():
	get_node("Control2")._onButtonUp3_pressed()

func _on_ButtonDown3_pressed():
	get_node("Control2")._onButtonDown3_pressed()

# -------------------------------
func _on_officer_timer_timeout():
	$"Control3/Officer".hide()



func _on_star_map_gui_input(event):
	#print("event")
	if event is InputEventMouseButton:
		print("Clicked in starmap")
		# trigger jump
		game.player.w_hole.jump()
