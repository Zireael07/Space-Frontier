extends Control


# Declare member variables here. Examples:
var system = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	system = 1 # because Sol is the one selected by default


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Button_pressed():
	print("Starting...", system)
	game.start = system
	
	# Load the game here
	get_tree().change_scene("res://main.tscn")

func _on_OptionButton_item_selected(index):
	system = index+1 # to avoid 0 and null being the same
