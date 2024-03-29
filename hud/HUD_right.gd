extends Control


# Declare member variables here. Examples:
var player
var planets

# Called when the node enters the scene tree for the first time.
func _ready():
	player = game.player
	planets = get_tree().get_nodes_in_group("planets")


func _on_planet_colonized(planet):
	var node = null
	# get label
	for l in $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control".get_children():
		if l is Label:
			# because ordering in groups cannot be relied on 100%
			# find because the nav info text can have additional stuff such as * or ^
			if l.get_text().find(planet.get_node("Label").get_text().strip_edges()) != -1:
				node = String(l.get_name())

	if node:
		$"Panel_rightHUD/PanelInfo/NavInfo/PlanetList/Control".get_node(node).set_self_modulate(Color(0, 1, 1))
	else:
		print("Couldn't find node for planet " + str(planet.get_node("Label").get_text()))

# operate the right HUD
func switch_to_navi():
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".show()
	
	# grab the f&cking focus
	$"Panel_rightHUD/PanelInfo/NavInfo/ButtonView".grab_focus()
	
func _onButtonCensus_pressed():
	$"Panel_rightHUD/PanelInfo/CensusInfo".show()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()

	# update
	var flt1 = "Fleet 1	" + str(game.fleet1[0]) + "		" + str(game.fleet1[1]) + "	" + str(game.fleet1[2])
	$"Panel_rightHUD/PanelInfo/CensusInfo/Label1".set_text(flt1)
	var flt2 = "Fleet 2	" + str(game.fleet2[0]) + "		" + str(game.fleet2[1]) + "	" + str(game.fleet2[2])
	$"Panel_rightHUD/PanelInfo/CensusInfo/Label2".set_text(flt2)
	
func _onButtonShip_pressed(target):
	if target != null and (target.is_in_group("friendly") or target.is_in_group("enemy")):
		# correctly name starbases
		if target.is_in_group("starbase"):
			$"Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Starbase")
			$"Panel_rightHUD/PanelInfo/ShipInfo/Rank".set_text("REAR ADM.")
			
			$"Panel_rightHUD/PanelInfo/ShipInfo/Task".show()
			# stayed in HUD.gd because called from starbase script
			get_parent().starbase_update_status(target)

		else:
			$"Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout" + "\n" + target.get_parent().get_name())
		
			$"Panel_rightHUD/PanelInfo/ShipInfo/Rank".set_text(game.ranks.keys()[target.rank])
			# stayed in HUD.gd because called from brain.gd
			get_parent().display_task(target)
		
		# no modules for AI yet
		$"Panel_rightHUD/PanelInfo/ShipInfo/Power".hide()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Engine".hide()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Shields".hide()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Others".hide()
		
	# no target, show player's own data	
	else:
		# get the correct data
		$"Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout")
		# want our own ship's data
		$"Panel_rightHUD/PanelInfo/ShipInfo/Power".show()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Power".set_text("Power: " + str(player.power_level))
		$"Panel_rightHUD/PanelInfo/ShipInfo/Engine".show()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Engine".set_text("Engine: " + str(player.engine_level))
		$"Panel_rightHUD/PanelInfo/ShipInfo/Shields".show()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Shields".set_text("Shields: " + str(player.shield_level))
	
		# others
		var txt_others = ""
		if player.has_cloak:
			txt_others += "Cloak"
			$"Panel_rightHUD/PanelInfo/ShipInfo/Others".set_text(txt_others)
	
	# show ship panel
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".show()

func _on_ship_prev_button_pressed():
	if get_parent().target == null:
		return 
		
	if get_parent().target.is_in_group("enemy"):
		var enemies = get_tree().get_nodes_in_group("enemy")
		get_parent().target = enemies[enemies.find(get_parent().target)-1]
	_onButtonShip_pressed(get_parent().target)

