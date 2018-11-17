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
	
	player.connect("officer_message", self, "_on_officer_messaged")
	
	
	player.HUD = self
	
	get_node("Control2/Panel_rightHUD/PanelInfo/PlanetInfo/GoToButton").connect("pressed", player, "_on_goto_pressed")
	
	# Called every time the node is added to the scene.
	# Initialization here
	#pass

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
	
func _on_module_level_changed(module, level):
	var info = $"Control2/Panel_rightHUD/PanelInfo/ShipInfo/"

	
	print("Changed level of module " + str(module) + " " + str(level))
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

	if prev_target:
		if 'targetted' in prev_target:
			prev_target.targetted = false
		prev_target.update()
		prev_target.disconnect("shield_changed", self, "_on_target_shield_changed")
	
	for n in $"Control/Panel2".get_children():
		n.show()
	
		
	target.connect("shield_changed", self, "_on_target_shield_changed")

	
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