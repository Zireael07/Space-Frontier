extends Control

# class member variables go here, for example:
var paused = false
var player = null
var target = null
# for direction indicators
var dir_labels = []
var planets = null
var center = Vector2(450,450)

func _ready():
	player = game.player
	#player = get_tree().get_nodes_in_group("player")[0].get_child(0)
	player.HUD = self

	planets = get_tree().get_nodes_in_group("planets")

	# connect the signals

	# targeting signals
	for e in get_tree().get_nodes_in_group("enemy"):
		#e.connect("AI_targeted", self, "_on_AI_targeted")

		#if "target_acquired_AI" in e.get_signal_list():
		for s in e.get_signal_list():
			if s.name == "target_acquired_AI":
				print("Connecting target acquired for " + str(e.get_parent().get_name()))
				e.connect("target_acquired_AI", self, "_on_target_acquired_by_AI")
				e.connect("target_lost_AI", self, "_on_target_lost_by_AI")


	for p in planets:
		p.connect("planet_targeted", self, "_on_planet_targeted")
		p.connect("planet_colonized", self, "_on_planet_colonized")

	for c in get_tree().get_nodes_in_group("colony"):
		# "colony" is a group of the parent of colony itself
		c.get_child(0).connect("colony_colonized", self, "_on_colony_colonized")
		# because colonies don't have HUD info yet
		c.get_child(0).connect("colony_targeted", self, "_on_planet_targeted")

	player.connect("shield_changed", self, "_on_shield_changed")
	player.connect("module_level_changed", self, "_on_module_level_changed")
	player.connect("power_changed", self, "_on_power_changed")
	player.connect("engine_changed", self, "_on_engine_changed")

	player.connect("officer_message", self, "_on_officer_messaged")
	player.connect("kill_gained", self, "_on_kill_gained")
	player.connect("points_gained", self, "_on_points_gained")

	player.connect("planet_landed", self, "_on_planet_landed")

	player.connect("colony_picked", self, "_on_colony_picked")
	for f in get_tree().get_nodes_in_group("friendly"):
		f.connect("colony_picked", self, "_on_colony_picked")

#	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed")

	# populate nav menu
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	
	# scroll container scrollbar
	nav_list.set_v_scroll(0)
	# fix for max being stuck at 100
	nav_list.get_node("_v_scroll").set_max(300)
	# prevent any off values for scrolling
	nav_list.get_node("_v_scroll").set_step(15)


	nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control"

	# headers
	var label = Label.new()
	label.set_text("name       type")
	label.set_position(Vector2(10,0))
	nav_list.add_child(label)
	
	# explanatory tooltip
	var tooltip = """ * - habitable planets
	^ - enough pop for a colony"""
	tooltip += " \n" + '" - has ice or water content'
	
	# didn't want to show up when attached to header, so it's attached to the whole listing instead
	nav_list.set_tooltip(tooltip)
	
	# star
	var s = get_tree().get_nodes_in_group("star")[0]
	label = Label.new()
	var s_type = ""
	if "star_type" in s:
		s_type = str(s.get_star_type(s.star_type))
	label.set_text(s.get_node("Label").get_text() + " " + s_type)
	label.set_position(Vector2(10,15))
	nav_list.add_child(label)
	# tint gray
	label.set_self_modulate(Color(0.5,0.5, 0.5))

	# planets
	var dir_label
	var y = 30
	for i in range (planets.size()):
		var p = planets[i]
		# labels for right panel
		label = Label.new()
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
		

		# direction labels
		dir_label = Label.new()
		dir_label.set_text(p.get_node("Label").get_text())
		dir_label.set_position(Vector2(20, 100))
		$"Control3".add_child(dir_label)
		dir_labels.append(dir_label)
		
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	cursor.set_position(Vector2(0, 15))

	# force modulate the initial color
	$"Control/Panel/ProgressBar_en".set_modulate(Color(0.41, 0.98, 0.02))
	$"Control/Panel/ProgressBar_sh".set_modulate(Color(0.41, 0.98, 0.02))
	$"Control/Panel/ProgressBar_po".set_modulate(Color(0.41, 0.98, 0.02))