func _on_ship_next_button_pressed():
	if get_parent().target == null:
		return 
	if get_parent().target.is_in_group("enemy"):
		var enemies = get_tree().get_nodes_in_group("enemy")
		if enemies.size() > enemies.find(get_parent().target)+1:
			get_parent().target = enemies[enemies.find(get_parent().target)+1]
	_onButtonShip_pressed(get_parent().target)

func switch_to_refit():
	# update class line
	$"Panel_rightHUD/PanelInfo/RefitInfo/ShipName".set_text(player.ship_class.keys()[player.class_id].capitalize())
	
	if not player.docked:
		$"Panel_rightHUD/PanelInfo/RefitInfo/Label".hide()
		$"Panel_rightHUD/PanelInfo/RefitInfo/Cursor".hide()
	
	# get the correct data
	$"Panel_rightHUD/PanelInfo/RefitInfo/Power".set_text("Power: " + str(player.engine_level))
	$"Panel_rightHUD/PanelInfo/RefitInfo/Engine".set_text("Engine: " + str(player.power_level))
	$"Panel_rightHUD/PanelInfo/RefitInfo/Shields".set_text("Shields: " + str(player.shield_level))
	# others
	var txt_others = ""
	if player.has_tractor:
		txt_others = "Tractor"
	if player.has_cloak:
		txt_others += "\nCloak"
	$"Panel_rightHUD/PanelInfo/RefitInfo/Others".set_text(txt_others)

	# disable button if not docked
	if player.docked:
		$"Panel_rightHUD/PanelInfo/RefitInfo/ButtonUpgrade".set_disabled(false)
	else:
		$"Panel_rightHUD/PanelInfo/RefitInfo/ButtonUpgrade".set_disabled(true)

	# show correct panel
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".show()

func update_ship_name():
	# update class line
	$"Panel_rightHUD/PanelInfo/RefitInfo/ShipName".set_text(player.ship_class.keys()[player.class_id].capitalize())


func switch_to_cargo():
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".show()
	
func _onButtonCargo_pressed():
	# refresh data
	player.refresh_cargo()
	# disable the button if nothing in cargo
	if player.cargo_empty(player.cargo):
		$"Panel_rightHUD/PanelInfo/CargoInfo/ButtonSell".set_disabled(true)
	else:
		$"Panel_rightHUD/PanelInfo/CargoInfo/ButtonSell".set_disabled(false)
	switch_to_cargo()
	# grab the f#$cking focus
	$"Panel_rightHUD/PanelInfo/CargoInfo/ButtonBuy".grab_focus()

func _onButtonDown_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
	if cursor.get_position().y < 90:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))
		
func _onButtonUp_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
	if cursor.get_position().y > 30:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))
		
func _onButtonUpgrade_pressed():
	if player.docked:
		var cursor = $"Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
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


func _on_ButtonSell_pressed():
	if player.docked:
		var cursor = $"Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
		var select_id = ((cursor.get_position().y-30) / 15)
		
		if select_id == 3:
			print("Pressed sell addons")
			player.credits += 100
			player.has_tractor = false
			# force update
			switch_to_refit()

# navigation panel
# show planet/star descriptions
func _on_ButtonView_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
			
	var stars = get_tree().get_nodes_in_group("star")
	
	# if we are pointing at first entry (a star), show star description instead
	if cursor.get_position().y < 15 * (stars.size()+1):
		var line = cursor.get_position().y + nav_list.get_v_scroll_bar().value
		var select_id = (line - 15)/15
		print("Star select id ", select_id)
		var star = get_tree().get_nodes_in_group("star")[select_id]
		
		make_star_view(star, select_id)

		return
	# any futher entry is not a star
	else:
		var line = cursor.get_position().y + nav_list.get_v_scroll_bar().value
		var select_id = (line - 15 * (stars.size()+1)) / 15
		var skips = []
		#var planets = get_tree().get_nodes_in_group("planets")
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
				make_planet_view(moon, m_id, skip)
				return
			else:
				if select_id > skip+num_moons:
					# fix
					select_id = select_id-num_moons
			
		var planet = get_tree().get_nodes_in_group("planets")[select_id]
		make_planet_view(planet, select_id)

