extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# fix weird sizing bug
	# 100x100 times button's scale
	# button scale informed by friendly sprite's dimensions (roughly 50x75)
	var size = Vector2(100,100)*get_node("TextureButton").rect_scale
	#print("Size: " + str(size))
	_set_size(size)
	if game.player.HUD.target != null:
		get_node("VBoxContainer/Button2").set_disabled(false)
	else:
		get_node("VBoxContainer/Button2").set_disabled(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_TextureButton_pressed():
	#print("Control pressed")
	get_node("VBoxContainer").set_position(Vector2(60, 60))
	get_node("VBoxContainer").show()



func _on_Button_pressed():
	if get_node("VBoxContainer/Button").visible:
		var area = game.player.HUD.ship_to_control[self]
		print("Issuing order 1 to ship " + area.get_parent().get_name())
		# actually issue order
		var brain = area.get_node("brain")
		brain.target = game.player.get_child(0).get_global_position()
		brain.set_state(brain.STATE_IDLE)
		
	#pass # Replace with function body.


func _on_Button2_pressed():
	if get_node("VBoxContainer/Button").visible:
		var area = game.player.HUD.ship_to_control[self]
		print("Issuing order 2 to ship " + area.get_parent().get_name())
		# actually issue order
		var brain = area.get_node("brain")
		brain.set_state(brain.STATE_ATTACK, game.player.HUD.target)
	#pass # Replace with function body.