func _process(_delta):
	# show player speed
	if player != null and player.is_inside_tree():
		var format = "%0.2f" % player.spd
		get_node("Control/Panel/Label").set_text(format + " c")
		
		get_node("Control/Panel/Label_rank").set_text(game.ranks.keys()[player.rank])

	# move direction labels to proper places
	for i in range(planets.size()):
		var planet = planets[i]
		var rel_loc = planet.get_global_position() - player.get_child(0).get_global_position()
		#print(rel_loc)

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



func _input(_event):
	if Input.is_action_pressed("ui_cancel"):
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"pause_panel".show() #(not paused)
		else:
			$"pause_panel".hide()
	
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
			var planets = get_tree().get_nodes_in_group("planets")
			var id = planets.find(planet)
			_on_prev_pressed(id)
	if Input.is_action_pressed("arrow_down"):
		# planet list open
		if get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
			_on_ButtonDown2_pressed()
		# if we have a planet view open
		if get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			var planet_name = planet_name_from_view()
			var planet = get_named_planet(planet_name)
			var planets = get_tree().get_nodes_in_group("planets")
			var id = planets.find(planet)
			_on_next_pressed(id)
	if Input.is_action_pressed("ui_accept"):
		# planet list open
		if get_node("Control2/Panel_rightHUD/PanelInfo/NavInfo").is_visible():
			_on_ButtonView_pressed()
	if Input.is_action_pressed("ui_back"):
		# if we have a planet view open
		if get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo").is_visible():
			_on_BackButton_pressed()
	
	if Input.is_action_pressed("orders"):
		if not paused:
			return
		else:
			$"pause_panel/Label".set_text("ORDERS MODE")


# --------------------
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
	


func _on_module_level_changed(module, level):
	var info = $"Control2/Panel_rightHUD/PanelInfo/ShipInfo/"
	var refit = $"Control2/Panel_rightHUD/PanelInfo/RefitInfo/"

	player.emit_signal("officer_message", "Our " + str(module) + " system has been upgraded to level " + str(level))

	if module == "engine":
		info.get_node("Engine").set_text("Engine: " + str(level))
		refit.get_node("Engine").set_text("Engine: " + str(level))
		#$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".set_text("Engine: " + str(level))

func _on_officer_messaged(message):
	$"Control3/Officer".show()
	$"Control3/Officer".set_text("1st Officer>: " + str(message))
	# start the hide timer
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

func _on_planet_targeted(planet):
	var prev_target = null
	if target != null:
		prev_target = target
	# draw the red outline
	planet.targetted = true
	target = planet

	if prev_target:
		prev_target.update()

	# hide panel info if any
	for n in $"Control/Panel2".get_children():
		n.hide()

func _on_planet_colonized(planet):
	var node = null
	# get label
	for l in $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control".get_children():
		if l is Label:
			# because ordering in groups cannot be relied on 100%
			# find because the nav info text can have additional stuff such as * or ^
			if l.get_text().find(planet.get_node("Label").get_text().strip_edges()) != -1:
				node = l.get_name()

	if node:
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control".get_node(node).set_self_modulate(Color(0, 1, 1))
	else:
		print("Couldn't find node for planet " + str(planet.get_node("Label").get_text()))

# minimap
func _on_colony_picked(colony):
	print("Colony picked HUD")
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap"._on_colony_picked(colony)

func _on_colony_colonized(colony):
	print("Colony colonized HUD")
	
	# update census
	game.fleet1[0] += 1
	
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap"._on_colony_colonized(colony)
	


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

#----------------------------------------------------------------------------
# operate the right HUD
func switch_to_navi():
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".show()