func make_star_view(star, _select_id):
	print("Making view for star...", star.get_node("Label").get_text() )
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".show()
	
	var view = $"Panel_rightHUD/PanelInfo/PlanetInfo/SubViewportContainer"
	# scale to achieve roughly 110 px size
	var siz = Vector2(750,750)
	view.get_child(0).size = siz
	view.set_scale(Vector2(0.15, 0.15))
	view._set_position(Vector2(90, 0))
	# place view in center
	view.get_node("SubViewport/Node2D").position = Vector2(siz.x/2, siz.y/2)
	# add the nodes
	view.get_node("SubViewport/Node2D").add_child(star.get_node("Sprite2D").duplicate())	

	#$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
	#$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_material(star.get_node("Sprite2D").get_material())
	#$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(star.get_node("Sprite2D").get_texture())

	# set label
	var txt = "Star: " + str(star.get_node("Label").get_text())
	var label = $"Panel_rightHUD/PanelInfo/PlanetInfo/LabelName"

	label.set_text(txt)

	# set text
	var text = ""
	# paranoia
	if 'luminosity' in star:
		var fmt_AU = "%.3f AU"
		var fmt_lum = "%.3f"
		text = "Luminosity: " + str(fmt_lum % star.luminosity) + "\n" + \
	"Habitable zone: " + "\n" + str(fmt_AU % star.hz_inner) + "-" + str(fmt_AU % star.hz_outer)

	var rtl = $"Panel_rightHUD/PanelInfo/PlanetInfo".get_child(1)
	rtl.set_name("RichTextLabel")
	rtl.set_text(text)

