extends Node2D

var entered = false
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Area2D_area_entered(_area):
	if not entered:
		print("Wormhole entered")
		entered = true
		
		# change the system
		get_tree().get_nodes_in_group("main")[0].change_system()
		
		