func _on_ButtonPlanet_pressed():
	switch_to_navi()

func _on_ButtonCensus_pressed():
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".show()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()

	# update
	var flt1 = "Fleet 1	" + str(game.fleet1[0]) + "		" + str(game.fleet1[1]) + "	" + str(game.fleet1[2])
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label1".set_text(flt1)
	var flt2 = "Fleet 2	" + str(game.fleet2[0]) + "		" + str(game.fleet2[1]) + "	" + str(game.fleet2[2])
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo/Label2".set_text(flt2)

func _on_ButtonShip_pressed():
	if target != null and (target.is_in_group("friendly") or target.is_in_group("enemy")):
		# correctly name starbases
		if target.is_in_group("starbase"):
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Starbase")
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Rank".set_text("REAR ADM.")
		else:
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout")
		
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Rank".set_text(game.ranks.keys()[target.rank])
		# no modules for AI yet
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Power".hide()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".hide()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Shields".hide()
		
		if target.is_in_group("friendly"):
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".show()
			var task = "Task: " + str(target.brain.tasks[target.brain.curr_state])
			if target.brain.curr_state == 2:
				var p = target.brain.get_state_obj().planet_
				task += " " + str(p.get_node("Label").get_text() )
			if target.brain.curr_state == 5:
				var id = target.brain.get_state_obj().planet_
				var p = get_tree().get_nodes_in_group("planets")[id-1]
				task += " " + str(p.get_node("Label").get_text() ) 
			if target.brain.curr_state == 6:
				var id = target.brain.get_state_obj().id
				var p = get_tree().get_nodes_in_group("planets")[id-1]
				task += " " + str(p.get_node("Label").get_text()) 
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".set_text(task)
		else:
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Task".hide()
		
	else:
		# get the correct data
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout")
		# for now, assume we want our own ship's data
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Power".show()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Power".set_text("Power: " + str(player.power_level))
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".show()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".set_text("Engine: " + str(player.engine_level))
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Shields".show()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Shields".set_text("Shields: " + str(player.shield_level))
		
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".show()

func switch_to_refit():
	# get the correct data
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Power".set_text("Power: " + str(player.engine_level))
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Engine".set_text("Engine: " + str(player.power_level))
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Shields".set_text("Shields: " + str(player.shield_level))
	# others
	var txt_others = ""
	if player.has_cloak:
		txt_others = "Cloak"
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Others".set_text(txt_others)

	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".show()

func switch_to_cargo():
	$"Control2/Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".show()

func _on_ButtonCargo_pressed():
	# refresh data
	player.refresh_cargo()
	switch_to_cargo()

func _on_planet_landed():
	switch_to_cargo()


func _on_ButtonRefit_pressed():
	switch_to_refit()

func _on_ButtonDown_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
	if cursor.get_position().y < 60:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))


func _on_ButtonUp_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
	if cursor.get_position().y > 30:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))

func _on_ButtonUpgrade_pressed():
	if player.docked:
		var cursor = $"Control2/Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
		var select_id = ((cursor.get_position().y-30) / 15)

		if player.credits < 50:
			player.emit_signal("officer_message", "We need " + str(50-player.credits) + " more credits to afford an upgrade")
			return

		if select_id == 0:
			player.power_level += 1
			player.credits -= 50
		if select_id == 1:
			player.engine_level += 1
			player.credits -= 50
		if select_id == 2:
			player.shield_level += 1
			player.credits -= 50