func make_planet_view(planet, select_id=-1, parent_id=-1):
	var rtl = $"Panel_rightHUD/PanelInfo/PlanetInfo".get_child(1)
	# allow identifying what planet we are for from code (needed for scrollbar response)
	rtl.set_name("RichTextLabel#"+str(select_id)+">"+str(parent_id))
	# richtextlabel scrollbar
	rtl.scroll_to_line(0)
	rtl.get_v_scroll_bar().set_scale(Vector2(2, 1))
	
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".show()
	# reset
	for c in $"Panel_rightHUD/PanelInfo/PlanetInfo/SubViewportContainer/SubViewport/Node2D".get_children():
		c.queue_free()
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
	# use viewport instead of hacking to replicate planet looks
	var view = $"Panel_rightHUD/PanelInfo/PlanetInfo/SubViewportContainer"
	# 0.35 scale to achieve roughly 110 px size from 300px sized viewport for a planet
	var siz = Vector2(300,300)
	view.get_child(0).size = siz
	view.set_scale(Vector2(0.35, 0.35))
	#if planet.is_in_group("moon") or planet.is_in_group("aster_named"):
	#	view.set_scale(Vector2(1,1))
	view._set_position(Vector2(80, 0))
	# place view in center
	view.get_node("SubViewport/Node2D").position = Vector2(siz.x/2, siz.y/2)
	# add the nodes
	view.get_node("SubViewport/Node2D").add_child(planet.get_node("Sprite2D").duplicate())
	if planet.has_node("Sprite_shadow"):
		view.get_node("SubViewport/Node2D").add_child(planet.get_node("Sprite_shadow").duplicate())
		
	# set label
	var txt = "Destination: " + str(planet.get_node("Label").get_text())
	var label = $"Panel_rightHUD/PanelInfo/PlanetInfo/LabelName"

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
	# actual text begins here
	# first, list things the player is likely to be immediately interested in
	if planet.is_habitable():
		text = "Habitable"
	if planet.in_venus_zone():
		text = "In Venus Zone"
	if planet.tidally_locked:
		text = text + "\n" + "Tidally locked"
	
	var format_habitability = "%d" % (planet.calculate_habitability() * 100.0) if planet.scanned else " ?? "
	# linebreak because planet graphic
	text = text + "\n" + "Habitability:" + "\n" + format_habitability+"%"
	#text = text + "\n" + "Habitability: " + "\n" + str(planet.calculate_habitability())
	
	# planet temp & class
	if planet.scanned:
		text = text + "\n" + "Class: " + planet.get_temp_desc() + " \n" + planet.get_volatiles_desc() + " " + planet.get_planet_class()
	else:
		text = text + "\n" + "Class: ?? \n ?? " + planet.get_planet_class()
	
	# formatting planet population string
	var format_pop = "%.2fK" % (planet.population * 1000)
	if planet.population > 1.0:
		format_pop = "%.2fM" % (planet.population)
	# NOTE: 1B = 1000M (1B = 10^9) 
	# as evidenced by Earth's starting pop in the original Stellar Frontier
	if planet.population > 1000.0:
		format_pop = "%.2fB" % (planet.population/1000.0)
	
	var factor = planet.population/8500.0
	var fact = clampf(factor, 0.01, 1.0) # to ensure no negative natural growth
	var growth_rate = lerpf(0.0125, 0.0001, fact) # just by eyeballing historical stats (max is around 2.0% i.e. 0.02)
		
	if col:
		# linebreak because of planet graphic
		text = text + "\n" + "Population: " + "\n" + str(format_pop)
		text = text + "\n" + "Growth rate: " + "%.2f" % (growth_rate*100) + "%" # original game had this somewhere at the bottom
		var allegiance = ""
		if col == "colony":
			allegiance = "Terran"
		elif col == "enemy_col":
			allegiance = "enemy"
		# linebreak because of planet graphic on the right
		text = text + "\n" + "under " + allegiance + "\n" + " control"
	
	var dist = planet.dist
	# two significant digits is enough for planets
	var fmt_AU = "%.2f AU"
	# three digits for asteroids
	if planet.is_in_group("aster_named"):
		fmt_AU = "%.3f AU"
	# moons are a special case
	if planet.is_in_group("moon"):
		# fudge for Martian moons (for realistic distances, they'd totally overlap the Mars sprite)
		if planet.get_parent().get_parent().get_node("Label").get_text() == "Mars":
			# 150 is the rough radius of the sprite
			dist = dist-150
		
		dist = dist/10	
		# show up to 4 significant digits for moons
		fmt_AU = "%.4f AU"

	
	var au_dist = (dist/game.LIGHT_SEC)/game.LS_TO_AU
	
	var period = planet.calculate_orbit_period()
	var yr = 3.15581e7 #seconds (86400 for a day)

	#formatting
	var format_AU = fmt_AU % au_dist
	var format_grav = "%.2f g" % planet.gravity
	var format_temp = "%d K" % planet.temp
	var format_tempC = "(%d C)" % (planet.temp-game.ZEROC_IN_K);
	var format_atm = "%.2f atm" % planet.atm
	if planet.is_in_group("moon"):
		format_atm = "%.3f atm" % planet.atm
	var format_greenhouse = "%d " % planet.greenhouse_diff() if planet.scanned else " ?? "
	# format mass depending on what body we're looking at
	var format_mass = "%.3f M⊕" % (planet.mass) # use Earth masses by default
	if planet.is_in_group("moon") or planet.get_node("Label").get_text() == "Ceres":
		format_mass = "%.4f M☾" % (planet.mass/game.MOON_MASS)
	# otherwise the numbers would be vanishingly small
	if planet.is_in_group("aster_named") and planet.get_node("Label").get_text() != "Ceres":
		var Ceres = 0.0128*game.MOON_MASS
		format_mass = "%.4f M① \n (1 = 0.0128 M☾)" % (planet.mass/Ceres)
	if planet.is_in_group("moon") and planet.get_node("Label").get_text() == "Phobos" or planet.get_node("Label").get_text() == "Deimos":
		var Ceres = 0.0128*game.MOON_MASS
		print("Mass: ", planet.mass, ", Ceres: ", planet.mass/Ceres)
		format_mass = "%.6f M① \n (1 = 0.0128 M☾)" % (planet.mass/Ceres) # they are just THAT small
	
	var format_radius = "%.2f R⊕" % planet.radius

	# linebreak because of planet graphic on the right
	#var period_string = str(period/86400) + " days, " + "\n" + str(period/yr) + " year(s)"
	var format_days = "%.1f days, \n%.2f year(s)" % [(period/86400), (period/yr)]

	var format_hydro = "%d" % (planet.hydro * 100) if planet.scanned else "??"
	var format_ices = "%d" % (planet.ice * 100) if planet.scanned else "??"

	# set text
	# this comes first after name/habitability (and some line breaks for clarity)
	# because most other parameters are determined by orbital parameters
	# lots of linebreaks because of planet graphic on the right
	text = text + "\n \n \n" + "Orbital radius: " + "\n" + str(format_AU) + "\n" + "period: " + "\n" + str(format_days)
	# those parameters have been present in the original game
	text = text + "\n" + "Mass: " + str(format_mass) + "\n" + \
	"Pressure: " + str(format_atm) + "\n" + \
	"Gravity: " + str(format_grav) + "\n"
	# radius was not present, but we might as well add it in
	# don't show it for moons and asteroids or gas giants
	if not planet.is_in_group("moon") and not planet.is_in_group("aster_named") and planet.get_planet_class() == "rocky":
		text = text + "Radius: " + str(format_radius) + "\n"
	# was in the original game
	text = text + "Temperature: " + "\n" + str(format_temp) + " " + str(format_tempC) + " \n"
	# this is new
	text = text + "Greenhouse effect: " + str(format_greenhouse) + "\n"
	# this was present in the original game
	# renamed to be clearer
	text = text + "Land/water ratio: " + str(format_hydro) + "%\n"
	# this is new
	text = text + "Ice cover: " + str(format_ices) + "%" + "\n"
	
	if planet.atm > 0.01 and planet.scanned:
		# pretty formatting for atmosphere data
		var atm_text = ""
		var gases = planet.atm_gases
		if not gases:
			gases = planet.atmosphere_gases()
		# gases[1] is sorted for display purposes
		for i in range(gases[1].size()):
			var g = gases[1][i]
			var format_g = "%s %d" % [g[0], g[1]]
			if i == 0:
				atm_text = str(format_g)+"%"
			else:
				atm_text = atm_text + ", " + str(format_g)+"%"
		
		text = text + "Atmosphere: \n" + atm_text #str(planet.atmosphere_gases())
	
	if planet.scanned:
		# pretty formatting for composition
		var composition_text = ""
		var composition = planet.composition
		for i in range(composition.size()):
			var e = composition[i]
			var format_e = "%s %.2f" % [e[0], e[1]]
			if i == 0:
				composition_text = str(format_e)+"%"
			else:
				composition_text = composition_text + ", " + str(format_e)+"%"
			
		text = text + "\nComposition: \n" + composition_text
	
	# planet storage (only if ours)
	if col and col == "colony":
		var store = str(planet.storage).replace("{", "").replace("}", "")
		text = text + "\n" + "Storage: \n" + store
	
	
	# layout fix
	text = text + "\n"

	rtl.set_text(text)

	# tooltip
	var tool_dist = game.player.get_global_position().distance_to(planet.get_global_position())
	#print("Dist to planet: " + str(dist))
	var ls_travel = tool_dist/game.LIGHT_SEC
	var format_time = "%d s" % ls_travel
	if ls_travel > 60.0:
		var mins = int(floor(ls_travel/60))
		format_time = "%02d:%02d" % [mins, (ls_travel-(mins*60))]  # MM:SS
	var travel_time = "Est. travel time @ 1.00c: " + format_time

	if tool_dist > 400: # i.e. LIGHT_SPEED = LIGHT_SEC
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".tooltip_text = travel_time
	else:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".tooltip_text = ""
	
	# connected from script because the scrollbar of the RichTextLabel is created at runtime
	rtl.get_v_scroll_bar().connect("value_changed",Callable(self,"_on_view_scroll_changed")) #, [value, no_shadow])
	
		
	# connected from script because they rely on ID of the planet
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".is_connected("pressed",Callable(player,"_on_goto_pressed")):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".disconnect("pressed",Callable(player,"_on_goto_pressed"))
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed",Callable(player,"_on_goto_pressed").bind(planet))

	if parent_id != -1:
		if $"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".is_connected("pressed",Callable(player,"_on_conquer_pressed")):
			$"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".disconnect("pressed",Callable(player,"_on_conquer_pressed"))
		get_node("Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton").connect("pressed",Callable(player,"_on_conquer_pressed").bind(select_id))

	if $"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".is_connected("pressed",Callable(player,"_on_scan_pressed")):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".disconnect("pressed",Callable(player,"_on_scan_pressed"))
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton").connect("pressed",Callable(player,"_on_scan_pressed").bind(planet))

	# prev/next button
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".is_connected("pressed",Callable(self,"_on_prev_pressed")):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".disconnect("pressed",Callable(self,"_on_prev_pressed"))
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton").connect("pressed",Callable(self,"_on_prev_pressed").bind(select_id, parent_id))

	# prev/next button
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".is_connected("pressed",Callable(self,"_on_next_pressed")):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".disconnect("pressed",Callable(self,"_on_next_pressed"))
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/NextButton").connect("pressed",Callable(self,"_on_next_pressed").bind(select_id, parent_id))

