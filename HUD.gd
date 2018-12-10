extends Control

# class member variables go here, for example:
var paused = false
var player = null
var target = null


func _ready():
	player = game.player
	#player = get_tree().get_nodes_in_group("player")[0].get_child(0)
	
	# connect the signal
	
	# targeting signals
	for e in get_tree().get_nodes_in_group("enemy"):
		e.connect("AI_targeted", self, "_on_AI_targeted")
		
	for p in get_tree().get_nodes_in_group("planets"):
		p.connect("planet_targeted", self, "_on_planet_targeted")
		
	for c in get_tree().get_nodes_in_group("colony"):
		# "colony" is a group of the parent of colony itself
		# because colonies don't have HUD info yet
		c.get_child(0).connect("colony_targeted", self, "_on_planet_targeted")	
	
	player.connect("shield_changed", self, "_on_shield_changed")
	player.connect("module_level_changed", self, "_on_module_level_changed")
	player.connect("power_changed", self, "_on_power_changed")
	
	player.connect("officer_message", self, "_on_officer_messaged")
	
#	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed")
	
	
	player.HUD = self
	
	# populate nav menu
	var y = 0
	for p in get_tree().get_nodes_in_group("planets"):
		var label = Label.new()
		label.set_text(p.get_node("Label").get_text())
		label.set_position(Vector2(10,y))
		$"Control2/Panel_rightHUD/PanelInfo/NavInfo".add_child(label)
		y += 15
	

func _process(delta):
	if player != null and player.is_inside_tree():
		var format = "%0.2f" % player.spd
		get_node("Control/Panel/Label").set_text(format + " c")
	
	#pass



func _input(event):
	if Input.is_action_pressed("ui_cancel"):
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"pause_panel".show() #(not paused)
		else:
			$"pause_panel".hide()



func _on_shield_changed(shield):
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

	
func _on_module_level_changed(module, level):
	var info = $"Control2/Panel_rightHUD/PanelInfo/ShipInfo/"

	player.emit_signal("officer_message", "Our " + str(module) + " system has been upgraded to level " + str(level))

	if module == "engine":
		info.get_node("Engine").set_text("Engine: " + str(level))
		#$"Control2/Panel_rightHUD/PanelInfo/ShipInfo/Engine".set_text("Engine: " + str(level))

func _on_officer_messaged(message):
	$"Control3/Officer".set_text("1st Officer>: " + str(message))


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
	
	# assume sprite is always the first child of the ship
	$"Control/Panel2/target_outline".set_texture(AI.get_child(0).get_texture())
	
	
	for n in $"Control/Panel2".get_children():
		n.show()
	
		
	target.connect("shield_changed", self, "_on_target_shield_changed")

func hide_target_panel():
	# hide panel info if any
	for n in $"Control/Panel2".get_children():
		n.hide()

	
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
	
func _on_target_shield_changed(shield):
	#print("Shields from signal is " + str(shield))
	
	# original max is 100
	# avoid truncation
	var maxx = 100.0
	var perc = shield/maxx * 100
	
	#print("Perc: " + str(perc))
	
	if perc >= 0:
		$"Control/Panel2/ProgressBar_sh2".value = perc
	else:
		$"Control/Panel2/ProgressBar_sh2".value = 0

# operate the right HUD
func _on_ButtonPlanet_pressed():
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".show()


func _on_ButtonShip_pressed():
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".show()

func switch_to_refit():
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/ShipInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".show()

func _on_ButtonCargo_pressed():
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/RefitInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/CargoInfo".show()

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

func _on_ButtonSell_pressed():
	player.sell_cargo(0)


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


func _on_ButtonView_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var select_id = (cursor.get_position().y) / 15
	var planet = get_tree().get_nodes_in_group("planets")[select_id]
	
	$"Control2/Panel_rightHUD/PanelInfo/NavInfo".hide()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo".show()
	$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/TextureRect".set_texture(planet.get_node("Sprite").get_texture())
	
	if $"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".is_connected("pressed", player, "_on_goto_pressed"):
		$"Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton".disconnect("pressed", player, "_on_goto_pressed")
		
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed", [select_id])


func _on_ButtonUp2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	if cursor.get_position().y > 0:
		# up a line
		cursor.set_position(cursor.get_position() - Vector2(0, 15))


func _on_ButtonDown2_pressed():
	var cursor = $"Control2/Panel_rightHUD/PanelInfo/NavInfo/Cursor2"
	var num_list = get_tree().get_nodes_in_group("planets").size()-1
	var max_y = 15*num_list
	#print("num list" + str(num_list) + " max y: " + str(max_y))
	if cursor.get_position().y < max_y:
		# down a line
		cursor.set_position(cursor.get_position() + Vector2(0, 15))