# show planet/star descriptions
func _on_ButtonView_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"


	# if we are pointing at first entry (a star), show star description instead
	if cursor.get_position().y < 30:
		var star = get_tree().get_nodes_in_group("star")[0]
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".show()
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_material(star.get_node("Sprite").get_material())
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(star.get_node("Sprite").get_texture())

		# set label
		var txt = "Star: " + str(star.get_node("Label").get_text())
		var label = $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/LabelName"

		label.set_text(txt)

		# set text
		var text = "Luminosity: " + str(star.luminosity) + "\n" + \
		"Habitable zone: " + str(star.hz_inner) + "-" + str(star.hz_outer)

		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".set_text(text)

		return
	# any futher entry is not a star
	else:
		var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
		var line = cursor.get_position().y + nav_list.get_v_scroll()
		var select_id = (line - 30) / 15
		var skips = []
		var planets = get_tree().get_nodes_in_group("planets")
		for i in range(planets.size()):
			if planets[i].has_moon():
				skips.append(i)
		
		# if the planet has a moon(s)
		for skip in skips:
		#if skip != -1:
			# how many moons do we have?
			var num_moons = planets[skip].get_moons().size()
			if select_id > skip and select_id < skip+num_moons+1:
				var m_id = select_id-skip-1
				print("Pointed cursor at moon " + str(m_id))
				var moon = planets[skip].get_moons()[m_id]
				make_planet_view(moon)
				return
			else:
				if select_id > skip+num_moons:
					# fix
					select_id = select_id-num_moons
			
		var planet = get_tree().get_nodes_in_group("planets")[select_id]
		make_planet_view(planet, select_id)

