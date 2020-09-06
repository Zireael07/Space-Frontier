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
				node = l.get_name()

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
	$"Panel_rightHUD/PanelInfo/NavInfo".show()
	
func _onButtonCensus_pressed():
	$"Panel_rightHUD/PanelInfo/CensusInfo".show()
	$"Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
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
			$"Panel_rightHUD/PanelInfo/ShipInfo/ShipName".set_text("Scout")
		
			$"Panel_rightHUD/PanelInfo/ShipInfo/Rank".set_text(game.ranks.keys()[target.rank])
			# stayed in HUD.gd because called from brain.gd
			get_parent().display_task(target)
		
		# no modules for AI yet
		$"Panel_rightHUD/PanelInfo/ShipInfo/Power".hide()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Engine".hide()
		$"Panel_rightHUD/PanelInfo/ShipInfo/Shields".hide()
		
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
	
	# show ship panel
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Panel_rightHUD/PanelInfo/ShipInfo".show()

func switch_to_refit():
	# get the correct data
	$"Panel_rightHUD/PanelInfo/RefitInfo/Power".set_text("Power: " + str(player.engine_level))
	$"Panel_rightHUD/PanelInfo/RefitInfo/Engine".set_text("Engine: " + str(player.power_level))
	$"Panel_rightHUD/PanelInfo/RefitInfo/Shields".set_text("Shields: " + str(player.shield_level))
	# others
	var txt_others = ""
	if player.has_cloak:
		txt_others = "Cloak"
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
	$"Panel_rightHUD/PanelInfo/RefitInfo".show()

func switch_to_cargo():
	$"Panel_rightHUD/PanelInfo/CensusInfo".hide()
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".hide()
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

func _onButtonDown_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/RefitInfo/Cursor"
	if cursor.get_position().y < 60:
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

# navigation panel
# show planet/star descriptions
func _on_ButtonView_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
			
	var stars = get_tree().get_nodes_in_group("star")
	
	# if we are pointing at first entry (a star), show star description instead
	if cursor.get_position().y < 15 * (stars.size()+1):
		var line = cursor.get_position().y + nav_list.get_v_scroll()
		var select_id = (line - 15)/15
		print("Star select id ", select_id)
		var star = get_tree().get_nodes_in_group("star")[select_id]
		$"Panel_rightHUD/PanelInfo/NavInfo".hide()
		$"Panel_rightHUD/PanelInfo/PlanetInfo".show()
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_material(star.get_node("Sprite").get_material())
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(star.get_node("Sprite").get_texture())

		# set label
		var txt = "Star: " + str(star.get_node("Label").get_text())
		var label = $"Panel_rightHUD/PanelInfo/PlanetInfo/LabelName"

		label.set_text(txt)

		# set text
		var text = ""
		# paranoia
		if 'luminosity' in star:
			text = "Luminosity: " + str(star.luminosity) + "\n" + \
		"Habitable zone: " + str(star.hz_inner) + "-" + str(star.hz_outer)

		$"Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".set_text(text)

		return
	# any futher entry is not a star
	else:
		var line = cursor.get_position().y + nav_list.get_v_scroll()
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

func make_planet_view(planet, select_id=-1, parent_id=-1):
	# richtextlabel scrollbar
	$"Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".scroll_to_line(0)
	$"Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".get_v_scroll().set_scale(Vector2(2, 1))
	
	$"Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Panel_rightHUD/PanelInfo/PlanetInfo".show()
	# reset
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(Vector2(0.15, 0.15))
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect"._set_position(Vector2(83, 11)) 
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(Vector2(0.15, 0.15))
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2"._set_position(Vector2(83, 11))
	# show planet sprite
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(planet.get_node("Sprite").get_texture())
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_material(planet.get_node("Sprite").get_material())
	# show shadow if planet has one
	if planet.has_node("Sprite_shadow") and planet.get_node("Sprite_shadow").is_visible():
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".show()
		# add shader if one is used
		if planet.get_node("Sprite_shadow").get_material().is_class("ShaderMaterial"):
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_material(planet.get_node("Sprite_shadow").get_material())
			# set color
			var has_aura = planet.get_node("Sprite_shadow").get_material().get_shader().has_param("shader_param/aura_color")
			if has_aura:
				var aura_col = planet.get_node("Sprite_shadow").get_material().get_shader_param("aura_color")
				$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".get_material().set_shader_param("aura_color", aura_col)	
	else:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
	
	# apply any modulate effects
	var modu = planet.get_node("Sprite").get_modulate()
	$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_modulate(modu)
	
	if planet.get_node("Sprite").get_material() != null:
		#print("Shader: " + str(planet.get_node("Sprite").get_material().is_class("ShaderMaterial")))
		var is_rot = planet.get_node("Sprite").get_material().get_shader().has_param("time")
		#print("is rotating: " + str(is_rot))
		if is_rot:
			var sc = Vector2(0.15/2, 0.15)
			# Saturn's texture is 1800px instead of 1000px
			if planet.get_node("Label").get_text() == "Saturn":
				sc = Vector2(sc.x*0.55, sc.y*0.55) 
			# Rhea texture is very low-res (360px)
			if planet.get_node("Label").get_text() == "Rhea":
				sc = Vector2(sc.x*3, sc.y*3)
