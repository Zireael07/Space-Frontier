extends Control

# class member variables go here, for example:
var paused = false
var player = null

func _ready():
	
	player = get_tree().get_nodes_in_group("player")[0].get_child(0)
	
	# connect the signal
	for e in get_tree().get_nodes_in_group("enemy"):
		e.connect("AI_targeted", self, "_on_AI_targeted")
	
	player.connect("shield_changed", self, "_on_shield_changed")
	player.connect("module_level_changed", self, "_on_module_level_changed")
	
	
	# Called every time the node is added to the scene.
	# Initialization here
	#pass

func _process(delta):
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

func _on_AI_targeted():
	for n in $"Control/Panel2".get_children():
		n.show()
	
	#$"Control/Panel2/target_outline".show()