func make_planet_view(planet, select_id=-1):
	# richtextlabel scrollbar
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".scroll_to_line(0)
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".get_v_scroll().set_scale(Vector2(2, 1))
	
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".show()
	# reset
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(Vector2(0.15, 0.15))
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect"._set_position(Vector2(83, 1)) 
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(Vector2(0.15, 0.15))
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2"._set_position(Vector2(83, 1))
	# show planet sprite
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(planet.get_node("Sprite").get_texture())
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_material(planet.get_node("Sprite").get_material())
	# show shadow if planet has one
	if planet.has_node("Sprite_shadow") and planet.get_node("Sprite_shadow").is_visible():
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".show()
		# add shader if one is used
		if planet.get_node("Sprite_shadow").get_material().is_class("ShaderMaterial"):
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_material(planet.get_node("Sprite_shadow").get_material())
			# set color
			var has_aura = planet.get_node("Sprite_shadow").get_material().get_shader().has_param("shader_param/aura_color")
			if has_aura:
				var aura_col = planet.get_node("Sprite_shadow").get_material().get_shader_param("aura_color")
				$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".get_material().set_shader_param("aura_color", aura_col)	
	else:
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
	
	if planet.get_node("Sprite").get_material() != null:
		#print("Shader: " + str(planet.get_node("Sprite").get_material().is_class("ShaderMaterial")))
		var is_rot = planet.get_node("Sprite").get_material().get_shader().has_param("shader_param/time")
		#print("is rotating: " + str(is_rot))
		if is_rot:
			var sc = Vector2(0.15/2, 0.15)
			# Saturn's texture is 1800px instead of 1000px
			if planet.get_node("Label").get_text() == "Saturn":
				sc = Vector2(sc.x*0.55, sc.y*0.55) 

			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(sc)

			# move to the right to not overlap the text
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect"._set_position(Vector2(95, 1)) 
			var sc2 = Vector2(0.15*0.86, 0.15*0.86 ) #0.86 is the ratio of the procedural planet's shadow to the usual's (0.43/0.5)
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(sc2)
			# experimentally determined values
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2"._set_position(Vector2(88, -7))
	# why the eff do the asteroid/moon crosses/dwarf planets seem not to have material?
	else:
		if planet.is_in_group("moon") or planet.is_in_group("aster_named"):
			var sc = Vector2(1, 1)
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(sc)
		
	# set label
	var txt = "Planet: " + str(planet.get_node("Label").get_text())
	var label = $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/LabelName"

	label.set_text(txt)

	var col = planet.has_colony()
	if col and col == "colony":
	# tint cyan
		label.set_self_modulate(Color(0, 1, 1))
	elif col and col == "enemy_col":
		# tint red
		label.set_self_modulate(Color(1, 0, 0))
	else:
		label.set_self_modulate(Color(1,1,1))

	var text = ""
	# first, list things the player is likely to be immediately interested in
	if planet.is_habitable():
		text = " Habitable"
	if planet.tidally_locked:
		text = text + "\n" + " Tidally locked"
	
	var format_habitability = "%d" % (planet.calculate_habitability() * 100.0)
	# linebreak because planet graphic
	text = text + "\n" + "Habitability:" + "\n" + format_habitability+"%"
	#text = text + "\n" + "Habitability: " + "\n" + str(planet.calculate_habitability())
	
	# planet class
	text = text + "\n" + "Class: " + planet.get_planet_class()
		
	# formatting
	var format_pop = "%.2fK" % (planet.population * 1000)
	if planet.population > 1.0:
		format_pop = "%.2fM" % (planet.population)
	if planet.population > 1000.0:
		format_pop = "%.2fB" % (planet.population/1000.0)
		
	if col:
		# linebreak because of planet graphic
		text = text + "\n" + " Population: " + "\n" + str(format_pop)

	var au_dist = (planet.dist/game.LIGHT_SEC)/game.LS_TO_AU
	var period = planet.calculate_orbit_period()
	var yr = 3.15581e7 #seconds (86400 for a day)

	#formatting
	var format_AU = "%.3f AU" % au_dist
	var format_grav = "%.2f g" % planet.gravity
	var format_temp = "%d K" % planet.temp
	var format_tempC = "(%d C)" % (planet.temp-273.15)
	var format_atm = "%.2f atm" % planet.atm
	var format_greenhouse = "%d " % planet.greenhouse_diff()
	# format mass depending on what body we're looking at
	var format_mass = "%.3f Earth masses" % (planet.mass)
	if planet.is_in_group("moon") or planet.get_node("Label").get_text() == "Ceres":
		format_mass = "%.4f Moon masses" % (planet.mass/game.MOON_MASS)
	# otherwise the numbers would be vanishingly small
	if planet.is_in_group("aster_named") and planet.get_node("Label").get_text() != "Ceres":
		var Ceres = 0.0128*game.MOON_MASS
		format_mass = "%.4f Ceres masses (1 = 0.0128 Moon masses)" % (planet.mass/Ceres) 

	# linebreak because of planet graphic on the right
	#var period_string = str(period/86400) + " days, " + "\n" + str(period/yr) + " year(s)"
	var format_days = "%.1f days, \n%.2f year(s)" % [(period/86400), (period/yr)]

	var format_ices = "%d" % (planet.ice * 100)

	# set text
	# this comes first because most other parameters are determined by orbital parameters
	# lots of linebreaks because of planet graphic on the right
	text = text + "\n" + "Orbital radius: " + "\n" + str(format_AU) + "\n" + "period: " + "\n" + str(format_days)
	# those parameters have been present in the original game
	text = text + "\n" + "Mass: " + str(format_mass) + "\n" + \
	"Pressure: " + str(format_atm) + "\n" + \
	"Gravity: " + str(format_grav) + "\n" + \
	"Temperature: " + str(format_temp) + " " + str(format_tempC) + " \n"
	# this is new
	text = text + "Greenhouse effect: " + str(format_greenhouse) + "\n"
	# this was present in the original game
	text = text + "Hydro: " + str(planet.hydro) + "\n"
	# this is new
	text = text + "Ice cover: " + str(format_ices) + "%"

	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".set_text(text)

	# tooltip
	var dist = game.player.get_global_position().distance_to(planet.get_global_position())
	#print("Dist to planet: " + str(dist))
	var ls_travel = dist/game.LIGHT_SEC
	var format_time = "%d s" % ls_travel
	if ls_travel > 60.0:
		var mins = int(floor(ls_travel/60))
		format_time = "%02d:%02d" % [mins, (ls_travel-(mins*60))]  # MM:SS
	var travel_time = "Est. travel time @ 1.00c: " + format_time

	if dist > 400: # i.e. LIGHT_SPEED = LIGHT_SEC
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".set_tooltip(travel_time)
	else:
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".set_tooltip("")
		
	# connected from script because they rely on ID of the planet
	if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".is_connected("pressed", player, "_on_goto_pressed"):
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".disconnect("pressed", player, "_on_goto_pressed")
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed", [planet])

	if select_id != -1:
		if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".is_connected("pressed", player, "_on_conquer_pressed"):
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".disconnect("pressed", player, "_on_conquer_pressed")
		get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton").connect("pressed", player, "_on_conquer_pressed", [select_id])

	# prev/next button
	if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".is_connected("pressed", self, "_on_prev_pressed"):
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".disconnect("pressed", self, "_on_prev_pressed")
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton").connect("pressed", self, "_on_prev_pressed", [select_id])