func scan_toggle(planet):
	if planet.scanned:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".set_disabled(true)
	else:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".set_disabled(false)
	$"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".show()
	$"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".hide()
	
func scan_off(): 
	$"Panel_rightHUD/PanelInfo/PlanetInfo/ScanButton".set_disabled(true)
	$"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".hide()
	
# UI signals
func _on_view_scroll_changed(val):
	#print("Scroll val" + str(val))
	if val > 5:
		# make sprite transparent if we scrolled down
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".self_modulate = Color(1,1,1, 0.5)
		# hide because otherwise it obscures the text
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".self_modulate = Color(1,1,1,0.75)
	else:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".self_modulate = Color(1,1,1, 1)
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".self_modulate = Color(1,1,1, 1)
#		# get planet, again
#		var planet = null
#		var spl = $"Panel_rightHUD/PanelInfo/PlanetInfo".get_child(1).get_name().split("#")
#		print("ID: ", spl[1])
#		var id = spl[1].split(">")
#		if int(id[1]) == -1: # parent_id
#			planet = get_tree().get_nodes_in_group("planets")[int(id[0])]
#		else:
#			var parent = get_tree().get_nodes_in_group("planets")[int(id[1])]
#			planet = parent.get_moons()[int(id[0])]
#		# restore shadow if we have to
#		if not planet.no_shadow:
#			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".show()

