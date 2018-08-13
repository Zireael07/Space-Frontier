extends Control

# class member variables go here, for example:
var paused = false


func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass


func _input(event):
	if Input.is_action_pressed("ui_cancel"):
		paused = not paused
		#print("Pressed pause, paused is " + str(paused))
		get_tree().set_pause(paused)
		if paused:
			$"pause_panel".show() #(not paused)
		else:
			$"pause_panel".hide()