# prev/next button
	if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".is_connected("pressed", self, "_on_next_pressed"):
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".disconnect("pressed", self, "_on_next_pressed")
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/NextButton").connect("pressed", self, "_on_next_pressed", [select_id])

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
	var planets = get_tree().get_nodes_in_group("planets")
	for p in planets:
		if p.has_node("Label"):
			var nam = p.get_node("Label").get_text()
			if planet_name == nam:
				ret = p
				break
				
	return ret

# UI signals
func _on_prev_pressed(id):
	if id-1 >= 0:	
		var planet = get_tree().get_nodes_in_group("planets")[id-1]
		make_planet_view(planet, id-1)
	#print("Pressed prev: id: " + str(id))

func _on_next_pressed(id):
	if id+1 < get_tree().get_nodes_in_group("planets").size():
		var planet = get_tree().get_nodes_in_group("planets")[id+1]
		make_planet_view(planet, id+1)
	#print("Pressed next: id: " + str(id))


func _on_ButtonUp2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	if cursor.get_position().y > 15:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))
		
	# do we scroll?
	if cursor.get_position().y < 30:
		var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
		if nav_list.get_v_scroll() > 0:
			nav_list.set_v_scroll(nav_list.get_v_scroll()-15)
			print("Scrolling up...")


func _on_ButtonDown2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var num_list = get_tree().get_nodes_in_group("planets").size()-1
	
	var max_y = 15*(num_list+2) #because of star and header
	for p in get_tree().get_nodes_in_group("planets"):
		if p.has_moon():
			for m in p.get_moons():
				max_y = max_y +15
				
	# do we scroll?
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	var line = cursor.get_position().y + nav_list.get_v_scroll()
	if cursor.get_position().y > 150 and line < max_y:
		if nav_list.get_v_scroll() == 0:
			print("Scrolling list down..")
			# scroll the list
			nav_list.set_v_scroll(15)
		elif nav_list.get_v_scroll() % 15 == 0:
			var curr = nav_list.get_v_scroll()
			nav_list.set_v_scroll(curr+15)
		
		return
		
	#print("num list" + str(num_list) + " max y: " + str(max_y))
	if line < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))

func _on_BackButton_pressed():
	var nav_list = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	# scroll container scrollbar
	nav_list.set_v_scroll(0)
	switch_to_navi()


func _on_ConquerButton_pressed():
	pass # Replace with function body.

func set_cargo_listing(text):
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".set_text(text)

func _on_ButtonSell_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var select_id = (cursor.get_position().y / 15)

	player.sell_cargo(select_id)

func _on_ButtonUp3_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	if cursor.get_position().y > 0:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0,15))

func _on_ButtonDown3_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var num_list = player.cargo.size()-1
	var max_y = 15*num_list
	if cursor.get_position().y < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0,15))


func _on_officer_timer_timeout():
	$"Control3/Officer".hide()