func _on_prev_pressed(id, parent_id):
	if parent_id == -1:
		if id-1 >= 0:	
			var planet = get_tree().get_nodes_in_group("planets")[id-1]
			make_planet_view(planet, id-1)
	else:
		#print("Got parent id")
		var parent = get_tree().get_nodes_in_group("planets")[parent_id] 
		if id-1 >= 0:
			var moon = parent.get_moons()[id-1]
			make_planet_view(moon, id-1, parent_id)
	#print("Pressed prev: id: " + str(id))

func _on_next_pressed(id, parent_id):
	if parent_id == -1:
		if id+1 < get_tree().get_nodes_in_group("planets").size():
			var planet = get_tree().get_nodes_in_group("planets")[id+1]
			make_planet_view(planet, id+1)
	else:
		#print("Got parent id")
		var parent = get_tree().get_nodes_in_group("planets")[parent_id] 
		if id+1 < parent.get_moons().size():
			var moon = parent.get_moons()[id+1]
			make_planet_view(moon, id+1, parent_id)
	#print("Pressed next: id: " + str(id))

func _onButtonUp2_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	if cursor.get_position().y > 15:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))
		
	# do we scroll?
	if cursor.get_position().y < 30:
		var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
		if nav_list.get_v_scroll_bar().value > 0:
			nav_list.get_v_scroll_bar().value = (nav_list.get_v_scroll_bar().value-15)
			# manually "scroll"
			nav_list.get_node("Control")._set_position(Vector2(0,-nav_list.get_v_scroll_bar().value))
			print("Scrolling up...")
			
