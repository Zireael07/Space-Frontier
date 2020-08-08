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

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_TextureButton_pressed():
	print("Control pressed")
	get_node("VBoxContainer").set_position(Vector2(60, 60))
	#get_node("VBoxContainer").show()

