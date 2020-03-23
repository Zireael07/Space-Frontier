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

	planets = get_tree().get_nodes_in_group("planets")

	# connect the signal

	# targeting signals
	for e in get_tree().get_nodes_in_group("enemy"):
		e.connect("AI_targeted", self, "_on_AI_targeted")

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


	player.HUD = self

	# populate nav menu
	# star
	var s = get_tree().get_nodes_in_group("star")[0]
	var label = Label.new()
	var s_type = ""
	if "star_type" in s:
		s_type = str(s.get_star_type(s.star_type))
	label.set_text(s.get_node("Label").get_text() + " " + s_type)
	label.set_position(Vector2(10,0))
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".add_child(label)
	# tint gray
	label.set_self_modulate(Color(0.5,0.5, 0.5))

	# planets
	var dir_label
	var y = 15
	for i in range (planets.size()):
		var p = planets[i]
		# labels for right panel
		label = Label.new()
		var txt = p.get_node("Label").get_text()
		# mark habitable planets
		if p.is_habitable():
			txt = txt + " * "
		# does it have enough pop for a colony?
		if p.population > 51/1000.0: # in milions
			txt = txt + " ^ "
			
		label.set_text(txt)
		label.set_position(Vector2(10,y))
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo".add_child(label)
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
		y += 15
		if p.has_moon():
			var x = 15 # indent moons
			for m in p.get_moons():
				# moon label
				label = Label.new()
				
				#var moon = p.get_moon()
				txt = m.get_node("Label").get_text()
				label.set_text(txt)
				label.set_position(Vector2(10+x, y))
				$"Control2/Panel_rightHUD/PanelInfo/NavInfo".add_child(label)
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

		# direction labels
		dir_label = Label.new()
		dir_label.set_text(p.get_node("Label").get_text())
		dir_label.set_position(Vector2(20, 100))
		$"Control3".add_child(dir_label)
		dir_labels.append(dir_label)


func _process(_delta):
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


	#pass



func _input(_event):
	if Input.is_action_pressed("ui_cancel"):
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"pause_panel".show() #(not paused)
		else:
			$"pause_panel".hide()
	if Input.is_action_pressed("orders"):
		if not paused:
			return
		else:
			$"pause_panel/Label".set_text("ORDERS MODE")


func _on_shield_changed(data):
	var shield = data[0]
	#print("Shields from signal is " + str(shield))

	# original max is 100
	# avoid truncation
	var maxx = 100.0
	var perc = shield/maxx * 100

	#print("Perc: " + str(perc))

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
	# force update
	target.emit_signal("shield_changed", [target.shields])
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
	for l in $"Control2/Panel_rightHUD/PanelInfo/NavInfo".get_children():
		# because ordering in groups cannot be relied on 100%
		# find because the nav info text can have additional stuff such as * or ^
		if l.get_text().find(planet.get_node("Label").get_text().strip_edges()) != -1:
			node = l.get_name()

	if node:
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo".get_node(node).set_self_modulate(Color(0, 1, 1))
	else:
		print("Couldn't find node for planet " + str(planet.get_node("Label").get_text()))

# minimap
func _on_colony_picked(colony):
	print("Colony picked HUD")
	# pass to correct node
	$"Control2/Panel_rightHUD/minimap"._on_colony_picked(colony)

func _on_colony_colonized(colony):
	print("Colony colonized HUD")
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

#----------------------------------------------------------------------------
# operate the right HUD
func switch_to_navi():
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".show()

func _on_ButtonPlanet_pressed():
	switch_to_navi()


func _on_ButtonShip_pressed():
	if target != null and (target.is_in_group("friendly") or target.is_in_group("enemy")):
		# correctly name starbases
		if target.is_in_group("starbase"):
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Starbase")
		else:
			$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout")
		# no modules for AI yet
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Power".hide()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".hide()
		$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Shields".hide()
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


	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".show()

func switch_to_cargo():
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

func set_cargo_listing(text):
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".set_text(text)


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
	if cursor.get_position().y < 15:
		var star = get_tree().get_nodes_in_group("star")[0]
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".show()
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
	
	else:
		var select_id = (cursor.get_position().y - 15) / 15
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
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(sc)
			# move to the right to not overlap the text
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect"._set_position(Vector2(95, 1)) 
			var sc2 = Vector2(0.15*0.86, 0.15*0.86 ) #0.86 is the ratio of the procedural planet's shadow to the usual's (0.43/0.5)
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(sc2)
			# experimentally determined values
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2"._set_position(Vector2(88, -7))
	# why the eff do the asteroid/moon crosses seem not to have material?
	else:
		if planet.is_in_group("moon"):
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

	# linebreak because of planet graphic on the right
	#var period_string = str(period/86400) + " days, " + "\n" + str(period/yr) + " year(s)"
	var format_days = "%.1f days, \n%.2f year(s)" % [(period/86400), (period/yr)]

	# set text
	# this comes first because most other parameters are determined by orbital parameters
	# lots of linebreaks because of planet graphic on the right
	text = text + "\n" + "Orbital radius: " + "\n" + str(format_AU) + "\n" + "period: " + "\n" + str(format_days)
	# those parameters have been present in the original game
	text = text + "\n" + "Mass: " + str(planet.mass) + "\n" + \
	"Pressure: " + str(format_atm) + "\n" + \
	"Gravity: " + str(format_grav) + "\n" + \
	"Temperature: " + str(format_temp) + " " + str(format_tempC) + " \n"
	# this is new
	text = text + "Greenhouse effect: " + str(format_greenhouse) + "\n" + \
	"Hydro: " + str(planet.hydro)


	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".set_text(text)

	# connected from script because they rely on ID of the planet
	if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".is_connected("pressed", player, "_on_goto_pressed"):
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".disconnect("pressed", player, "_on_goto_pressed")
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed", [planet])

	if select_id != -1:
		if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".is_connected("pressed", player, "_on_conquer_pressed"):
			$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".disconnect("pressed", player, "_on_conquer_pressed")
		get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton").connect("pressed", player, "_on_conquer_pressed", [select_id])

func _on_ButtonUp2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	if cursor.get_position().y > 0:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))


func _on_ButtonDown2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var num_list = get_tree().get_nodes_in_group("planets").size()-1
	
	var max_y = 15*num_list+1 #because of star
	for p in get_tree().get_nodes_in_group("planets"):
		if p.has_moon():
			for m in p.get_moons():
				max_y = max_y +15
	#print("num list" + str(num_list) + " max y: " + str(max_y))
	if cursor.get_position().y < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))

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



func _on_BackButton_pressed():
	switch_to_navi()


func _on_ConquerButton_pressed():
	pass # Replace with function body.


func _on_officer_timer_timeout():
	$"Control3/Officer".hide()