func _onButtonDown2_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var num_list = get_tree().get_nodes_in_group("planets").size()-1
	var stars = get_tree().get_nodes_in_group("star")
	
	var max_y = 15*(num_list+stars.size()+1) #because of header
	for p in get_tree().get_nodes_in_group("planets"):
		if p.has_moon():
			for m in p.get_moons():
				max_y = max_y +15
				
	# do we scroll?
	var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	var line = cursor.get_position().y + nav_list.get_v_scroll_bar().value #nav_list.get_v_scroll()
	if cursor.get_position().y > 150 and line < max_y:
		if nav_list.get_v_scroll_bar().value == 0: #get_v_scroll() == 0:
			# scroll the list
			nav_list.get_v_scroll_bar().value = 15
			# manually "scroll"
			nav_list.get_node("Control")._set_position(Vector2(0,-nav_list.get_v_scroll_bar().value))
			print("Scrolling list down..")
		else:
		#elif int(nav_list.get_child(0).value) % 15 == 0: #nav_list.get_v_scroll() % 15 == 0:
			var curr = nav_list.get_v_scroll_bar().value #nav_list.get_v_scroll()
			nav_list.get_v_scroll_bar().value = curr+15
			#print("Scroll further ", nav_list.get_child(0).value)
			# manually "scroll"
			nav_list.get_node("Control")._set_position(Vector2(0,-nav_list.get_v_scroll_bar().value))
			#nav_list.set_v_scroll(curr+15)
			#nav_list.scroll_vertical = (curr+15)
		
		return
		
	#print("num list" + str(num_list) + " max y: " + str(max_y))
	if line < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))

func _onBackButton_pressed():
	var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	# scroll container scrollbar
	#nav_list.set_v_scroll(0)
	#nav_list.get_child(0).value = 0
	switch_to_navi()


# cargo
# ---------------------------------
func _onButtonSell_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var select_id = ((cursor.get_position().y-15) / 15)

	player.sell_cargo(select_id)
	
	#TODO: disable sell if we no longer have this cargo in hold?
	
	# grab the f#$cking focus
	$"Panel_rightHUD/PanelInfo/CargoInfo/ButtonBuy".grab_focus()

func _onButtonBuy_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var select_id = ((cursor.get_position().y-15) / 15)

	if player.buy_cargo(select_id):
		# if we bought anything, enable the sell button
		$"Panel_rightHUD/PanelInfo/CargoInfo/ButtonSell".set_disabled(false)

func get_base_storage(playr):
	if 'storage' in playr.get_parent().get_parent():
		return playr.get_parent().get_parent().storage
	elif 'storage' in playr.get_parent().get_parent().get_parent(): # planet
		return playr.get_parent().get_parent().get_parent().storage
	else:
		return []

func _onButtonUp3_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	if cursor.get_position().y > 15:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0,15))
		
func _onButtonDown3_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	#var num_list = player.cargo.size()-1
	#if player.cargo_empty(player.cargo):
	#	num_list = get_base_storage(player).size()-1
	var num_list = get_base_storage(player).size()-1
	var max_y = 15+15*num_list

	if cursor.get_position().y > 150 and cursor.get_position().y < max_y:
		#var scroll = $"Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_child(0).value
		if $"Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_child(0).value == 0:
			$"Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_child(0).value = 15
		else: 
			$"Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_child(0).value = $"Panel_rightHUD/PanelInfo/CargoInfo/RichTextLabel".get_child(0).value + 15 
		return
	if cursor.get_position().y < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0,15))
		
# --------------------------
func switch_to_help():
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/HelpInfo".show()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
