@tool
extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var siz = get_node("TextureRect").get_size()
	get_node("TextureRect").set_position(-(siz/2))
	get_node("TextureRect").set_pivot_offset(siz/2)
	get_node("Label").set_position(siz/2-Vector2(20,7))
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