#			if planet.get_node("Label").get_text() == "Mimas":
#				sc = Vector2(sc.x*0.5, sc.y*0.5)

			#print("sc: " + str(sc))
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(sc)

			# move to the right to not overlap the text
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect"._set_position(Vector2(95, 11)) 
			var sc2 = Vector2(0.15*0.86, 0.15*0.86 ) #0.86 is the ratio of the procedural planet's shadow to the usual's (0.43/0.5)
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(sc2)
			# experimentally determined values
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2"._set_position(Vector2(88, 3))
			
			if planet.is_in_group("moon"):
				# hide shadow for moons if they don't have atmo
				if planet.atm < 0.001:
					$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
				else:
					sc2 = Vector2(0.18*0.86, 0.18*0.86) # experimental (for Titan)
					$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".set_scale(sc2)
	# why the eff do the asteroid/moon crosses/dwarf planets seem not to have material?
	else:
		if planet.is_in_group("moon") or planet.is_in_group("aster_named"):
			var sc = Vector2(1, 1)
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_scale(sc)
			# hide shadow
			$"Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect2".hide()
		
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
	if planet.tidally_locked:
		text = text + "\n" + "Tidally locked"
	
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
		text = text + "\n" + "Population: " + "\n" + str(format_pop)
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
	var format_tempC = "(%d C)" % (planet.temp-273.15)
	var format_atm = "%.2f atm" % planet.atm
	if planet.is_in_group("moon"):
		format_atm = "%.3f atm" % planet.atm
	var format_greenhouse = "%d " % planet.greenhouse_diff()
	# format mass depending on what body we're looking at
	var format_mass = "%.3f M Earth" % (planet.mass)
	if planet.is_in_group("moon") or planet.get_node("Label").get_text() == "Ceres":
		format_mass = "%.4f M Moon" % (planet.mass/game.MOON_MASS)
	# otherwise the numbers would be vanishingly small
	if planet.is_in_group("aster_named") and planet.get_node("Label").get_text() != "Ceres":
		var Ceres = 0.0128*game.MOON_MASS
		format_mass = "%.4f M Ceres  (1 = 0.0128 M Moon)" % (planet.mass/Ceres) 

	# linebreak because of planet graphic on the right
	#var period_string = str(period/86400) + " days, " + "\n" + str(period/yr) + " year(s)"
	var format_days = "%.1f days, \n%.2f year(s)" % [(period/86400), (period/yr)]

	var format_ices = "%d" % (planet.ice * 100)

	# set text
	# this comes first after name/habitability (and some line breaks for clarity)
	# because most other parameters are determined by orbital parameters
	# lots of linebreaks because of planet graphic on the right
	text = text + "\n \n \n" + "Orbital radius: " + "\n" + str(format_AU) + "\n" + "period: " + "\n" + str(format_days)
	# those parameters have been present in the original game
	text = text + "\n" + "Mass: " + str(format_mass) + "\n" + \
	"Pressure: " + str(format_atm) + "\n" + \
	"Gravity: " + str(format_grav) + "\n" + \
	"Temperature: " + "\n" + str(format_temp) + " " + str(format_tempC) + " \n"
	# this is new
	text = text + "Greenhouse effect: " + str(format_greenhouse) + "\n"
	# this was present in the original game
	text = text + "Hydro: " + str(planet.hydro) + "\n"
	# this is new
	text = text + "Ice cover: " + str(format_ices) + "%"
	# layout fix
	text = text + "\n"

	$"Panel_rightHUD/PanelInfo/PlanetInfo/RichTextLabel".set_text(text)

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
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".set_tooltip(travel_time)
	else:
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".set_tooltip("")
		
	# connected from script because they rely on ID of the planet
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".is_connected("pressed", player, "_on_goto_pressed"):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".disconnect("pressed", player, "_on_goto_pressed")
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed", [planet])

	if parent_id != -1:
		if $"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".is_connected("pressed", player, "_on_conquer_pressed"):
			$"Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton".disconnect("pressed", player, "_on_conquer_pressed")
		get_node("Panel_rightHUD/PanelInfo/PlanetInfo/ConquerButton").connect("pressed", player, "_on_conquer_pressed", [select_id])

	# prev/next button
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".is_connected("pressed", self, "_on_prev_pressed"):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton".disconnect("pressed", self, "_on_prev_pressed")
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/PrevButton").connect("pressed", self, "_on_prev_pressed", [select_id, parent_id])

	# prev/next button
	if $"Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".is_connected("pressed", self, "_on_next_pressed"):
		$"Panel_rightHUD/PanelInfo/PlanetInfo/NextButton".disconnect("pressed", self, "_on_next_pressed")
	get_node("Panel_rightHUD/PanelInfo/PlanetInfo/NextButton").connect("pressed", self, "_on_next_pressed", [select_id, parent_id])

# UI signals
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
		if nav_list.get_v_scroll() > 0:
			nav_list.set_v_scroll(nav_list.get_v_scroll()-15)
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

func _onBackButton_pressed():
	var nav_list = $"Panel_rightHUD/PanelInfo/NavInfo/PlanetList"
	# scroll container scrollbar
	nav_list.set_v_scroll(0)
	switch_to_navi()


# cargo
# ---------------------------------
func _onButtonSell_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var select_id = (cursor.get_position().y / 15)

	player.sell_cargo(select_id)

func _onButtonBuy_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var select_id = (cursor.get_position().y / 15)

	player.buy_cargo(select_id)	

func get_base_storage(playr):
	if 'storage' in playr.get_parent().get_parent():
		return playr.get_parent().get_parent().storage
	else:
		return []

func _onButtonUp3_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	if cursor.get_position().y > 0:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0,15))
		
func _onButtonDown3_pressed():
	var cursor = $"Panel_rightHUD/PanelInfo/CargoInfo/Cursor3"
	var num_list = player.cargo.size()-1
	if player.cargo_empty(player.cargo):
		num_list = get_base_storage(player).size()-1
	var max_y = 15*num_list
	if cursor.get_position().y < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0,15))
